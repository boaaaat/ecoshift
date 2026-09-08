-- Cross-server parties. Membership outlives a connection; presence owns a server session.
local Players = game:GetService("Players")
local MemoryStore = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.SessionConfig)
local MatchmakingPolicy = require(ReplicatedStorage.Shared.MatchmakingPolicy)
local PartyService = { _sessions = {}, _busy = {}, _lastRequest = {} }
local parties = MemoryStore:GetHashMap(Config.Namespace .. ":parties")
local membership = MemoryStore:GetHashMap(Config.Namespace .. ":members")
local presence = MemoryStore:GetHashMap(Config.Namespace .. ":presence")
local invites = MemoryStore:GetHashMap(Config.Namespace .. ":invites")
local merges = MemoryStore:GetHashMap(Config.Namespace .. ":party-merges")
local function key(userId) return tostring(userId) end
local function guid() return HttpService:GenerateGUID(false) end
local function count(map) local n=0; for _ in pairs(map or {}) do n+=1 end; return n end
local function validUserId(userId)
	return type(userId)=="number" and userId>0 and userId<2^53 and userId%1==0
end
local function rosterSet(roster)
	if type(roster)~="table" then return nil end
	local size=count(roster)
	if size<1 or size>Config.MaxPartySize then return nil end
	local seen={}
	for index,userId in pairs(roster) do
		if type(index)~="number" or index%1~=0 or index<1 or index>size or not validUserId(userId) or seen[key(userId)] then return nil end
		seen[key(userId)]=true
	end
	return seen,size
end
local function launchKind(mode)
	if mode==nil or mode=="Matchmaking" then return "Matchmaking" end
	if mode=="Party" then return "Party" end
	if mode=="LobbyMerge" then return "LobbyMerge" end
	return nil
end
local function queueKind(queue)
	return queue.Purpose=="LobbyMerge" and "LobbyMerge" or launchKind(queue.Mode)
end
local function memberRoster(members)
	if type(members)~="table" then return nil end
	local roster={}
	for id,member in pairs(members) do
		if type(member)~="table" or not validUserId(member.UserId) or id~=key(member.UserId) then return nil end
		table.insert(roster,member.UserId)
	end
	table.sort(roster)
	local seen,size=rosterSet(roster)
	return seen and roster or nil,seen,size
end
local function call(callback)
	local ok, value = pcall(callback)
	if not ok then warn("[PartyService] Shared session storage unavailable:", value) end
	return ok, value
end
local function online(p)
	return p and (p.Online or (p.TransferUntil or 0) > os.time()) and (p.ExpiresAt or 0) > os.time()
end
local function sessionWins(session, previousAt, previousId)
	return not previousAt or session.StartedAt > previousAt or (session.StartedAt == previousAt and session.Id >= (previousId or ""))
end
local function sameLock(lock, worldId, matchId)
	return lock and lock.WorldId == worldId and lock.MatchId == matchId
end
local function recoveryBusy(link)
	return link and link.RecoveryLock and (link.RecoveryLock.Until or 0)>os.time()
end

function PartyService:GetPartyById(id, depth)
	if type(id) ~= "string" then return nil, "No party." end
	if (depth or 0)>6 then return nil,"Party service is temporarily unavailable." end
	local ok, record = call(function() return parties:GetAsync(id) end)
	if not ok then return nil, "Party service is temporarily unavailable." end
	if record and record.RecoveryPending then
		if recoveryBusy(record) then return nil,"Crew recovery is in progress." end
		return nil
	end
	if record and record.MergedInto then return self:GetPartyById(record.MergedInto,(depth or 0)+1) end
	if record and not record.Closed and not record.RunId and not record.MergeLock then
		local anyOnline=false
		for _,member in pairs(record.Members) do if (member.OnlineUntil or record.CreatedAt+Config.PresenceTTL)>os.time() then anyOnline=true end end
		if not anyOnline then
			local refreshed,err=self:Mutate(id,function(current)
				if current.RunId or current.MergeLock then return true end
				for _,member in pairs(current.Members) do if (member.OnlineUntil or current.CreatedAt+Config.PresenceTTL)>os.time() then return true end end
				current.Closed=true; current.Queue=nil; return true
			end)
			if not refreshed then return nil,err end
			record=refreshed
		end
	end
	return record and not record.Closed and record or nil
end

function PartyService:GetParty(player)
	local ok, link = call(function() return membership:GetAsync(key(player.UserId)) end)
	if not ok then return nil, "Party service is temporarily unavailable." end
	if not link or not link.PartyId then return nil end
	local record, err = self:GetPartyById(link.PartyId)
	if record and record.Members[key(player.UserId)] then return record end
	return nil, err
end

function PartyService:Mutate(id, transform, mergeOwner)
	local reason
	local ok, record = call(function()
		return parties:UpdateAsync(id, function(current)
			reason = nil
			if not current or current.Closed then reason = "That party has ended."; return nil end
			if current.RecoveryPending then reason="Crew recovery is in progress."; return nil end
			if current.MergeLock and not (mergeOwner and sameLock(current.MergeLock,mergeOwner.WorldId,mergeOwner.MatchId)) then
				reason = "Your crew is committing to an expedition. Please wait."; return nil
			end
			local accepted, message = transform(current)
			if not accepted then reason=message; return nil end
			current.Revision = (current.Revision or 0) + 1
			return current
		end, Config.PartyTTL)
	end)
	if not ok then return nil, "Party service is temporarily unavailable." end
	if reason then return nil, reason end
	return record
end

function PartyService:_member(player)
	return { UserId=player.UserId, Name=player.Name, DisplayName=player.DisplayName,
		Role=player:GetAttribute("Role") or "Generalist", JoinedAt=os.time(), Ready=false, OnlineUntil=os.time()+Config.PresenceTTL,
		Session=self._sessions[player] and self._sessions[player].Id,
		SessionAt=self._sessions[player] and self._sessions[player].StartedAt }
end

function PartyService:_claim(player, partyId)
	local session=self._sessions[player]
	if not session or not session.Established or session.Leaving then return false,"Your connection is still synchronizing." end
	local read, observed = call(function() return membership:GetAsync(key(player.UserId)) end)
	if not read then return false,"Party service is temporarily unavailable." end
	if observed and observed.MergeLock then
		local lock=observed.MergeLock
		local state=self:GetMergeStatus(lock.WorldId)
		if state=="Aborted" then
			local cleaned,result=call(function() return membership:UpdateAsync(key(player.UserId),function(old)
				if old and sameLock(old.MergeLock,lock.WorldId,lock.MatchId) then old.MergeLock=nil; return old end
				return nil
			end,Config.PartyTTL) end)
			if not cleaned or not result then return false,"Membership recovery is retrying." end
			observed=result
		end
	end
	if observed and observed.PartyId then
		local current, err = self:GetPartyById(observed.PartyId)
		if err then return false, err end
		if current and current.Members[key(player.UserId)] then return false,"Leave your current party first." end
	end
	local token=guid()
	local ok, result=call(function()
		return membership:UpdateAsync(key(player.UserId), function(old)
			if self._sessions[player]~=session or session.Leaving or player.Parent~=Players then return nil end
			if old and (old.MergeLock or recoveryBusy(old) or old.Session~=session.Id or not sessionWins(session,old.SessionAt,old.Session)) then return nil end
			-- Compare the exact observed claim; a concurrent create/join wins only once.
			if old and old.ClaimUntil and old.ClaimUntil > os.time() then return nil end
			if (old and old.PartyId)~=(observed and observed.PartyId) or (old and old.Token)~=(observed and observed.Token) then return nil end
			return {PartyId=partyId,Token=token,ClaimUntil=os.time()+30,Session=session.Id,SessionAt=session.StartedAt}
		end, Config.PartyTTL)
	end)
	return ok and result and result.Token==token, "Your party membership changed. Try again.", token
end

