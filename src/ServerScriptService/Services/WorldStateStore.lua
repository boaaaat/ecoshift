-- Durable session authority. Immutable snapshot chunks become visible through one
-- fenced pointer update; a stale server can never publish over its successor.
local DSS = game:GetService("DataStoreService")
local Http = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Util = require(Shared.Util)
local Biomes = require(Shared.OverhaulBiomes)
local records = DSS:GetDataStore("EcoshiftWorldSessions_Overhaul_20260912")
local chunks = DSS:GetDataStore("EcoshiftWorldSnapshots_Overhaul_20260912")
local reservations = DSS:GetDataStore("EcoshiftReservedWorlds_Overhaul_20260912")
local assignments = DSS:GetDataStore("EcoshiftRunAssignments_Overhaul_20260912")
local Service = { LeaseSeconds = 120 }
local fresh = Instance.new("DataStoreGetOptions")
fresh.UseCache = false

local function validId(id)
	return type(id) == "string" and #id > 0 and #id <= 40 and id:match("^[%w_:%-]+$") ~= nil
end
local function call(fn)
	local ok, value
	for attempt = 1, 3 do
		ok, value = pcall(fn)
		if ok then return true, value end
		if attempt < 3 then task.wait(attempt) end
	end
	warn("[WorldStateStore] Storage unavailable:", value)
	return false, "WorldStorageUnavailable"
end
function Service:Get(id)
	if not validId(id) then return nil, "InvalidWorldId" end
	local ok, record = call(function() return records:GetAsync(id, fresh) end)
	if not ok then return nil, record end
	if not record then return nil, "WorldNotFound" end
	if record.SchemaVersion ~= 1 or record.Id ~= id or record.GameplayRulesVersion ~= 2 or record.ContentRelease ~= 2 then return nil, "UnsupportedWorldVersion" end
	return record
end
function Service:Mutate(id, transform)
	if not validId(id) then return nil, "InvalidWorldId" end
	local reason
	local ok, result = call(function() return records:UpdateAsync(id, function(raw)
		reason = nil
		if raw and (raw.SchemaVersion ~= 1 or raw.Id ~= id or raw.GameplayRulesVersion ~= 2 or raw.ContentRelease ~= 2) then reason = "UnsupportedWorldVersion"; return nil end
		local nextValue, failure = transform(raw and Util.DeepCopy(raw))
		if not nextValue then reason = failure or "WorldChanged"; return nil end
		nextValue.Revision = (raw and raw.Revision or 0) + 1
		nextValue.UpdatedAt = os.time()
		return nextValue
	end) end)
	if not ok or reason then return nil, reason or result end
	return result
end
function Service:Assign(userId, record)
	local value = { WorldId = record.Id, Generation = record.Generation, IssuedAt = record.LaunchedAt }
	local ok, result = call(function() return assignments:UpdateAsync(tostring(userId), function(old)
		if old and old.IssuedAt > value.IssuedAt then return nil end
		if old and old.WorldId==value.WorldId and old.Generation>value.Generation then return nil end
		if old and old.IssuedAt==value.IssuedAt and old.WorldId~=value.WorldId then return nil end
		return value
	end) end)
	return ok and result and result.WorldId == record.Id and result.Generation == record.Generation
end
function Service:GetAssignment(userId)
	local ok, value = call(function() return assignments:GetAsync(tostring(userId), fresh) end)
	if not ok then return nil,"WorldStorageUnavailable" end
	return value
end
function Service:RegisterReservation(record)
	local ok = call(function() return reservations:SetAsync(record.PrivateServerId, {
		WorldId = record.Id, Generation = record.Generation,
		GameplayRulesVersion = record.GameplayRulesVersion, ContentRelease = record.ContentRelease,
	}) end)
	return ok
end
function Service:ResolveReservation(privateServerId)
	if type(privateServerId) ~= "string" or #privateServerId == 0 then return nil, "ReservedExpeditionRequired" end
	local ok, link = call(function() return reservations:GetAsync(privateServerId, fresh) end)
	if not ok or not link then return nil, "ReservationUnavailable" end
	local record, reason = self:Get(link.WorldId)
	if not record then return nil, reason end
	if record.Generation ~= link.Generation or record.PrivateServerId ~= privateServerId then return nil, "ReservationExpired" end
	if (record.GameplayRulesVersion) ~= (link.GameplayRulesVersion) then return nil, "WorldRulesMismatch" end
	return record
