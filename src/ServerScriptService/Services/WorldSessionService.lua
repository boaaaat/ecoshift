-- Durable expedition orchestration. Reservation credentials stay in server-only
-- records/options; TeleportData is a correlation hint, never admission authority.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teleport = game:GetService("TeleportService")
local Http = game:GetService("HttpService")
local Config = require(RS.Shared.SessionConfig)
local Util = require(RS.Shared.Util)
local Policy = require(RS.Shared.MatchmakingPolicy)
local Store = require(script.Parent.WorldStateStore)
local Saves = require(script.Parent.WorldSaveService)
local Parties = require(script.Parent.PartyService)
local Profiles = require(script.Parent.ProfileService)
local Service = { _travel = {}, _loading = {}, _present = {}, _workers = {}, _recoveryAt = {}, _closing = false }
local LAUNCH_SECONDS, RESERVATION_SECONDS, SAVE_SECONDS = 300, 90, 120
local function guid() return Http:GenerateGUID(false) end
local function nativeType() return game.MatchmakingType.Name end
local function contains(record, userId) return record and table.find(record.Roster or {}, userId) ~= nil end
local function sameRoster(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	local left, right = table.clone(a), table.clone(b)
	table.sort(left); table.sort(right)
	for i, id in ipairs(left) do if id ~= right[i] then return false end end
	return true
end
local function validRoster(ids)
	if type(ids) ~= "table" or #ids < 1 or #ids > Config.MaxPartySize then return false end
	local seen, count = {}, 0
	for key, id in pairs(ids) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #ids
			or type(id) ~= "number" or id % 1 ~= 0 or id <= 0 or id >= 2^53 or seen[id] then return false end
		seen[id] = true; count += 1
	end
	return count == #ids
end
local function active(record)
	return record and not record.Ended and record.Phase == "Active" and (record.ServerLeaseUntil or 0) > os.time()
end
local function ownedLease(record)
	return record and record.Phase == "Active" and record.ServerJobId == game.JobId and (record.ServerLeaseUntil or 0) > os.time()
end
local function launching(record)
	return record and not record.Ended and record.Phase == "Launching" and (record.LaunchUntil or 0) > os.time()
end
local function safeMessage(player, success, message)
	local remote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Lobby")
	if remote and player.Parent == Players then remote:FireClient(player, "Notice", { Success = success, Message = message }) end
end

function Service:_adopt(record)
	if not self._record or (record.Revision or 0) >= (self._record.Revision or 0) then self._record = record end
	local current = self._record
	if current.Phase == "Active" and current.ServerJobId == game.JobId and not self._stopped then
		RS:SetAttribute("WorldLeaseUntil", current.ServerLeaseUntil or 0)
		RS:SetAttribute("WorldLeaseOwned", (current.ServerLeaseUntil or 0) > os.time())
	end
end

function Service:_stop(reason)
	if self._stopped then return end
	self._stopped = true
	RS:SetAttribute("WorldLeaseOwned", false)
	RS:SetAttribute("WorldRestoring", true)
	RS:SetAttribute("WorldSessionState", reason)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then player.Character:Destroy() end
		player:Kick("This expedition stopped safely. Return to the lobby to reunite with your crew.")
	end
end

function Service:_startLeaseWorkers()
	if self._leaseWorkers then return end
	self._leaseWorkers = true
	-- This deadline guard never waits for DataStore uploads or the renew request.
	task.spawn(function()
		while not self._stopped do
			if self._record and self._record.Phase == "Active" and (self._record.ServerLeaseUntil or 0) <= os.time() then self:_stop("WorldLeaseExpired"); break end
			task.wait(1)
		end
	end)
	task.spawn(function()
		while not self._stopped do
			task.wait(30)
			if self._stopped or not self._record or self._record.Phase ~= "Active" then break end
			local renewed, reason = Store:Renew(self._record, game.JobId)
			if renewed then self:_adopt(renewed)
			elseif reason == "WorldLeaseLost" then self:_stop(reason) end
		end
	end)
end

function Service:_otherAssignment(userId, worldId)
	local assignment, reason = Store:GetAssignment(userId)
	if reason then return nil, reason end
	if not assignment or assignment.WorldId == worldId then return false end
	local other, failure = Store:Get(assignment.WorldId)
	if failure and failure ~= "WorldNotFound" then return nil, failure end
	return active(other) or launching(other)
end

function Service:_publishAssignments(record)
	if not launching(record) and not active(record) then return nil, "LaunchNoLongerAvailable" end
	if not Store:RegisterReservation(record) then return nil, "ReservationRegistrationPending" end
	-- Each owner has a separate key. Prepare the crew together instead of adding
	-- every player's storage latency to the launch time.
	local remaining, complete = #record.Roster, true
	local finished = Instance.new("BindableEvent")
	for _, userId in ipairs(record.Roster) do
		task.spawn(function()
			local ok, assigned = pcall(Store.Assign, Store, userId, record)
			if not ok or not assigned then complete = false end
			remaining -= 1
			if remaining == 0 then finished:Fire() end
		end)
	end
	if remaining > 0 then finished.Event:Wait() end
	finished:Destroy()
	if not complete then return nil, "CrewAssignmentsPending" end
	-- The durable assignments are ready: don't wait for the recovery poll to
	-- discover them. Other lobbies retain that fallback, as do failed teleports.
	if launching(record) or (active(record) and not record.AdmissionComplete) then
		for _, userId in ipairs(record.Roster) do
			local player = Players:GetPlayerByUserId(userId)
			if player and record.MatchmakingType == nativeType() then self:_queueTravel(player, record) end
		end
	end
	-- Save ownership was already committed; archive display metadata can refresh
	-- alongside travel rather than holding up the departure.
	task.spawn(function() Saves:UpdateManifest(record) end)
	return true
end

function Service:_ensureLaunch(worldId)
	local record, reason = Store:Get(worldId)
	if not record then return nil, reason end
	if not record.CrewCommitted or not record.SlotToken then return nil, "CrewCommitPending" end
	local committed, failure = Saves:CommitRoster(record.Id, record.SlotToken)
	if not committed then return nil, failure end
	if launching(record) or active(record) then return self:_publishAssignments(record) end
	if record.Phase ~= "CrewCommitted" and record.Phase ~= "Reserving" then return nil, "OriginalCrewResumeRequired" end
	local token = guid()
	local claimed, problem = Store:Mutate(record.Id, function(current)
		if not current or not current.CrewCommitted or current.Ended then return nil, "CrewCommitPending" end
		if current.Phase ~= "CrewCommitted" and current.Phase ~= "Reserving" then return nil, "LaunchChanged" end
		if current.ReservationLeaseToken and (current.ReservationLeaseUntil or 0) > os.time() then return nil, "ReservationWorkerBusy" end
		if current.Phase == "CrewCommitted" then current.Generation = (current.Generation or 0) + 1 end
		current.Phase = "Reserving"
		current.ReservationLeaseToken, current.ReservationLeaseUntil = token, os.time() + RESERVATION_SECONDS
		return current
	end)
	if not claimed then return nil, problem end
	-- A lost response may create an unused reservation. Only a fenced successful
	-- durable publication can make its credential reachable by any player.
	local reserved, code, privateId = pcall(function() return Teleport:ReserveServerAsync(Config.ExpeditionPlaceId) end)
	if not reserved or type(code) ~= "string" or type(privateId) ~= "string" then return nil, "ReservationRetryPending" end
	local issuedAt = os.time()
	for _, userId in ipairs(claimed.Roster) do
		local assignment, err = Store:GetAssignment(userId)
		if err then return nil, err end
		if assignment then issuedAt = math.max(issuedAt, (assignment.IssuedAt or 0) + 1) end
	end
	local launched, launchError = Store:Mutate(claimed.Id, function(current)
		if not current or current.Generation ~= claimed.Generation or current.Phase ~= "Reserving"
			or current.ReservationLeaseToken ~= token or current.ReservationLeaseUntil <= os.time() then return nil, "ReservationWorkerExpired" end
		current.PrivateServerId, current.PrivateAccessCode = privateId, code
		current.ServerJobId, current.ServerLeaseUntil = nil, 0
		current.Phase, current.LaunchedAt, current.LaunchUntil = "Launching", issuedAt, os.time() + LAUNCH_SECONDS
		current.AdmissionComplete = false
		current.ReservationLeaseToken, current.ReservationLeaseUntil = nil, nil
		return current
	end)
	if not launched then return nil, launchError end
	return self:_publishAssignments(launched)
end

function Service:CreateMatchedExpedition(match)
	if RunService:IsStudio() then return false, "PublishedPlayRequired" end
	if type(match) ~= "table" or not validRoster(match.Roster) or not Policy.IsMatchmakingType(match.MatchmakingType) then return false, "InvalidMatchedRoster" end
	local launchMode = match.LaunchMode or "Matchmaking"
	if launchMode ~= "Matchmaking" and launchMode ~= "Party" then return false, "InvalidLaunchMode" end
	if launchMode == "Matchmaking" and #match.Roster ~= Config.MaxPartySize then return false, "InvalidMatchedRoster" end
	if launchMode == "Party" and (type(match.Sources) ~= "table" or #match.Sources ~= 1) then return false, "InvalidPartyLaunch" end
	local record, reason = Store:Get(match.WorldId)
	if not record and reason ~= "WorldNotFound" then return nil, reason end
	if not record then
		local function sourceChanged(message)
			-- A cancelled start can lose its source queue before the first world
			-- write. Resolve the fenced decision instead of retrying it forever.
			local aborted, failure = Parties:AbortMerge(match.WorldId, match.Id, match.LeaseToken)
			if aborted == true then return false, message end
			return nil, failure or "CrewCommitRecoveryPending"
		end
		local members, sources, sourceIds, roster, leader, oldest = {}, {}, {}, {}, nil, math.huge
		for _, source in ipairs(match.Sources or {}) do
			local party, err = Parties:GetPartyById(source.Id)
			if err then return nil, err end
			if not party or not party.Queue or party.Queue.MatchId ~= match.Id or party.Queue.Token ~= source.Token then return sourceChanged("SourceCrewChanged") end
			if (party.Queue.Mode or "Matchmaking") ~= launchMode then return sourceChanged("LaunchModeChanged") end
			table.insert(sourceIds, source.Id); table.insert(sources, { Id = source.Id, Token = source.Token })
			if party.CreatedAt < oldest then oldest, leader = party.CreatedAt, party.LeaderId end
			for userId, member in pairs(party.Members) do
				if members[userId] then return false, "DuplicateCrewMember" end
				members[userId] = { UserId = member.UserId, Name = member.Name, DisplayName = member.DisplayName, Role = member.Role, ClassLevel = member.ClassLevel or 1,
					JoinedAt = member.JoinedAt, SourcePartyId = source.Id, Session = member.Session, SessionAt = member.SessionAt }
				table.insert(roster, member.UserId)
			end
		end
		if not sameRoster(roster, match.Roster) then return false, "MatchedRosterChanged" end
		table.sort(roster)
		record, reason = Store:Mutate(match.WorldId, function(current)
			if current then return current.MatchId == match.Id and current or nil, "WorldCommitChanged" end
			return { SchemaVersion = 1, Id = match.WorldId, MatchId = match.Id, LaunchMode = launchMode, Sources = sources, SourceIds = sourceIds,
				Roster = roster, Members = members, LeaderId = leader, PartyId = "world:" .. match.WorldId,
				MatchmakingType = match.MatchmakingType, CreatedAt = os.time(), Generation = 0, Phase = "Preparing", CrewCommitted = false }
		end)
		if not record then return nil, reason end
	end
	if record.MatchId ~= match.Id or (record.LaunchMode or "Matchmaking") ~= launchMode or not sameRoster(record.Roster, match.Roster) then return nil, "WorldCommitChanged" end
	if record.CrewCommitted then
		if Parties.RestoreExpeditionParty and (record.Phase == "CrewCommitted" or record.Phase == "Reserving") then
			local party = Parties:RestoreExpeditionParty(record)
			if not party then return nil, "CommittedCrewRecoveryPending" end
		end
		return self:_ensureLaunch(record.Id)
	end
	if record.Phase == "Aborted" then
		if record.SlotToken and not Saves:AbortRoster(record.Id, record.SlotToken) then return nil, "ArchiveAbortPending" end
		return false, "ReservationAborted"
	end
	local reserved, tokenOrReason, possibleToken = Saves:ReserveRoster(record.Id, record.Roster)
	if not reserved then
		local manifest = Saves:GetManifest(record.Id)
		if manifest and manifest.State == "Aborted" then return false, tokenOrReason end
		return nil, tokenOrReason or possibleToken
	end
	local updated, updateError = Store:Mutate(record.Id, function(current)
		if not current or current.MatchId ~= match.Id or current.Phase == "Aborted" then return nil, "WorldCommitChanged" end
		current.SlotToken = tokenOrReason
		return current
	end)
	if not updated then return nil, updateError end
	record = updated
	local validSignals = true
	for _, userId in ipairs(record.Roster) do
		local presence, available = Parties:GetPresence(userId)
		if not available then return nil, "CrewPresenceUnavailable" end
		if not presence or not presence.Online or presence.Mode ~= "Lobby" or presence.ExpiresAt <= os.time()
			or presence.MatchmakingType ~= record.MatchmakingType or presence.Session ~= record.Members[tostring(userId)].Session then validSignals = false; break end
	end
	local party, mergeReason, decision
	if validSignals then
		party, mergeReason, decision = Parties:MergeForExpedition(record.SourceIds, record.MatchId, record.Id, match.LeaseToken, launchMode)
	else
		-- Atomic cancellation distinguishes an actual precommit change from a
		-- previous worker that already committed and began transferring the crew.
		local aborted, abortReason = Parties:AbortMerge(record.Id, record.MatchId, match.LeaseToken)
		mergeReason = abortReason or "CrewPlatformOrConnectionChanged"
		if aborted == true then decision = false elseif aborted == false then decision = true end
	end
	if decision == false then
		local stopped = Store:Mutate(record.Id, function(current)
			if not current or current.CrewCommitted then return nil, "CrewAlreadyCommitted" end
			current.Phase = "Aborted"; return current
		end)
		if not stopped then return nil, "AbortStatusPending" end
		local aborted = Saves:AbortRoster(record.Id, record.SlotToken)
		if aborted then return false, mergeReason end
		return nil, "ArchiveAbortPending"
	end
	if decision ~= true then return nil, mergeReason or "CrewDecisionPending" end
	local committedRecord, commitError = Store:Mutate(record.Id, function(current)
		if not current or current.MatchId ~= match.Id or current.Phase == "Aborted" then return nil, "WorldCommitChanged" end
		current.CrewCommitted = true
		if current.Phase == "Preparing" then current.Phase = "CrewCommitted" end
		return current
	end)
	if not committedRecord then return nil, commitError end
	-- From the irreversible crew decision onward every failure is retryable nil.
	if not party then return nil, mergeReason or "CommittedCrewRecoveryPending" end
	return self:_ensureLaunch(record.Id)
end

function Service:_travelFailure(player, state)
	if self._travel[player] ~= state then return end
	state.InFlight = false
	if state.Kind == "Lobby" and (state.Attempts or 0) >= 5 then
		self._travel[player] = nil
		local remotes = RS:FindFirstChild("Remotes")
		local death = remotes and remotes:FindFirstChild("Death")
		if death and state.ReturnRequestId and player.Parent == Players then
			death:FireClient(player, "ReturnStatus", { RequestId = state.ReturnRequestId, Success = false,
				Message = "Roblox could not start your return. Please try again." })
		end
		safeMessage(player, false, "Roblox could not start your return. Please try again.")
		Parties:CancelTransfer(player)
		return
	end
	state.RetryAt = os.clock() + math.min(30, 2 ^ math.min(state.Attempts or 1, 5))
	Parties:CancelTransfer(player)
	if state.Attempts == 3 then safeMessage(player, false, "Travel is retrying. Your expedition and crew are preserved.") end
end

function Service:_teleport(player, state)
	if player.Parent ~= Players or state.InFlight or (state.RetryAt or 0) > os.clock() then return end
	-- Fence the attempt before any storage call can yield; retry workers cannot
	-- overlap one player's reservation check or react to an older failure event.
	local attemptId = guid()
	state.TravelId, state.Attempts, state.InFlight = attemptId, (state.Attempts or 0) + 1, true
	state.StartedAt = os.clock()
	local options = Instance.new("TeleportOptions")
	local placeId = Config.LobbyPlaceId
	if state.Kind == "World" then
		local record = Store:Get(state.WorldId)
		if self._travel[player] ~= state or state.TravelId ~= attemptId or not state.InFlight then return end
		if not record or record.Generation ~= state.Generation or not contains(record, player.UserId)
			or record.MatchmakingType ~= nativeType() or (not active(record) and not launching(record)) then
			self._travel[player] = nil; Parties:CancelTransfer(player); return
		end
		if type(record.PrivateAccessCode) ~= "string" then self:_travelFailure(player, state); return end
		options.ReservedServerAccessCode = record.PrivateAccessCode
		placeId = Config.ExpeditionPlaceId
	end
	state.PlaceId = placeId
	options:SetTeleportData({ TravelId = state.TravelId })
	Parties:BeginTransfer(player)
	if player.Parent ~= Players or self._travel[player] ~= state or state.TravelId ~= attemptId or not state.InFlight then return end
	local ok = pcall(function() Teleport:TeleportAsync(placeId, { player }, options) end)
	if not ok and state.TravelId == attemptId then self:_travelFailure(player, state) end
end

function Service:_initTravel()
	if self._travelStarted or RunService:IsStudio() then return end
	self._travelStarted = true
	Teleport.TeleportInitFailed:Connect(function(player, _, _, placeId, options)
		local state = self._travel[player]
		if not state or state.PlaceId ~= placeId then return end
		local ok, data = pcall(function() return options:GetTeleportData() end)
		if ok and data and data.TravelId == state.TravelId then self:_travelFailure(player, state) end
	end)
	Players.PlayerRemoving:Connect(function(player) self._travel[player], self._recoveryAt[player] = nil, nil end)
	task.spawn(function()
		while true do
			for player, state in pairs(self._travel) do
				if player.Parent ~= Players then self._travel[player] = nil
				elseif state.InFlight and os.clock() - state.StartedAt > 45 then self:_travelFailure(player, state)
				elseif not state.InFlight then task.spawn(function() self:_teleport(player, state) end) end
			end
			task.wait(3)
		end
	end)
end

function Service:_queueTravel(player, record)
	if self._travel[player] then return true, "Travel is already being arranged." end
	self:_initTravel()
	local state = { Kind = "World", WorldId = record.Id, Generation = record.Generation, Attempts = 0 }
	self._travel[player] = state
	task.spawn(function() self:_teleport(player, state) end)
	return true, "Travel to your expedition is starting."
end

function Service:GetRejoinSummary(player)
	if RunService:IsStudio() then return nil end
	local assignment = Store:GetAssignment(player.UserId)
	local record = assignment and Store:Get(assignment.WorldId)
	if not record or not contains(record, player.UserId) or record.Generation ~= assignment.Generation then return nil end
	return { WorldId = record.Id, Available = (active(record) or launching(record)) and record.MatchmakingType == nativeType(),
		Status = record.Ended and "Ended" or record.Phase, RequiresCrew = not active(record) and not launching(record), OwnerCount = #record.Roster }
end

function Service:Rejoin(player)
	if RunService:IsStudio() then return false, "Expedition travel requires published play." end
	if Config.GetMode() ~= "Lobby" then return false, "You are already in an expedition." end
	local assignment, reason = Store:GetAssignment(player.UserId)
	if not assignment then return false, reason or "No active expedition is assigned." end
	local record, errorMessage = Store:Get(assignment.WorldId)
	if not record then return false, errorMessage end
	if record.Generation ~= assignment.Generation or not contains(record, player.UserId) then return false, "That expedition assignment changed." end
	if record.MatchmakingType ~= nativeType() then return false, "This server has incompatible cross-play settings." end
	if not active(record) and not launching(record) then return false, "Reunite and ready this world's original crew to resume it." end
	return self:_queueTravel(player, record)
end

function Service:ReturnToLobby(player, requestId)
	if RunService:IsStudio() then return false, "Travel is disabled in Studio preview." end
	if Config.GetMode() == "Lobby" then return true, "You are already in the lobby." end
	local existing = self._travel[player]
	if existing then
		if existing.Kind == "Lobby" then
			existing.ReturnRequestId = requestId or existing.ReturnRequestId
			return true, "Travel is already being arranged."
		end
		return false, "Another trip is still being arranged. Please try again shortly."
	end
	self:_initTravel()
	local state = { Kind = "Lobby", Attempts = 0, ReturnRequestId = requestId }
	self._travel[player] = state
	task.spawn(function() self:_teleport(player, state) end)
	if self._ending or (self._record and self._record.Ended) then
		return true, "Returning to the lobby. This ended world's save copies are removed."
	end
	return true, "Returning to the lobby. Your expedition state is retained."
end

function Service:Resume(player, slotId)
	if RunService:IsStudio() then return false, "Saved-world travel requires published play." end
	if Config.GetMode() ~= "Lobby" then return false, "Return to the lobby before resuming a saved world." end
	local slot, reason, manifest = Saves:GetOwnedSlot(player, slotId)
	if not slot then return false, reason end
	local record, failure = Store:Get(slot.WorldId)
	if not record then return false, failure end
	if record.Ended or record.Phase == "Ended" then return false, "This expedition ended in a team wipe." end
	if not record.CrewCommitted or not sameRoster(manifest.OwnerIds, record.Roster) then return false, "World commit recovery is still pending." end
	if active(record) then
		if record.MatchmakingType ~= nativeType() then return false, "This server has incompatible cross-play settings." end
		return self:_queueTravel(player, record)
	end
	if launching(record) then self:_publishAssignments(record); return self:_queueTravel(player, record) end
	local party, partyError = Parties:GetParty(player)
	if not party then return false, partyError or "Reform the original crew first." end
	if party.Queue or (party.RunId and party.RunId ~= record.Id) then return false, "Your crew is committed elsewhere." end
	local ids, platform = {}, nil
	for _, member in pairs(party.Members) do
		table.insert(ids, member.UserId)
		local presence, available = Parties:GetPresence(member.UserId)
		if not available then return false, "Crew connections are still synchronizing." end
		if not member.Ready or not presence or not presence.Online or presence.Mode ~= "Lobby" or presence.ExpiresAt <= os.time()
			or presence.Session ~= member.Session then return false, "Every original crew member must be online and ready in a lobby." end
		if not Policy.IsMatchmakingType(presence.MatchmakingType) or (platform and platform ~= presence.MatchmakingType) then return false, "Your crew has incompatible cross-play settings." end
		platform = presence.MatchmakingType
		local other, errorMessage = self:_otherAssignment(member.UserId, record.Id)
		if other == nil then return false, errorMessage end
		if other then return false, "A crew member has another active expedition." end
	end
	if not validRoster(ids) or not sameRoster(ids, record.Roster) then return false, "This shared save needs exactly its original " .. tostring(#record.Roster) .. " crew members." end
	if platform ~= record.MatchmakingType then return false, "Use the saved expedition's cross-play settings." end
	local copiesReady, copyError = Saves:ReconcileRosterForResume(record.Id, record.Roster)
	if not copiesReady then return false, copyError end
	if record.Phase == "Reserving" and record.PartyId == party.Id then
		if record.ResumeToken and not Parties:ReleaseResume(party.Id, record.Id, record.ResumeToken) then
			return true, "Your committed crew is synchronizing before travel."
		end
		local ready = self:_ensureLaunch(record.Id)
		return true, ready and "Your saved world is launching." or "Your existing world reservation is retrying."
	end
	local locked, lockError = Parties:LockResume(party.Id, record, party.Members, player.UserId)
	if not locked then return false, lockError end
	local lock = locked.ResumeCommit
	local resumed, resumeError = Store:Mutate(record.Id, function(current)
		-- A lost acknowledgment may retry after this exact token was adopted.
		if current and current.PartyId == party.Id and current.ResumeToken == lock.Token and current.Generation > lock.Generation then return current end
		if not current or current.Generation ~= lock.Generation or current.ResumeRejectedToken == lock.Token or lock.Until <= os.time()
			or current.Ended or current.Phase == "Ended" or current.Phase == "Aborted"
			or (current.ServerLeaseUntil or 0) > os.time() or launching(current) then return nil, "WorldAlreadyRunning" end
		if current.Phase == "Reserving" and (current.ReservationLeaseUntil or 0) > os.time() then return nil, "ReservationWorkerBusy" end
		current.Generation = current.Generation + 1
		current.Phase, current.PartyId, current.LeaderId = "Reserving", locked.Id, locked.LeaderId
		current.ResumeToken = lock.Token
		current.PrivateServerId, current.PrivateAccessCode, current.ServerJobId, current.ServerLeaseUntil = nil, nil, nil, 0
		current.ReservationLeaseToken, current.ReservationLeaseUntil, current.AdmissionComplete = nil, nil, false
		return current
	end)
	if not resumed then
		local latest = Store:Get(record.Id)
		if latest and latest.PartyId == party.Id and latest.ResumeToken == lock.Token and latest.Generation > lock.Generation then resumed = latest end
	end
	local released = Parties:ReleaseResume(party.Id, record.Id, lock.Token)
	if not resumed and released then
		-- Release can discover an adoption that completed after the prior read.
		local latest = Store:Get(record.Id)
		if not latest then return true, "The resume decision is synchronizing. Keep your crew together." end
		if latest.PartyId == party.Id and latest.ResumeToken == lock.Token and latest.Generation > lock.Generation then resumed = latest end
	end
	if not resumed then
		if released then return false, resumeError or "This resume attempt could not commit. Refresh the saved world." end
		return true, "Resume is still being resolved. Keep your crew together; its reservation is preserved."
	end
	if not released then return true, "Your saved world is committed; crew synchronization is retrying." end
	local ready = self:_ensureLaunch(resumed.Id)
	return true, ready and "Your original crew's saved world is launching." or "Your world reservation is retrying. Keep your crew together."
end

function Service:_loadPlayer(player)
	if self._loading[player] or self._stopped or self._closing or self._finalWanted or player.Parent ~= Players then return end
	self._loading[player] = true
	local ok = pcall(function()
		local expires = os.clock() + 60
		while player.Parent == Players and not Profiles:IsLoaded(player) and not self._stopped do
			assert(os.clock() < expires, "ProfileUnavailable"); task.wait(0.1)
		end
		if player.Parent ~= Players or self._stopped then return end
		if not self._studio then
			assert(active(self._record) and contains(self._record, player.UserId), "WorldAdmissionExpired")
			require(script.Parent.RoleService):ApplyRunRole(player, self._record.Members[tostring(player.UserId)].Role, self._record.Members[tostring(player.UserId)].ClassLevel or 1)
		end
		player:LoadCharacterAsync()
		if player.Parent ~= Players or self._stopped then return end
		local char = assert(player.Character, "CharacterUnavailable")
		assert(char:WaitForChild("Humanoid", 10), "HumanoidUnavailable")
		self._snapshots:RestorePlayer(player)
	end)
	self._loading[player] = nil
	if not ok and player.Parent == Players then
		if player.Character then player.Character:Destroy() end
		player:Kick("Your expedition character could not load safely. Rejoin from the lobby.")
	end
end

function Service:PrepareExpedition()
	RS:SetAttribute("WorldLeaseOwned", false); RS:SetAttribute("WorldLeaseUntil", 0)
	if RunService:IsStudio() then self._studio = true; return true, nil end
	if game.PlaceId ~= Config.ExpeditionPlaceId or game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then return false, "ReservedExpeditionRequired" end
	local record, reason = Store:ResolveReservation(game.PrivateServerId)
	if not record then return false, reason end
	if not record.CrewCommitted or record.Ended or not validRoster(record.Roster) or record.MatchmakingType ~= nativeType() then return false, "InvalidExpeditionAdmission" end
	local manifest, manifestError = Saves:GetManifest(record.Id)
	if not manifest or manifest.State ~= "Committed" or manifest.Token ~= record.SlotToken or not sameRoster(manifest.OwnerIds, record.Roster) then return false, manifestError or "SaveSlotsNotCommitted" end
	local acquired, acquireError = Store:AcquireServer(record, game.JobId, nativeType())
	if not acquired then return false, acquireError end
	self:_adopt(acquired)
	RS:SetAttribute("WorldId", acquired.Id)
	RS:SetAttribute("WorldGeneration", acquired.Generation)
	RS:SetAttribute("WorldSessionState", "AwaitingOriginalCrew")
	self:_startLeaseWorkers(); self:_initTravel()
	local function admit(player)
		if self._stopped or self._closing or self._finalWanted or self._ending then player:Kick("This expedition is pausing or has ended. Reunite with your crew in the lobby."); return end
		if not contains(self._record, player.UserId) then player:Kick("This reserved expedition belongs to another crew."); return end
		self._present[player] = true
		player:SetAttribute("WorldPlayerLoading", true)
		require(script.Parent.RoleService):ApplyRunRole(player, self._record.Members[tostring(player.UserId)].Role, self._record.Members[tostring(player.UserId)].ClassLevel or 1)
		if self._snapshots then task.spawn(function() self:_loadPlayer(player) end) end
	end
	Players.PlayerAdded:Connect(admit)
	Players.PlayerRemoving:Connect(function(player)
		self._present[player] = nil
		if self._snapshots and next(self._present) == nil and not self._stopped then
			self._finalWanted = self._ending and "Ended" or "Paused"
			task.defer(function() self:_save(self._finalWanted) end)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do admit(player) end
	local expires = math.min(acquired.LaunchUntil or os.time() + LAUNCH_SECONDS, os.time() + LAUNCH_SECONDS)
	while not self._stopped do
		local complete = true
		for _, userId in ipairs(acquired.Roster) do if not Players:GetPlayerByUserId(userId) then complete = false; break end end
		if complete then break end
		if os.time() >= expires then self:_stop("OriginalCrewMissing"); return false, "OriginalCrewMissing" end
		task.wait(0.25)
	end
	if self._stopped then return false, "WorldLeaseLost" end
	local snapshot, readError = Store:ReadSnapshot(self._record)
	if readError then self:_stop("SnapshotUnavailable"); return false, readError end
	if snapshot and snapshot.Match and snapshot.Match.MatchState == "GameOver" then self:_stop("ExpeditionEnded"); return false, "ExpeditionEnded" end
	self._loadedSnapshot = snapshot
	return true, snapshot
end

function Service:_save(finalPhase)
	if self._studio or self._stopped or not self._snapshots then return false end
	if finalPhase == "Ended" or not self._finalWanted then self._finalWanted = finalPhase end
	if self._saving then self._saveAgain = true; return false end
	self._saving = true
	local saved = false
	repeat
		self._saveAgain = false
		local phase = self._finalWanted
		local deadline = os.clock() + (self._closing and 12 or 30)
		local generator = require(script.Parent.WorldGenController)
		while generator._busy and os.clock() < deadline and not self._stopped do task.wait(0.1) end
		if self._stopped or generator._busy or not ownedLease(self._record) then break end
		local captured, snapshot = pcall(function() return self._snapshots:Capture() end)
		if not captured then RS:SetAttribute("WorldSaveStatus", "CaptureRetryPending"); break end
		local written, reason = Store:WriteSnapshot(self._record, game.JobId, snapshot, phase)
		if not written then
			RS:SetAttribute("WorldSaveStatus", reason or "SaveRetryPending")
			if reason == "WorldLeaseLost" then self:_stop(reason) end
			break
		end
		self:_adopt(written); saved = true
		Saves:UpdateManifest(written)
		RS:SetAttribute("WorldSaveStatus", "Saved")
		RS:SetAttribute("WorldSavedAt", written.SavedAt)
		if phase then
			self._stopped = true
			RS:SetAttribute("WorldLeaseOwned", false)
			RS:SetAttribute("WorldRestoring", true)
			RS:SetAttribute("WorldSessionState", phase)
			Parties:FinishExpedition(written.PartyId, written.Id)
			break
		end
	until not self._saveAgain
	self._saving = false
	return saved
end

function Service:StartExpedition(snapshots)
	self._snapshots = snapshots
	if self._studio then
		Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_loadPlayer(player) end) end)
		for _, player in ipairs(Players:GetPlayers()) do self:_loadPlayer(player) end
		return true
	end
	if self._stopped or not active(self._record) then return false, "WorldLeaseLost" end
	for _, userId in ipairs(self._record.Roster) do if not Players:GetPlayerByUserId(userId) then self:_stop("OriginalCrewChangedDuringLoad"); return false, "OriginalCrewChangedDuringLoad" end end
	local started, reason = Store:Mutate(self._record.Id, function(current)
		if not current or current.Generation ~= self._record.Generation or current.ServerJobId ~= game.JobId or not active(current) then return nil, "WorldLeaseLost" end
		current.AdmissionComplete = true; return current
	end)
	if not started then self:_stop("WorldActivationPending"); return false, reason end
	self:_adopt(started)
	RS:SetAttribute("WorldSessionState", "Active")
	for _, player in ipairs(Players:GetPlayers()) do self:_loadPlayer(player) end
	local gameState = require(script.Parent.GameStateService)
	gameState:OnStateChanged(function(state)
		if state.MatchState ~= "GameOver" or self._ending then return end
		self._ending = true
		task.spawn(function()
			local ended = Store:Mutate(self._record.Id, function(current)
				if not current or current.Generation ~= self._record.Generation or current.ServerJobId ~= game.JobId or not active(current) then return nil, "WorldLeaseLost" end
				current.Ended = true; return current
			end)
			if ended then
				self:_adopt(ended)
				Saves:UpdateManifest(ended)
			end
			self:_save("Ended")
		end)
	end)
	task.spawn(function()
		local nextSave = os.clock() + SAVE_SECONDS
		while not self._stopped do
			if os.clock() >= nextSave or self._finalWanted then self:_save(self._finalWanted); nextSave = os.clock() + (self._finalWanted and 5 or SAVE_SECONDS) end
			task.wait(1)
		end
	end)
	game:BindToClose(function()
		self._closing = true
		local deadline = os.clock() + 27
		self._finalWanted = self._ending and "Ended" or "Paused"
		task.spawn(function() self:_save(self._finalWanted) end)
		while not self._stopped and os.clock() < deadline do
			if not self._saving then task.spawn(function() self:_save(self._finalWanted) end) end
			task.wait(0.25)
		end
	end)
	-- Publish an initial shared world before the first long autosave interval.
	task.spawn(function() self:_save() end)
	return true
end

function Service:_recover(worldId)
	if self._workers[worldId] then return end
	self._workers[worldId] = true
	local ok = pcall(function()
		local record = Store:Get(worldId)
		if not record then return end
		if record.CrewCommitted then
			Saves:UpdateManifest(record)
			if record.Phase == "CrewCommitted" or record.Phase == "Reserving" then
				if Parties.RestoreExpeditionParty and not Parties:RestoreExpeditionParty(record) then return end
				self:_ensureLaunch(worldId)
			elseif launching(record) or (active(record) and not record.AdmissionComplete) then self:_publishAssignments(record)
			elseif record.Ended or record.Phase == "Paused" or record.Phase == "Ended"
				or (record.Phase == "Active" and not active(record)) or (record.Phase == "Launching" and not launching(record)) then
				Parties:FinishExpedition(record.PartyId, record.Id)
			end
		elseif record.Phase == "Preparing" then
			local status, errorMessage = Parties:GetMergeStatus(worldId)
			if errorMessage or not status then return end
			if status == "Committed" or status == "Complete" then
				local changed = Store:Mutate(worldId, function(current)
					if not current or current.Phase ~= "Preparing" or not current.SlotToken then return nil, "CrewRecoveryPending" end
					current.CrewCommitted, current.Phase = true, "CrewCommitted"; return current
				end)
				if changed and Parties.RestoreExpeditionParty and Parties:RestoreExpeditionParty(changed) then self:_ensureLaunch(worldId) end
			elseif status == "Aborted" then
				local changed = Store:Mutate(worldId, function(current)
					if not current or current.CrewCommitted then return nil, "CrewAlreadyCommitted" end
					current.Phase = "Aborted"; return current
				end)
				if changed and changed.SlotToken then Saves:AbortRoster(changed.Id, changed.SlotToken) end
			end
		elseif record.Phase == "Aborted" and record.SlotToken then
			Saves:AbortRoster(record.Id, record.SlotToken)
		end
	end)
	self._workers[worldId] = nil
	if not ok then warn("[WorldSession] Durable expedition recovery will retry.") end
end

function Service:Init()
	if self._lobbyStarted or Config.GetMode() ~= "Lobby" or RunService:IsStudio() then return end
	self._lobbyStarted = true
	self:_initTravel()
	task.spawn(function()
		while true do
			local recover = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local assignment = Store:GetAssignment(player.UserId)
				local record = assignment and Store:Get(assignment.WorldId)
				if record and record.Generation == assignment.Generation and contains(record, player.UserId) then
					recover[record.Id] = true
					if (launching(record) or (active(record) and not record.AdmissionComplete)) and record.MatchmakingType == nativeType() then self:_queueTravel(player, record) end
				end
				if (self._recoveryAt[player] or 0) <= os.clock() then
					self._recoveryAt[player] = os.clock() + 60
					for _, worldId in ipairs(Saves:GetRecoveryWorldIds(player) or {}) do recover[worldId] = true end
				end
			end
			for worldId in pairs(recover) do task.spawn(function() self:_recover(worldId) end) end
			task.wait(10)
		end
	end)
end

return Service