function PartyService:_release(player, partyId, token)
	local session=self._sessions[player]
	if not session then return end
	local ok,result=call(function() return membership:UpdateAsync(key(player.UserId), function(old)
		if old and not old.MergeLock and not recoveryBusy(old) and old.PartyId==partyId and old.Session==session.Id and (not token or old.Token==token) then
			return {ClearedAt=os.time(),Session=session.Id,SessionAt=session.StartedAt}
		end
		return nil
	end, Config.PartyTTL) end)
	if ok and result and not result.PartyId and self._sessions[player]==session then player:SetAttribute("PartyId",nil) end
end

function PartyService:Create(player)
	local id=guid()
	local claimed, reason, token=self:_claim(player,id)
	if not claimed then return false,reason end
	local record={Id=id,LeaderId=player.UserId,Members={[key(player.UserId)]=self:_member(player)},Revision=1,CreatedAt=os.time()}
	local ok=call(function() parties:SetAsync(id,record,Config.PartyTTL) end)
	if not ok then self:_release(player,id,token); return false,"Could not create party. Try again." end
	player:SetAttribute("PartyId",id)
	return true,"Party created."
end

function PartyService:Invite(player, target)
	local numeric=type(target)=="number"
	if numeric then
		if target~=target or target%1~=0 or target<=0 or target>=2^53 then return false,"Choose a valid Roblox player." end
	elseif type(target)~="string" or #target<3 or #target>20 or not target:match("^[%w_]+$") then return false,"Enter a Roblox username." end
	local now=os.clock()
	if now-(self._lastRequest[player] or -math.huge)<2 then return false,"Wait a moment before inviting another player." end
	self._lastRequest[player]=now
	local party, err=self:GetParty(player)
	if not party then return false,err or "Create a party first." end
	if party.LeaderId~=player.UserId then return false,"Only the party leader can invite." end
	if party.Queue or party.RunId or party.MergeLock then return false,"Finish the current expedition or queue first." end
	if count(party.Members)>=Config.MaxPartySize then return false,"Your party has six members." end
	local ok,userId=pcall(function()
		if numeric then return target end
		local localTarget=Players:FindFirstChild(target)
		return localTarget and localTarget.UserId or Players:GetUserIdFromNameAsync(target)
	end)
	if not ok or userId==player.UserId then return false,"That player could not be invited." end
	if party.Members[key(userId)] then return false,"That player is already in your party." end
	-- Numeric IDs and client friend labels confer no permission. Only verified
	-- EcoShift lobby presence is eligible for an in-experience party invitation.
	local localTarget=Players:GetPlayerByUserId(userId)
	if localTarget then
		if Config.GetMode()~="Lobby" then return false,"That player must return to the lobby before joining a new crew." end
	else
		local targetPresence,available=self:GetPresence(userId)
		if not available then return false,"That player's connection is still synchronizing. Try again shortly." end
		if not online(targetPresence) then return false,"That player is outside EcoShift. Use the Roblox friend invite to bring them here first." end
		if targetPresence.Mode~="Lobby" then return false,"That player must return to the lobby before joining a new crew." end
	end
	local inviteId=guid()
	local createdAt=os.time()
	local invitation={Id=inviteId,PartyId=party.Id,From=player.DisplayName,FromUserId=player.UserId,
		CreatedAt=createdAt,ExpiresAt=createdAt+Config.InviteSeconds}
	local saved,stored=call(function() return invites:UpdateAsync(key(userId),function(list)
		local nextList={}
		for _,v in ipairs(list or {}) do if v.ExpiresAt>os.time() and v.PartyId~=party.Id then table.insert(nextList,v) end end
		while #nextList>=8 do table.remove(nextList,1) end
		table.insert(nextList,invitation)
		return nextList
	end,Config.InviteSeconds) end)
	local confirmed=false
	if saved and type(stored)=="table" then
		for _,item in ipairs(stored) do if item.Id==inviteId then confirmed=true; break end end
	end
	if confirmed and self.OnInvitation then
		local recipient=Players:GetPlayerByUserId(userId)
		if recipient and recipient.Parent==Players then
			-- Delivery is a convenience; the persisted inbox remains authoritative
			-- when the recipient reconnects or receives an invite from another server.
			local delivered,reason=pcall(self.OnInvitation,recipient,table.clone(invitation))
			if not delivered then warn("[PartyService] Invitation notice will refresh from the inbox:",reason) end
		end
	end
	return confirmed,confirmed and "Invitation sent." or "Could not send invitation."
end

function PartyService:GetInvites(player)
	local ok,list=call(function() return invites:GetAsync(key(player.UserId)) end)
	if not ok then return {},false end
	local active={}
	for _,item in ipairs(type(list)=="table" and list or {}) do
		if type(item)=="table" and type(item.Id)=="string" and type(item.PartyId)=="string"
			and type(item.ExpiresAt)=="number" and item.ExpiresAt>os.time() then table.insert(active,table.clone(item)) end
	end
	return active,true
end

function PartyService:Accept(player, inviteId)
	if type(inviteId)~="string" or #inviteId>64 then return false,"Invalid invitation." end
	local ok,list=call(function() return invites:GetAsync(key(player.UserId)) end)
	if not ok then return false,"Invitations are temporarily unavailable." end
	local invite
	for _,v in ipairs(list or {}) do if v.Id==inviteId and v.ExpiresAt>os.time() then invite=v end end
	if not invite then return false,"That invitation has expired." end
	local claimed, reason, token=self:_claim(player,invite.PartyId)
	if not claimed then return false,reason end
	local member=self:_member(player)
	local record,err=self:Mutate(invite.PartyId,function(party)
		if party.Queue or party.RunId then return false,"That party is already on an expedition." end
		if count(party.Members)>=Config.MaxPartySize then return false,"That party is full." end
		party.Members[key(player.UserId)]=member
		return true
	end)
	if not record then self:_release(player,invite.PartyId,token); return false,err end
	player:SetAttribute("PartyId",record.Id)
	call(function() invites:UpdateAsync(key(player.UserId),function(current)
		local keep={}; for _,v in ipairs(current or {}) do if v.Id~=inviteId then table.insert(keep,v) end end
		return keep
	end,Config.InviteSeconds) end)
	return true,"Joined the party."
end

function PartyService:Leave(player)
	local party,err=self:GetParty(player)
	if not party then return false,err or "You are not in a party." end
	local result,reason=self:Mutate(party.Id,function(record)
		if record.Queue then return false,"Cancel matchmaking before leaving." end
		record.Members[key(player.UserId)]=nil
		if count(record.Members)==0 then record.Closed=true
		elseif record.LeaderId==player.UserId then
			local first
			for _,member in pairs(record.Members) do if not first or member.JoinedAt<first.JoinedAt then first=member end end
			record.LeaderId=first.UserId
		end
		return true
	end)
	if not result then return false,reason end
	self:_release(player,party.Id)
	return true,"Left the party. Your run rejoin remains available."
end