end
function Service:AcquireServer(record, jobId, nativeType)
	return self:Mutate(record.Id, function(current)
		if not current or current.Generation ~= record.Generation or current.PrivateServerId ~= game.PrivateServerId
			or current.MatchmakingType ~= nativeType then return nil, "ReservationChanged" end
		if current.Phase ~= "Launching" and current.Phase ~= "Active" then return nil, "CrewResumeRequired" end
		if current.Phase == "Launching" and (current.LaunchUntil or 0) <= os.time() then return nil, "CrewResumeRequired" end
		if current.ServerJobId and current.ServerJobId ~= jobId then
			-- A stopped generation must be resumed by the full crew with a new reservation.
			return nil, (current.ServerLeaseUntil or 0) > os.time() and "WorldAlreadyRunning" or "CrewResumeRequired"
		end
		current.ServerJobId, current.ServerLeaseUntil = jobId, os.time() + self.LeaseSeconds
		current.Phase = "Active"
		return current
	end)
end
function Service:Renew(record, jobId)
	return self:Mutate(record.Id, function(current)
		if not current or current.Generation ~= record.Generation or current.ServerJobId ~= jobId
			or current.Phase ~= "Active" or (current.ServerLeaseUntil or 0) <= os.time() then return nil, "WorldLeaseLost" end
		current.ServerLeaseUntil = os.time() + self.LeaseSeconds
		return current
	end)