-- Leadership actions use the caller's established connection and the exact
-- observed member. A delayed kick must never clear a newer membership claim.
function PartyService:_manageMember(player, userId, transfer)
	if not validUserId(userId) or userId==player.UserId then return false,"Choose another crew member." end
	if Config.GetMode()~="Lobby" then return false,"Crew management is available in the lobby." end
	local session=self._sessions[player]
	if not session or not session.Established or session.Leaving or player.Parent~=Players then return false,"Your connection is still synchronizing." end
	local party,err=self:GetParty(player)
	if not party then return false,err or "Create or join a party first." end
	if party.LeaderId~=player.UserId then return false,"Only the party leader can manage the crew." end
	if party.Queue or party.RunId or party.MergeLock or party.ResumeCommit or party.RecoveryPending then return false,"Cancel matchmaking or finish the current launch first." end
	local target=party.Members[key(userId)]
	local caller=party.Members[key(player.UserId)]
	if not target or not caller or caller.Session~=session.Id or caller.SessionAt~=session.StartedAt then return false,"Your crew or connection changed. Try again." end
	local p,available=self:GetPresence(player.UserId)
	if not available or not online(p) or not p.Online or p.Mode~="Lobby" or p.Session~=session.Id or p.SessionAt~=session.StartedAt then return false,"Your connection is still synchronizing." end
	local read,observed=call(function() return membership:GetAsync(key(userId)) end)
	if not read then return false,"Party service is temporarily unavailable." end
	if not observed or observed.PartyId~=party.Id or observed.Session~=target.Session or observed.SessionAt~=target.SessionAt
		or observed.MergeLock or recoveryBusy(observed) then return false,"That member's connection or party changed. Try again." end
	if transfer then
		local targetPresence,known=self:GetPresence(userId)
		if not known or not online(targetPresence) or not targetPresence.Online or targetPresence.Mode~="Lobby" or targetPresence.Session~=target.Session
			or targetPresence.SessionAt~=target.SessionAt then return false,"The new leader must be online in the lobby." end
	end
	local result,reason=self:Mutate(party.Id,function(current)
		local actor,member=current.Members[key(player.UserId)],current.Members[key(userId)]
		if self._sessions[player]~=session or session.Leaving or player.Parent~=Players or not actor
			or actor.Session~=session.Id or actor.SessionAt~=session.StartedAt then return false,"Your connection changed." end
		if current.LeaderId~=player.UserId then return false,"Only the party leader can manage the crew." end
		if current.Queue or current.RunId or current.MergeLock or current.ResumeCommit or current.RecoveryPending then return false,"Cancel matchmaking or finish the current launch first." end
		if not member or member.Session~=target.Session or member.SessionAt~=target.SessionAt or member.JoinedAt~=target.JoinedAt then return false,"That crew member changed. Try again." end
		if transfer then current.LeaderId=userId else current.Members[key(userId)]=nil end
		for _,remaining in pairs(current.Members) do remaining.Ready=false end
		return true
	end)
	if not result then return false,reason end
	if not transfer then
		call(function() return membership:UpdateAsync(key(userId),function(link)
			if not link or link.PartyId~=party.Id or link.Token~=observed.Token or link.Session~=observed.Session
				or link.SessionAt~=observed.SessionAt or link.MergeLock or recoveryBusy(link) then return nil end
			return {ClearedAt=os.time(),Session=link.Session,SessionAt=link.SessionAt}
		end,Config.PartyTTL) end)
	end
	return true,transfer and "Party leadership transferred. Everyone must ready up again." or "Player removed from the crew. Everyone must ready up again."
end

function PartyService:KickMember(player,userId) return self:_manageMember(player,userId,false) end
function PartyService:TransferLeader(player,userId) return self:_manageMember(player,userId,true) end

function PartyService:SetReady(player, ready)
	if type(ready)~="boolean" then return false,"Invalid ready state." end
	local party,err=self:GetParty(player)
	if not party then return false,err or "Create or join a party first." end
	local result,reason=self:Mutate(party.Id,function(record)
		if record.Queue or record.RunId then return false,"Your party is already committed to an expedition." end
		local member=record.Members[key(player.UserId)]
		if not member then return false,"Your party membership changed." end
		member.Ready,member.Role=ready,player:GetAttribute("Role") or "Generalist"
		return true
	end)
	return result~=nil,reason or (ready and "Ready for expedition." or "No longer ready.")
end

function PartyService:GetPresence(userId)
	local ok,p=call(function() return presence:GetAsync(key(userId)) end)
	return ok and p or nil,ok
end

function PartyService:Heartbeat(player, leaving)
	local session=self._sessions[player]
	if not session then return end
	leaving=leaving or session.Leaving or player.Parent~=Players
	local now=os.time()
	local expiry=math.max(now+Config.PresenceTTL,session.TransferUntil or 0)
	local ok,updated=call(function() return presence:UpdateAsync(key(player.UserId),function(old)
		if self._sessions[player]~=session then return nil end
		if old and old.Session~=session.Id then return nil end
		return {Session=session.Id,SessionAt=session.StartedAt,JobId=game.JobId,PlaceId=game.PlaceId,Mode=Config.GetMode(),MatchmakingType=game.MatchmakingType.Name,
			Online=not (leaving or session.Leaving or player.Parent~=Players),TransferUntil=session.TransferUntil,ExpiresAt=expiry}
	end,expiry-now) end)
	if not ok or not updated or updated.Session~=session.Id then return end
	local party=self:GetParty(player)
	if party and leaving and not session.TransferUntil and party.Queue then self:CancelQueue(party.Id,party.Queue.Token) end
	if party then self:Mutate(party.Id,function(record)
		local member=record.Members[key(player.UserId)]
		if not member then return false,"Membership changed." end
		if not sessionWins(session,member.SessionAt,member.Session) then return false,"Connection changed." end
		member.Session,member.SessionAt=session.Id,session.StartedAt
		member.OnlineUntil=leaving and (session.TransferUntil or 0) or now+Config.PresenceTTL
		return true
	end,party.MergeLock) end
end

function PartyService:BeginTransfer(player)
	local session=self._sessions[player]
	if session then session.TransferUntil=os.time()+Config.TransferSeconds; self:Heartbeat(player) end
end
function PartyService:CancelTransfer(player)
	local session=self._sessions[player]
	if session then session.TransferUntil=nil; self:Heartbeat(player) end
end

function PartyService:RefreshParty(party)
	if party.ResumeCommit and (party.ResumeCommit.Until or 0)<=os.time() then
		local released=self:ReleaseResume(party.Id,party.RunId,party.ResumeCommit.Token)
		if released then party=self:GetPartyById(party.Id); if not party then return end end
	end
	if party.MergeLock and party.Queue then
		local state=self:GetMergeStatus(party.MergeLock.WorldId)
		if state=="Aborted" then self:CancelQueue(party.Id,party.Queue.Token) end
	end
	local stale=false
	for _,member in pairs(party.Members) do if (member.OnlineUntil or party.CreatedAt+Config.PresenceTTL)<=os.time() then stale=true end end
	if stale and party.Queue then self:CancelQueue(party.Id,party.Queue.Token) end
	local anyOnline=false
	self:Mutate(party.Id,function(current)
		anyOnline=false
		local allOnline=true
		for _,member in pairs(current.Members) do
			if (member.OnlineUntil or current.CreatedAt+Config.PresenceTTL)>os.time() then anyOnline=true else allOnline=false end
		end
		if not allOnline and current.Queue then return false,"Connection refresh is pending." end
		if not anyOnline and not current.RunId then current.Closed=true end
		return true
	end)
	if anyOnline then
		for id in pairs(party.Members) do
			local ok,link=call(function() return membership:UpdateAsync(id,function(current)
				if current and current.PartyId==party.Id then
					if not current.MergeLock then current.ClaimUntil=nil end
					return current
				end
				return nil
			end,Config.PartyTTL) end)
			if ok and link and link.MergeLock and self:GetMergeStatus(link.MergeLock.WorldId)=="Aborted" then
				local lock=link.MergeLock
				call(function() return membership:UpdateAsync(id,function(current)
					if current and sameLock(current.MergeLock,lock.WorldId,lock.MatchId) then current.MergeLock=nil; return current end
					return nil
				end,Config.PartyTTL) end)
			end
		end
	end
end

-- Freeze the validated roster until the durable generation accepts or rejects it.
-- Heartbeats may advance Revision; only membership/session changes invalidate it.
function PartyService:LockResume(partyId, worldRecord, expectedMembers, requesterId)
	local roster,rosterSize=rosterSet(type(worldRecord)=="table" and worldRecord.Roster)
	if type(partyId)~="string" or type(worldRecord)~="table" or worldRecord.CrewCommitted~=true
		or type(worldRecord.Id)~="string" or type(worldRecord.MatchId)~="string" or type(worldRecord.Generation)~="number"
		or not roster or type(expectedMembers)~="table" or count(expectedMembers)~=rosterSize then return nil,"InvalidResumeCrew" end
	if not roster[key(requesterId)] then return nil,"OriginalCrewRequired" end
	local read,previous=call(function() return parties:GetAsync(partyId) end)
	if not read then return nil,"Party service is temporarily unavailable." end
	if previous and previous.ResumeCommit and (previous.ResumeCommit.Until or 0)<=os.time() then
		local released,reason=self:ReleaseResume(partyId,previous.RunId,previous.ResumeCommit.Token)
		if not released then return nil,reason end
		-- The release may have discovered a committed successor generation.
		return nil,"Resume lock recovered. Refresh the saved world and retry."
	end
	local token,reason=guid(),nil
	local ok,locked=call(function() return parties:UpdateAsync(partyId,function(current)
		reason=nil
		if not current or current.Closed or current.MergedInto then reason="That party has ended."; return nil end
		if current.RecoveryPending or recoveryBusy(current) or current.Queue or (current.RunId and current.RunId~=worldRecord.Id) then reason="CrewCommittedElsewhere"; return nil end
		local commit=current.ResumeCommit
		if current.MergeLock and not (commit and sameLock(current.MergeLock,worldRecord.Id,worldRecord.MatchId)) then reason="CrewCommitPending"; return nil end
		if commit and (not sameLock(current.MergeLock,worldRecord.Id,worldRecord.MatchId)
			or commit.Generation~=worldRecord.Generation or (commit.Until or 0)<=os.time()) then reason="ResumeDecisionPending"; return nil end
		if type(current.Members)~="table" or count(current.Members)~=rosterSize then reason="CrewChanged"; return nil end
		for id,member in pairs(current.Members) do
			local expected=expectedMembers[id]
			if not roster[id] or member.UserId~=tonumber(id) or type(expected)~="table" or expected.UserId~=member.UserId
				or type(expected.Session)~="string" or member.Session~=expected.Session or member.SessionAt~=expected.SessionAt
				or not member.Ready or (member.OnlineUntil or 0)<=os.time() then reason="CrewChanged"; return nil end
		end
		current.MergeLock={WorldId=worldRecord.Id,MatchId=worldRecord.MatchId}
		current.ResumeCommit=commit or {Token=token,Generation=worldRecord.Generation,Until=os.time()+180}
		current.RunId=worldRecord.Id
		current.Revision=(current.Revision or 0)+1
		return current
	end,Config.PartyTTL) end)
	if not ok then return nil,"Party service is temporarily unavailable." end
	if reason then return nil,reason end
	if not locked then return nil,"ResumeDecisionPending" end
	return locked
end

function PartyService:ReleaseResume(partyId, worldId, token)
	if type(partyId)~="string" or type(worldId)~="string" or type(token)~="string" then return nil,"InvalidResumeLock" end
	local read,party=call(function() return parties:GetAsync(partyId) end)
	if not read then return nil,"Party service is temporarily unavailable." end
	if not party or not party.ResumeCommit then return true end
	local commit=party.ResumeCommit
	if commit.Token~=token or not party.MergeLock or party.MergeLock.WorldId~=worldId then return nil,"ResumeLockChanged" end
	local Store=require(script.Parent.WorldStateStore)
	local world,reason=Store:Get(worldId)
	if not world then return nil,reason or "ResumeDecisionPending" end
	local function adopted(current)
		return current.PartyId==partyId and current.ResumeToken==token and current.Generation>commit.Generation
	end
	if not adopted(world) then
		local definitive=world.Generation~=commit.Generation or world.Ended or world.Phase=="Ended" or world.Phase=="Aborted"
		if not definitive and (commit.Until or 0)>os.time() then return nil,"ResumeDecisionPending" end
		-- A read alone cannot exclude an in-flight durable adoption. The caller's
		-- adoption callback checks this tombstone as well as the lock deadline.
		world,reason=Store:Mutate(worldId,function(current)
			if not current then return nil,"ResumeDecisionPending" end
			if adopted(current) then return current end
			local rejected=current.Generation~=commit.Generation or current.Ended or current.Phase=="Ended" or current.Phase=="Aborted"
			if not rejected and (commit.Until or 0)>os.time() then return nil,"ResumeDecisionPending" end
			current.ResumeRejectedToken=token
			return current
		end)
		if not world then return nil,reason or "ResumeDecisionPending" end
	end
	local keepRun=adopted(world) or (world.PartyId==partyId and world.Generation>commit.Generation)
	local released=false
	local ok=call(function() return parties:UpdateAsync(partyId,function(current)
		released=false
		if not current or not current.ResumeCommit then released=true; return nil end
		if current.ResumeCommit.Token~=token or not sameLock(current.MergeLock,worldId,party.MergeLock.MatchId) then return nil end
		current.ResumeCommit=nil; current.MergeLock=nil
		if not keepRun and current.RunId==worldId then current.RunId=nil end
		current.Revision=(current.Revision or 0)+1
		released=true
		return current
	end,Config.PartyTTL) end)
	if not ok then return nil,"Party service is temporarily unavailable." end
	if not released then return nil,"ResumeLockChanged" end
	return true
end

function PartyService:Snapshot(player)
	local party,err=self:GetParty(player)
	local snapshot={Available=err==nil,Message=err,MaxMembers=Config.MaxPartySize,Members={},Invites={},QueueStartedAt=false}
	if party then
		player:SetAttribute("PartyId",party.Id)
		snapshot.Id,snapshot.LeaderId,snapshot.RunId,snapshot.Revision=party.Id,party.LeaderId,party.RunId,party.Revision
		snapshot.ManagementLocked=(party.MergeLock~=nil or party.ResumeCommit~=nil or party.RecoveryPending==true)
		snapshot.MergedCrew=party.LaunchMode=="LobbyMerge"
		if party.Queue then
			snapshot.Queue={State=party.Queue.State,QueuedAt=party.Queue.QueuedAt,Mode=party.Queue.Mode,Purpose=party.Queue.Purpose}
			snapshot.QueueStartedAt=party.Queue.QueuedAt
		end
		for _,member in pairs(party.Members) do
			local item=table.clone(member)
			item.Session=nil; item.SessionAt=nil; item.OnlineUntil=nil
			local p=self:GetPresence(member.UserId)
			item.Online=online(p)==true; item.Location=item.Online and p.Mode or "Offline"
			local localMember=Players:GetPlayerByUserId(member.UserId)
			if localMember and Config.GetMode()=="Lobby" and not party.RunId then
				local currentRole=localMember:GetAttribute("Role")
				if type(currentRole)=="string" then
					-- Profile selection is already confirmed locally; the shared party
					-- update may still be yielding. A changed class requires readiness.
					if item.Role~=currentRole then item.Ready=false end
					item.Role=currentRole
				end
			end
			table.insert(snapshot.Members,item)
		end
		table.sort(snapshot.Members,function(a,b) if a.JoinedAt==b.JoinedAt then return a.UserId<b.UserId end; return a.JoinedAt<b.JoinedAt end)
	elseif not err then player:SetAttribute("PartyId",nil) end
	snapshot.Invites,snapshot.InvitesAvailable=self:GetInvites(player)
	return snapshot
end

function PartyService:GetMergeStatus(worldId)
	local ok,record=call(function() return merges:GetAsync(worldId) end)
	if not ok then return nil,"Crew commit storage is temporarily unavailable." end
	return record and record.State or nil,nil,record
end

function PartyService:ClaimMerge(worldId,matchId,leaseToken)
	local ok,record=call(function() return merges:UpdateAsync(worldId,function(old)
		if old and old.MatchId~=matchId then return nil end
		if old and old.LeaseToken~=leaseToken and (old.LeaseUntil or 0)>os.time() then return nil end
		old=old or {WorldId=worldId,MatchId=matchId,State="Preparing",CreatedAt=os.time()}
		old.LeaseToken,old.LeaseUntil=leaseToken,os.time()+90; return old
	end,Config.PartyTTL) end)
	return ok and record and record.LeaseToken==leaseToken or false
end

function PartyService:ReleaseMergeLease(worldId,matchId,leaseToken)
	call(function() return merges:UpdateAsync(worldId,function(old)
		if not old or old.MatchId~=matchId or old.LeaseToken~=leaseToken then return nil end
		old.LeaseUntil=0; return old
	end,Config.PartyTTL) end)
end