end
local function split(text)
	local result, start = {}, 1
	while start <= #text do
		local last = math.min(start + 999999, #text)
		-- DataStore strings must be valid UTF-8, including chunk boundaries.
		if last < #text then
			while text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last -= 1 end
		end
		table.insert(result, text:sub(start, last)); start = last + 1
	end
	return result
end

local function mapCount(value)
	local total = 0
	for _ in pairs(type(value) == "table" and value or {}) do total += 1 end
	return total
end

local function archiveStats(snapshot)
	local visits, visited, totalVisits = snapshot.Biome and (snapshot.Biome.Encounters or snapshot.Biome.Visits) or {}, {}, 0
	for _, biomeId in ipairs(Biomes.Order) do
		local count = tonumber(visits[biomeId]) or 0
		if count > 0 then
			table.insert(visited, biomeId)
			totalVisits += math.floor(count)
		end
	end
	local subBiomeVisits, visitedSubBiomes = snapshot.Biome and snapshot.Biome.SubBiomeVisits or {}, {}
	for _, biomeId in ipairs(Biomes.Order) do
		local byRegion = type(subBiomeVisits[biomeId]) == "table" and subBiomeVisits[biomeId] or {}
		for _, region in ipairs(Biomes.Biomes[biomeId].Regions or {}) do
			if byRegion[region.Id] == true then table.insert(visitedSubBiomes, biomeId .. "/" .. region.Id) end
		end
	end
	local rewards = snapshot.Auxiliary and snapshot.Auxiliary.ExpeditionRewardsService
	local rewardPlayers = rewards and rewards.Players or {}
	local playerRecords, deaths, revives, defeats = {}, 0, 0, 0
	for key, record in pairs(snapshot.RunStats or {}) do
		local userId = tonumber(key)
		if userId and type(record) == "table" then
			local playerDeaths = math.max(0, math.floor(tonumber(record.Deaths) or 0))
			local playerRevives = math.max(0, math.floor(tonumber(record.Revives) or 0))
			local playerDefeats = math.max(0, math.floor(tonumber(record.MonsterDefeats) or 0))
			local reward = rewardPlayers[key] or rewardPlayers[tostring(userId)]
			deaths += playerDeaths; revives += playerRevives; defeats += playerDefeats
			table.insert(playerRecords, {
				UserId = userId, SurvivedSeconds = math.max(0, math.floor(tonumber(reward and reward.SurvivedSeconds) or 0)),
				Deaths = playerDeaths, Revives = playerRevives, MonsterDefeats = playerDefeats,
			})
		end
	end
	table.sort(playerRecords, function(a, b) return a.UserId < b.UserId end)
	local objectives = snapshot.Auxiliary and snapshot.Auxiliary.ObjectiveService
	return {
		SchemaVersion = 2,
		PlaySeconds = math.max(0, math.floor(tonumber(snapshot.Round and snapshot.Round.Elapsed) or 0)),
		NightsSurvived = math.max(0, math.floor(tonumber(snapshot.DayNight and snapshot.DayNight.NightsSurvived) or 0)),
		BiomeShifts = math.max(0, math.floor(tonumber(snapshot.Biome and snapshot.Biome.ShiftCount) or 0)),
		BiomeVisits = totalVisits, UniqueBiomes = #visited, VisitedBiomes = visited,
		UniqueSubBiomes = #visitedSubBiomes, VisitedSubBiomes = visitedSubBiomes,
		MonsterDefeats = defeats, ObjectivesCompleted = mapCount(objectives and objectives.Claimed),
		StructuresStanding = #(snapshot.Structures or {}), CrewDeaths = deaths, CrewRevives = revives,
		CampaignTier = math.clamp(math.floor(tonumber(snapshot.Campaign and snapshot.Campaign.Tier) or 1), 1, 8),
		PlayerRecords = playerRecords,
	}
end

function Service:WriteSnapshot(record, jobId, snapshot, finalPhase)
	local encodedOK, encoded = pcall(function() return Http:JSONEncode(snapshot) end)
	if not encodedOK or #encoded > 16000000 then return nil, "SnapshotTooLargeOrInvalid" end
	local pieces, nonce = split(encoded), Http:GenerateGUID(false)
	for index, piece in ipairs(pieces) do
		local ok = call(function() return chunks:SetAsync(nonce .. ":" .. index, piece) end)
		if not ok then return nil, "SnapshotWritePending" end
	end
	local reference = { Id = nonce, Count = #pieces, Bytes = #encoded }
	local obsolete
	local updated, reason = self:Mutate(record.Id, function(current)
		-- UpdateAsync can commit despite a transport error. Repeating this exact
		-- pointer publication must acknowledge it before checking a final phase.
		if current and current.Snapshot and current.Snapshot.Id==nonce then obsolete=nil; return current end
		if not current or current.Generation ~= record.Generation or current.ServerJobId ~= jobId
			or current.Phase ~= "Active" or (current.ServerLeaseUntil or 0) <= os.time() then return nil, "WorldLeaseLost" end
		obsolete = current.PreviousSnapshot
		current.PreviousSnapshot, current.Snapshot = current.Snapshot, reference
		current.SnapshotRevision = (current.SnapshotRevision or 0) + 1
		current.SavedAt = os.time()
		current.ArchiveBiome = snapshot.Biome and snapshot.Biome.Biome or current.ArchiveBiome
		current.ArchiveElapsed = snapshot.Round and snapshot.Round.Elapsed or current.ArchiveElapsed
		current.ArchiveStats = archiveStats(snapshot)
		if finalPhase then
			current.Phase = finalPhase
			current.ServerLeaseUntil = 0
		end
		return current
	end)
	if updated and obsolete and obsolete.Id~=updated.Snapshot.Id
		and (not updated.PreviousSnapshot or obsolete.Id~=updated.PreviousSnapshot.Id) then
		task.spawn(function()
			for index = 1, obsolete.Count do call(function() chunks:RemoveAsync(obsolete.Id .. ":" .. index) end) end
		end)
	end
	return updated, reason
end
local function readReference(ref)
	if not ref then return nil, nil end
	if not validId(ref.Id) or type(ref.Count) ~= "number" or ref.Count < 1 or ref.Count > 17 then return nil, "InvalidSnapshot" end
	local pieces = {}
	for index = 1, ref.Count do
		local ok, piece = call(function() return chunks:GetAsync(ref.Id .. ":" .. index) end)
		if not ok or type(piece) ~= "string" then return nil, "SnapshotUnavailable" end
		table.insert(pieces, piece)
	end
	local encoded = table.concat(pieces)
	if #encoded ~= ref.Bytes then return nil, "IncompleteSnapshot" end
	local ok, snapshot = pcall(function() return Http:JSONDecode(encoded) end)
	if not ok or type(snapshot) ~= "table" then return nil, "InvalidSnapshot" end
	return snapshot
end
function Service:ReadSnapshot(record, validator)
	local snapshot, reason = readReference(record.Snapshot)
	if snapshot and validator then
		local called, valid = pcall(validator, snapshot)
		if not called or valid ~= true then snapshot, reason = nil, "InvalidSnapshot" end
	end
	if snapshot then return snapshot, nil, false end
	-- The previous immutable checkpoint is retained specifically so a corrupt or
	-- incomplete latest publication cannot destroy a resumable world.
	local previous, previousReason = readReference(record.PreviousSnapshot)
	if previous and validator then
		local called, valid = pcall(validator, previous)
		if not called or valid ~= true then previous, previousReason = nil, "InvalidPreviousSnapshot" end
	end
	if previous then return previous, nil, true end
	return nil, reason or previousReason
end
return Service