-- Abort is an atomic alternative to commit. A missing intent gets a tombstone so
-- a delayed preparation cannot recreate a transaction after cancellation.
function PartyService:AbortMerge(worldId,matchId,leaseToken)
	local ok,record=call(function() return merges:UpdateAsync(worldId,function(old)
		if old and old.MatchId~=matchId then return nil end
		if leaseToken and (not old or old.LeaseToken~=leaseToken or (old.LeaseUntil or 0)<=os.time()) then return nil end
		if old and (old.State=="Committed" or old.State=="Complete") then return old end
		old=old or {WorldId=worldId,MatchId=matchId,CreatedAt=os.time()}
		old.State="Aborted"; return old
	end,Config.PartyTTL) end)
	if not ok or not record then return nil,"Crew cancellation is retrying." end
	if record.State=="Aborted" then return true end
	return false,"Your expedition is already starting."
end

function PartyService:CancelQueue(partyId,token,matchId)
	local ok,observed=call(function() return parties:GetAsync(partyId) end)
	if not ok then return nil,"Queue cancellation is retrying." end
	if not observed or not observed.Queue or observed.Queue.Token~=token or (matchId and observed.Queue.MatchId~=matchId) then return true end
	local lock=observed.MergeLock
	if lock then
		local aborted,reason=self:AbortMerge(lock.WorldId,lock.MatchId)
		if aborted~=true then return aborted,reason end
	end
	local changed,reason=self:Mutate(partyId,function(current)
		if not current.Queue or current.Queue.Token~=token or (matchId and current.Queue.MatchId~=matchId) then return true end
		current.Queue=nil; current.MergeLock=nil; return true
	end,lock)
	if not changed then return nil,reason end
	if lock then
		for userId in pairs(observed.Members) do
			local written=call(function() return membership:UpdateAsync(userId,function(link)
				if link and sameLock(link.MergeLock,lock.WorldId,lock.MatchId) then link.MergeLock=nil; return link end
				return nil
			end,Config.PartyTTL) end)
			if not written then return nil,"Membership cancellation is retrying." end
		end
	end
	return true
end

function PartyService:AbortMatch(sources,matchId,worldId,leaseToken)
	local aborted,reason=self:AbortMerge(worldId,matchId,leaseToken)
	if aborted~=true then return aborted,reason end
	for _,source in ipairs(sources) do
		local released,err=self:CancelQueue(source.Id,source.Token,matchId)
		if released~=true then return released,err end
	end
	local state,err,intent=self:GetMergeStatus(worldId)
	if err or state~="Aborted" then return nil,err or "Cancellation status changed." end
	for userId in pairs(intent.Members or {}) do
		local ok=call(function() return membership:UpdateAsync(userId,function(link)
			if link and sameLock(link.MergeLock,worldId,matchId) then link.MergeLock=nil; return link end
			return nil
		end,Config.PartyTTL) end)
		if not ok then return nil,"Membership cancellation is retrying." end
	end
	return true
end

-- Third return: true means committed/recovery, false means confirmed safe abort,
-- nil means storage uncertainty. No caller may release claims on nil.
function PartyService:MergeForExpedition(sourceIds,matchId,worldId,leaseToken,launchMode)
	local mode=launchKind(launchMode)
	if not mode or type(sourceIds)~="table" or type(matchId)~="string" or type(worldId)~="string" then return nil,"Invalid expedition launch request.",nil end
	local sourceSet,sourceCount={},count(sourceIds)
	if sourceCount<1 or sourceCount>Config.MaxPartySize or (mode=="Party" and sourceCount~=1) then return nil,"A party launch requires exactly one source crew.",nil end
	for index,id in pairs(sourceIds) do
		if type(index)~="number" or index%1~=0 or index<1 or index>sourceCount or type(id)~="string" or id=="" or sourceSet[id] then return nil,"Invalid source crews.",nil end
		sourceSet[id]=true
	end
	local mergedId=(mode=="LobbyMerge" and "merge:" or "world:")..worldId
	local state,err,intent=self:GetMergeStatus(worldId)
	if err then return nil,err,nil end
	local function abort(reason)
		local cancelled,message=self:AbortMerge(worldId,matchId,leaseToken)
		if cancelled==true then return nil,reason,false end
		if cancelled==false then return nil,message,true end
		return nil,message or reason,nil
	end
	if intent and intent.MatchId~=matchId then return nil,"World commit ownership changed.",nil end
	if intent and (intent.LaunchMode~=nil or intent.Sources) and launchKind(intent.LaunchMode)~=mode then
		return nil,"World launch mode changed.",(state=="Committed" or state=="Complete") and true or nil
	end
	if state=="Aborted" then return nil,"Matchmaking was cancelled before commit.",false end
	if not intent or not intent.Sources then
		local members,sources,leaders,leader,created,nativeType={},{},{},nil,math.huge,nil
		for _,id in ipairs(sourceIds) do
			local ok,record=call(function() return parties:GetAsync(id) end)
			if not ok then return nil,"A source party is unavailable.",nil end
			if record and record.MergedInto then return nil,"A previous crew commit needs recovery.",true end
			if not record or record.Closed or not record.Queue or record.Queue.MatchId~=matchId then return abort("A source party is no longer claimed.") end
			if queueKind(record.Queue)~=mode then return abort("A source crew's launch mode changed.") end
			if mode=="LobbyMerge" then
				local sourceType=record.Queue.MatchmakingType
				if not MatchmakingPolicy.IsMatchmakingType(sourceType) or (nativeType and nativeType~=sourceType) then return abort("Crew members have incompatible cross-play settings.") end
				nativeType=sourceType
			end
			if not memberRoster(record.Members) then return abort("A source crew has an invalid roster.") end
			if not record.Members[key(record.LeaderId)] then return abort("A source crew's leader changed.") end
			table.insert(leaders,record.LeaderId)
			table.insert(sources,{Id=id,Token=record.Queue.Token,LeaderId=record.LeaderId})
			for userId,member in pairs(record.Members) do
				if members[userId] then return abort("A player appears in more than one party.") end
				members[userId]=table.clone(member); members[userId].Ready=false; members[userId].SourcePartyId=id
			end
			if record.CreatedAt<created then created=record.CreatedAt; leader=record.LeaderId end
		end
		if mode=="LobbyMerge" then leader=leaders[math.random(1,#leaders)] end
		local roster=memberRoster(members)
		if not roster or (mode~="Party" and #roster~=Config.MaxPartySize) then return abort("Matchmaking requires six distinct members; party launches allow one to six.") end
		local ok,saved=call(function() return merges:UpdateAsync(worldId,function(old)
			if old and (old.MatchId~=matchId or (old.LaunchMode~=nil and launchKind(old.LaunchMode)~=mode)) then return nil end
			if old and (old.State~="Preparing" or old.Sources) then return old end
			if leaseToken and (not old or old.LeaseToken~=leaseToken or (old.LeaseUntil or 0)<=os.time()) then return nil end
			old=old or {WorldId=worldId,MatchId=matchId,State="Preparing",CreatedAt=os.time()}
			old.PartyId,old.Sources,old.Members,old.LeaderId=mergedId,sources,members,leader
			old.LaunchMode,old.Roster,old.SourceLeaders=mode,roster,leaders
			if mode=="LobbyMerge" then old.MatchmakingType=nativeType end
			return old
		end,Config.PartyTTL) end)
		if not ok or not saved then return nil,"Crew preparation is retrying.",nil end
		intent=saved
	end
	if intent.State=="Aborted" then return nil,"The expedition was cancelled before commit.",false end
	-- Replays use the persisted original sources and roster. They cannot convert
	-- a queued six-player match into a smaller direct launch (or vice versa).
	local roster,rosterIds,rosterSize=memberRoster(intent.Members)
	local sourcesValid=type(intent.Sources)=="table" and #intent.Sources==sourceCount and count(intent.Sources)==sourceCount
	local sourceMembers,seenSources={},{}
	if sourcesValid then
		for _,source in ipairs(intent.Sources) do
			if type(source)~="table" or not sourceSet[source.Id] or seenSources[source.Id] or type(source.Token)~="string" then sourcesValid=false; break end
			seenSources[source.Id]=true; sourceMembers[source.Id]=0
		end
	end
	if roster and sourcesValid then
		for _,member in pairs(intent.Members) do
			if not seenSources[member.SourcePartyId] then sourcesValid=false; break end
			sourceMembers[member.SourcePartyId]+=1
		end
	end
	local savedRoster,savedSize=rosterSet(intent.Roster or roster)
	if savedRoster and roster then for id in pairs(rosterIds) do if not savedRoster[id] then savedRoster=nil; break end end end
	if launchKind(intent.LaunchMode)~=mode or intent.PartyId~=mergedId or not sourcesValid or not roster
		or not savedRoster or savedSize~=rosterSize or not rosterIds[key(intent.LeaderId)]
		or (mode~="Party" and rosterSize~=Config.MaxPartySize) then
		return nil,"The original crew commit does not match this launch request.",(intent.State=="Committed" or intent.State=="Complete") and true or nil
	end
	if mode=="LobbyMerge" then
		if not MatchmakingPolicy.IsMatchmakingType(intent.MatchmakingType) then return abort("Crew platform matchmaking is not ready.") end
		local originalLeader=false
		for _,source in ipairs(intent.Sources) do
			if source.LeaderId==intent.LeaderId and intent.Members[key(source.LeaderId)] and intent.Members[key(source.LeaderId)].SourcePartyId==source.Id then originalLeader=true end
		end
		if not originalLeader then return nil,"The original crew leaders changed.",(intent.State=="Committed" or intent.State=="Complete") and true or nil end
	end
	local lock={WorldId=worldId,MatchId=matchId}
	local function unlockLobbyMerge()
		for userId in pairs(intent.Members) do
			local saved=call(function() return membership:UpdateAsync(userId,function(link)
				if link and link.PartyId==mergedId and sameLock(link.MergeLock,worldId,matchId) then link.MergeLock=nil; return link end
				return nil
			end,Config.PartyTTL) end)
			if not saved then return nil,"Crew unlock is retrying.",true end
		end
		local saved,current=call(function() return parties:UpdateAsync(mergedId,function(party)
			-- Completed replays cannot recreate a dissolved party, reset readiness,
			-- or unlock a newer match the crew has entered since this merge.
			if party and sameLock(party.MergeLock,worldId,matchId) then
				party.MergeLock=nil; party.Revision=(party.Revision or 0)+1
			end
			return party
		end,Config.PartyTTL) end)
		if not saved then return nil,"Crew unlock is retrying.",true end
		return current or {Id=mergedId,Completed=true},nil,true
	end
	if mode=="LobbyMerge" and intent.State=="Complete" then return unlockLobbyMerge() end
	if intent.State=="Preparing" then
		for _,source in ipairs(intent.Sources) do
			local locked,reason=self:Mutate(source.Id,function(current)
				if leaseToken and (intent.LeaseToken~=leaseToken or (intent.LeaseUntil or 0)<=os.time()) then return false,"The crew commit lease expired." end
				if not current.Queue or current.Queue.Token~=source.Token or current.Queue.MatchId~=matchId or queueKind(current.Queue)~=mode then return false,"A source crew cancelled or changed launch mode." end
				if mode=="LobbyMerge" and current.Queue.MatchmakingType~=intent.MatchmakingType then return false,"A source crew's cross-play settings changed." end
				if type(current.Members)~="table" or count(current.Members)~=sourceMembers[source.Id] then return false,"A source crew's roster changed." end
				if source.LeaderId and current.LeaderId~=source.LeaderId then return false,"A source crew's leader changed." end
				for userId,member in pairs(current.Members) do
					local original=intent.Members[userId]
					if type(member)~="table" or not original or original.SourcePartyId~=source.Id or member.UserId~=original.UserId
						or member.Session~=original.Session or member.SessionAt~=original.SessionAt or member.Role~=original.Role
						or not member.Ready or (member.OnlineUntil or 0)<=os.time() then return false,"A crew member changed or disconnected." end
				end
				current.MergeLock=lock; current.Queue.State="Committing"; return true
			end,lock)
			if not locked then
				if reason=="Party service is temporarily unavailable." then return nil,reason,nil end
				return abort(reason or "Crew locking is retrying.")
			end
		end
		for userId,member in pairs(intent.Members) do
			local p,available=self:GetPresence(member.UserId)
			if not available then return nil,"Connection status is temporarily unavailable.",nil end
			if not p or not p.Online or p.ExpiresAt<=os.time() or p.Mode~="Lobby" or p.Session~=member.Session or p.SessionAt~=member.SessionAt then return abort("A crew member changed connection before commit.") end
			if mode=="LobbyMerge" and p.MatchmakingType~=intent.MatchmakingType then return abort("A crew member's cross-play settings changed before commit.") end
			local ok,link=call(function() return membership:UpdateAsync(userId,function(old)
				if leaseToken and (intent.LeaseToken~=leaseToken or (intent.LeaseUntil or 0)<=os.time()) then return nil end
				if not old or old.PartyId~=member.SourcePartyId or old.Session~=p.Session or (old.MergeLock and not sameLock(old.MergeLock,worldId,matchId)) then return nil end
				old.MergeLock=lock; return old
			end,Config.PartyTTL) end)
			if not ok then return nil,"Crew membership locking is retrying.",nil end
			if not link or not sameLock(link.MergeLock,worldId,matchId) then return abort("A member's party changed before commit.") end
		end
	end
	-- All source/member claims are fenced before this single irreversible write.
	local ok,committed=call(function() return merges:UpdateAsync(worldId,function(current)
		if not current or current.MatchId~=matchId then return nil end
		if launchKind(current.LaunchMode)~=mode then return nil end
		if leaseToken and (current.LeaseToken~=leaseToken or (current.LeaseUntil or 0)<=os.time()) then return nil end
		current.LaunchMode,current.Roster=mode,current.Roster or roster
		if current.State=="Preparing" then current.State="Committed" end
		return current
	end,Config.PartyTTL) end)
	if not ok or not committed then return nil,"Crew commit status is retrying.",nil end
	if committed.State=="Aborted" then return nil,"Matchmaking was cancelled before commit.",false end
	intent=committed
	local written,merged=call(function() return parties:UpdateAsync(mergedId,function(old)
		if old then return old.MatchId==matchId and launchKind(old.LaunchMode)==mode and old or nil end
		return {Id=mergedId,LeaderId=intent.LeaderId,Members=intent.Members,CreatedAt=intent.CreatedAt,Revision=1,RunId=mode~="LobbyMerge" and worldId or nil,MatchId=matchId,MergeLock=lock,LaunchMode=mode}
	end,Config.PartyTTL) end)
	if not written or not merged then return nil,"Committed crew creation is retrying.",true end
	if intent.State~="Complete" then
		for _,source in ipairs(intent.Sources) do
			local saved,result=call(function() return parties:UpdateAsync(source.Id,function(old)
				if old and old.MergedInto==mergedId then return old end
				if not old or not sameLock(old.MergeLock,worldId,matchId) then return nil end
				old.MergedInto=mergedId; old.Closed=true; old.Queue=nil; old.Revision=(old.Revision or 0)+1; return old
			end,Config.PartyTTL) end)
			if not saved or not result or result.MergedInto~=mergedId then return nil,"Committed source redirects are retrying.",true end
		end
		for userId in pairs(intent.Members) do
			local saved,result=call(function() return membership:UpdateAsync(userId,function(link)
				if not link or not sameLock(link.MergeLock,worldId,matchId) then return nil end
				link.PartyId=mergedId; link.ClaimUntil=nil; return link
			end,Config.PartyTTL) end)
			if not saved or not result or result.PartyId~=mergedId then return nil,"Committed member redirects are retrying.",true end
		end
		local saved,result=call(function() return merges:UpdateAsync(worldId,function(current)
			if not current or current.MatchId~=matchId or current.State=="Aborted" or launchKind(current.LaunchMode)~=mode then return nil end
			current.State="Complete"; return current
		end,Config.PartyTTL) end)
		if not saved or not result or result.State~="Complete" then return nil,"Crew completion is retrying.",true end
	end
	if mode=="LobbyMerge" then return unlockLobbyMerge() end
	for userId in pairs(intent.Members) do
		local saved=call(function() return membership:UpdateAsync(userId,function(link)
			if link and link.PartyId==mergedId and sameLock(link.MergeLock,worldId,matchId) then link.MergeLock=nil; return link end
			return nil
		end,Config.PartyTTL) end)
		if not saved then return nil,"Crew unlock is retrying.",true end
	end
	merged=self:Mutate(mergedId,function(current) current.MergeLock=nil; return true end,lock)
	if not merged then return nil,"Crew unlock is retrying.",true end
	return merged,nil,true
end

function PartyService:FinishExpedition(partyId, worldId)
	return self:Mutate(partyId,function(party)
		if party.RunId~=worldId then return false,"A different expedition is assigned." end
		party.RunId=nil; party.MatchId=nil; party.Queue=nil
		for _,member in pairs(party.Members) do member.Ready=false end
		return true
	end)
end

-- Rebuild expiring party indexes from confirmed durable authority. This does not
-- authorize teleports: an active-run rejoin uses the world's roster directly.
function PartyService:RestoreExpeditionParty(worldRecord)
	if type(worldRecord)~="table" or worldRecord.CrewCommitted~=true then return nil,"CrewCommitUnconfirmed" end
	local world,readError=require(script.Parent.WorldStateStore):Get(worldRecord.Id)
	if not world then return nil,readError end
	if world.CrewCommitted~=true or world.Generation~=worldRecord.Generation or world.PartyId~=worldRecord.PartyId then return nil,"WorldCrewChanged" end
	if world.Phase~="CrewCommitted" and world.Phase~="Reserving" and world.Phase~="Launching" and world.Phase~="Active" then
		return nil,"Reform the original crew before resuming."
	end
	local roster,rosterSize=rosterSet(world.Roster)
	local mode=launchKind(world.LaunchMode)
	if type(world.PartyId)~="string" or #world.PartyId<1 or #world.PartyId>128 or type(world.MatchId)~="string"
		or not mode or mode=="LobbyMerge" or not roster or type(world.Members)~="table" or count(world.Members)~=rosterSize then return nil,"InvalidDurableCrew" end
	local members,sources={},{}
	for _,userId in ipairs(world.Roster) do
		local member=world.Members[key(userId)]
		if type(member)~="table" or member.UserId~=userId or type(member.Name)~="string" or type(member.DisplayName)~="string"
			or type(member.Role)~="string" or type(member.JoinedAt)~="number" then return nil,"InvalidDurableCrew" end
		members[key(userId)]={UserId=userId,Name=member.Name,DisplayName=member.DisplayName,Role=member.Role,JoinedAt=member.JoinedAt,Ready=false,OnlineUntil=0}
	end
	if not roster[key(world.LeaderId)] then return nil,"InvalidDurableCrew" end
	for _,source in ipairs(world.Sources or {}) do
		if type(source)~="table" or type(source.Id)~="string" or type(source.Token)~="string" then return nil,"InvalidDurableCrew" end
		sources[source.Id]=source.Token
	end
	local function exactRoster(party)
		if type(party.Members)~="table" or count(party.Members)~=rosterSize then return false end
		for id,member in pairs(party.Members) do if not roster[id] or type(member)~="table" or member.UserId~=tonumber(id) then return false end end
		return true
	end
	local targetId=world.PartyId
	local available,existing=call(function() return parties:GetAsync(targetId) end)
	if not available then return nil,"CrewRecoveryPending" end
	if existing and existing.ResumeCommit then
		local released,reason=self:ReleaseResume(targetId,world.Id,existing.ResumeCommit.Token)
		if not released then return nil,reason end
		available,existing=call(function() return parties:GetAsync(targetId) end)
		if not available then return nil,"CrewRecoveryPending" end
	end
	if existing and (existing.MergedInto or existing.Queue or (existing.RunId and existing.RunId~=world.Id) or not exactRoster(existing)) then return nil,"CrewPartyConflict" end
	if existing and existing.MergeLock and not sameLock(existing.MergeLock,world.Id,world.MatchId) then return nil,"CrewCommitUnconfirmed" end
	if existing and recoveryBusy(existing) then return nil,"CrewRecoveryPending" end
	local observed,allAtTarget={},true
	for userId in pairs(roster) do
		local ok,link=call(function() return membership:GetAsync(userId) end)
		if not ok then return nil,"CrewRecoveryPending" end
		if link and link.MergeLock and not sameLock(link.MergeLock,world.Id,world.MatchId) then return nil,"CrewCommitUnconfirmed" end
		local completedLock=existing and not existing.RecoveryPending and link and link.RecoveryLock
			and link.PartyId==targetId and link.RecoveryLock.Token==existing.RecoveryCompleteToken
		if recoveryBusy(link) and not completedLock then return nil,"CrewRecoveryPending" end
		if link and link.PartyId and link.PartyId~=targetId then
			local other,err=self:GetPartyById(link.PartyId)
			if err then return nil,err end
			if other and other.Id~=targetId and other.Members[userId] then
				-- An original source still locked to this exact committed match is
				-- recoverable; a new queue or any unrelated live party is not.
				if not sources[other.Id] or not other.Queue or other.Queue.Token~=sources[other.Id] or other.Queue.MatchId~=world.MatchId or queueKind(other.Queue)~=mode then return nil,"CrewPartyConflict" end
				for id in pairs(other.Members) do if not roster[id] then return nil,"CrewPartyConflict" end end
			end
		end
		if link and (link.ClaimUntil or 0)>os.time() and link.PartyId~=targetId then return nil,"CrewRecoveryPending" end
		observed[userId]=link or false
		if not link or link.PartyId~=targetId then allAtTarget=false end
		local p,presenceOK=self:GetPresence(tonumber(userId))
		if not presenceOK then return nil,"CrewRecoveryPending" end
		if p then
			members[userId].Session,members[userId].SessionAt=p.Session,p.SessionAt
			members[userId].OnlineUntil=online(p) and p.ExpiresAt or 0
		end
	end
	local function clearCompletedLocks(party)
		for userId in pairs(roster) do
			local ok=call(function() return membership:UpdateAsync(userId,function(link)
				if link and link.PartyId==targetId and link.RecoveryLock and link.RecoveryLock.Token==party.RecoveryCompleteToken then
					link.RecoveryLock=nil; return link
				end
				return nil
			end,Config.PartyTTL) end)
			if not ok then return false end
		end
		return true
	end
	if existing and not existing.Closed and not existing.RecoveryPending and allAtTarget and existing.RunId==world.Id
		and not existing.MergeLock and existing.RecoveredGeneration==world.Generation then
		if not clearCompletedLocks(existing) then return nil,"CrewRecoveryPending" end
		return existing
	end
	if existing and not existing.RecoveryPending and existing.RecoveryCompleteToken then
		if not clearCompletedLocks(existing) then return nil,"CrewRecoveryPending" end
	end
	local token,deadline=guid(),os.time()+90
	local recovery={Token=token,WorldId=world.Id,Generation=world.Generation,Until=deadline}
	local function owns(link) return link and link.RecoveryLock and link.RecoveryLock.Token==token end
	local function rollback()
		-- Restore only this attempt's claims; preserve newer connection fences.
		for userId,prior in pairs(observed) do call(function() return membership:UpdateAsync(userId,function(link)
			if not owns(link) then return nil end
			link.PartyId,link.Token=prior and prior.PartyId or nil,prior and prior.Token or nil
			link.MergeLock,link.ClaimUntil=prior and prior.MergeLock or nil,prior and prior.ClaimUntil or nil
			link.RecoveryLock=nil; return link
		end,Config.PartyTTL) end) end
		call(function() return parties:UpdateAsync(targetId,function(party)
			if not owns(party) then return nil end
			party.RecoveryLock,party.RecoveryPending=nil,nil
			if not existing then party.Closed=true end
			return party
		end,Config.PartyTTL) end)
	end
	for userId,prior in pairs(observed) do
		local ok,claimed=call(function() return membership:UpdateAsync(userId,function(link)
			if os.time()>=deadline or (link and link.PartyId)~=(prior and prior.PartyId or nil) or (link and link.Token)~=(prior and prior.Token or nil) then return nil end
			if recoveryBusy(link) or (link and link.MergeLock and not sameLock(link.MergeLock,world.Id,world.MatchId)) then return nil end
			link=link or {}; link.RecoveryLock=recovery; return link
		end,Config.PartyTTL) end)
		if not ok or not owns(claimed) then rollback(); return nil,"CrewRecoveryPending" end
	end
	local prepared,target=call(function() return parties:UpdateAsync(targetId,function(party)
		if os.time()>=deadline then return nil end
		if party and (recoveryBusy(party) or party.MergedInto or party.Queue or (party.RunId and party.RunId~=world.Id) or not exactRoster(party)) then return nil end
		if party and party.MergeLock and not sameLock(party.MergeLock,world.Id,world.MatchId) then return nil end
		party=party or {Id=targetId,LeaderId=world.LeaderId,Members=members,CreatedAt=os.time(),Revision=1}
		party.RecoveryLock,party.RecoveryPending=recovery,true; return party
	end,Config.PartyTTL) end)
	if not prepared or not owns(target) then rollback(); return nil,"CrewRecoveryPending" end
	for userId in pairs(roster) do
		local ok,linked=call(function() return membership:UpdateAsync(userId,function(link)
			if os.time()>=deadline or not owns(link) then return nil end
			link.PartyId,link.Token,link.MergeLock,link.ClaimUntil=targetId,token,nil,nil; return link
		end,Config.PartyTTL) end)
		if not ok or not linked or linked.PartyId~=targetId or not owns(linked) then rollback(); return nil,"CrewRecoveryPending" end
	end
	-- Recheck durable generation before making the reconstructed indexes visible.
	local latest=require(script.Parent.WorldStateStore):Get(world.Id)
	if not latest then return nil,"CrewRecoveryPending" end
	if latest.CrewCommitted~=true or latest.Generation~=world.Generation or latest.PartyId~=targetId or latest.Phase~=world.Phase then rollback(); return nil,"WorldCrewChanged" end
	local latestRoster,latestSize=rosterSet(latest.Roster)
	if not latestRoster or latestSize~=rosterSize then rollback(); return nil,"WorldCrewChanged" end
	for id in pairs(roster) do if not latestRoster[id] then rollback(); return nil,"WorldCrewChanged" end end
	local saved,restored=call(function() return parties:UpdateAsync(targetId,function(party)
		if os.time()>=deadline or not owns(party) then return nil end
		party.Members,party.LeaderId=members,world.LeaderId
		party.RunId,party.MatchId=world.Id,world.MatchId
		party.LaunchMode=mode
		party.MergeLock,party.Closed,party.RecoveryPending,party.RecoveryLock=nil,nil,nil,nil
		party.RecoveryCompleteToken,party.RecoveredGeneration=token,world.Generation
		party.Revision=(party.Revision or 0)+1; return party
	end,Config.PartyTTL) end)
	-- A failed publish may have committed. Preserve claims for an idempotent retry.
	if not saved or not restored or restored.RecoveryCompleteToken~=token then return nil,"CrewRecoveryPending" end
	if not clearCompletedLocks(restored) then return nil,"CrewRecoveryPending" end
	for sourceId,sourceToken in pairs(sources) do
		if sourceId~=targetId then call(function() return parties:UpdateAsync(sourceId,function(source)
			if not source or not source.Queue or source.Queue.Token~=sourceToken or source.Queue.MatchId~=world.MatchId or queueKind(source.Queue)~=mode then return nil end
			for userId in pairs(source.Members) do if not roster[userId] then return nil end end
			source.MergedInto,source.Closed,source.Queue,source.MergeLock=targetId,true,nil,nil; return source
		end,Config.PartyTTL) end) end
	end
	return restored
end

function PartyService:Init()
	if self._started then return end
	self._started=true
	local function added(player,session)
		local registered,owned=call(function() return presence:UpdateAsync(key(player.UserId),function(old)
			if self._sessions[player]~=session or session.Leaving or player.Parent~=Players then return nil end
			if old and not sessionWins(session,old.SessionAt,old.Session) then return nil end
			return {Session=session.Id,SessionAt=session.StartedAt,Online=true,Mode=Config.GetMode(),MatchmakingType=game.MatchmakingType.Name,JobId=game.JobId,PlaceId=game.PlaceId,ExpiresAt=os.time()+Config.PresenceTTL}
		end,Config.PresenceTTL) end)
		if not registered or not owned or owned.Session~=session.Id then return end
		local ok,link=call(function() return membership:UpdateAsync(key(player.UserId),function(old)
			if self._sessions[player]~=session or session.Leaving or player.Parent~=Players then return nil end
			if old and not sessionWins(session,old.SessionAt,old.Session) then return nil end
			old=old or {}; old.Session,old.SessionAt=session.Id,session.StartedAt; return old
		end,Config.PartyTTL) end)
		if not ok or not link or link.Session~=session.Id then return end
		session.Established=true
		if ok and link and link.PartyId then
			local party,err=self:GetPartyById(link.PartyId)
			if session.Leaving or player.Parent~=Players or self._sessions[player]~=session then self:Heartbeat(player,true); return end
			if party and party.Members[key(player.UserId)] then
				self:Mutate(party.Id,function(current)
					local member=current.Members[key(player.UserId)]
					if not member then return false,"Membership changed." end
					if not sessionWins(session,member.SessionAt,member.Session) then return false,"Connection changed." end
					member.Session,member.SessionAt=session.Id,session.StartedAt; member.OnlineUntil=os.time()+Config.PresenceTTL
					return true
				end,party.MergeLock)
				player:SetAttribute("PartyId",party.Id)
			elseif not err and not link.MergeLock and (link.ClaimUntil or 0)<=os.time() then self:_release(player,link.PartyId,link.Token) end
		end
		self:Heartbeat(player)
		if session.RoleBound then return end
		session.RoleBound=true
		player:GetAttributeChangedSignal("Role"):Connect(function()
			local party=self:GetParty(player)
			local role=player:GetAttribute("Role") or "Generalist"
			local member=party and party.Members[key(player.UserId)]
			if party and member and member.Role~=role and not party.RunId then
				if party.Queue then self:CancelQueue(party.Id,party.Queue.Token) end
				self:Mutate(party.Id,function(current)
				local member=current.Members[key(player.UserId)]
				if member and member.Session==session.Id and member.Role~=role and player:GetAttribute("Role")==role then member.Role=role; member.Ready=false end
				return true
				end)
			end
		end)
	end
	local function startPlayer(player)
		if self._sessions[player] then return end
		-- Capture arrival before spawning any yielding work; late tasks retain an old fence.
		local session={Id=guid(),StartedAt=DateTime.now().UnixTimestampMillis}
		self._sessions[player]=session; task.spawn(added,player,session)
	end
	Players.PlayerAdded:Connect(startPlayer)
	Players.PlayerRemoving:Connect(function(player)
		self._lastRequest[player]=nil
		if self._sessions[player] then self._sessions[player].Leaving=true end
		self:Heartbeat(player,true)
		local party=self:GetParty(player)
		if party then self:RefreshParty(party) end
		self._sessions[player]=nil
	end)
	for _,player in ipairs(Players:GetPlayers()) do startPlayer(player) end
	task.spawn(function()
		while true do
			task.wait(Config.HeartbeatSeconds)
			local seen={}
			for _,player in ipairs(Players:GetPlayers()) do
				local session=self._sessions[player]
				if session and not session.Established then task.spawn(added,player,session) else self:Heartbeat(player) end
				local party=self:GetParty(player)
				if party and not seen[party.Id] then seen[party.Id]=true; self:RefreshParty(party) end
			end
		end
	end)
end

return PartyService
