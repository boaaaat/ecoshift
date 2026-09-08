-- EcoShift's cross-lobby queue supplements Roblox's native public-lobby ranking.
local Players=game:GetService("Players")
local MemoryStore=game:GetService("MemoryStoreService")
local HttpService=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.SessionConfig)
local Policy=require(RS.Shared.MatchmakingPolicy)
local Parties=require(script.Parent.PartyService)
local Profiles=require(script.Parent.ProfileService)
local Signals=require(script.Parent.RobloxMatchmakingSignals)
local Service={_exportedParty={},_processing={}}
local hints=MemoryStore:GetHashMap(Config.Namespace..":queue-hints")
local tickets=MemoryStore:GetSortedMap(Config.Namespace..":queue-tickets")
local pending=MemoryStore:GetSortedMap(Config.Namespace..":queue-commits")
local workerId=HttpService:GenerateGUID(false)
local function attempt(callback)
	local ok,result=pcall(callback)
	if not ok then warn("[Matchmaking] Shared queue temporarily unavailable:",result) end
	return ok,result
end
local function size(members) local n=0; for _ in pairs(members) do n+=1 end; return n end
local function removeTicket(id,token)
	if not token then return end
	-- Keep a short tombstone: a delayed refresh cannot resurrect the same ticket.
	attempt(function() return tickets:UpdateAsync(id,function(old)
		if not old or old.Token~=token then return nil end
		old.Removed=true; old.ExpiresAt=0; old.Members={}; return old,old.QueuedAt
	end,50) end)
end
local function terminal(record,stage)
	local ok,result=attempt(function() return pending:UpdateAsync(record.Id,function(old)
		if not old or old.LeaseToken~=record.LeaseToken or (old.LeaseUntil or 0)<=os.time() then return nil end
		old.Stage=stage; return old,old.CreatedAt
	end,60) end)
	return ok and result and result.Stage==stage
end

function Service:_validate(party)
	local nativeType
	if size(party.Members)>Config.MaxPartySize then return false,"The crew is too large." end
	for _,member in pairs(party.Members) do
		local p,ok=Parties:GetPresence(member.UserId)
		if not ok then return false,"Connection status is temporarily unavailable." end
		if not p or not p.Online or p.ExpiresAt<=os.time() or p.Mode~="Lobby" then return false,"Every crew member must be online in a lobby." end
		if not member.Ready then return false,"Every crew member must ready up." end
		if not Policy.IsMatchmakingType(p.MatchmakingType) then return false,"A crew member's platform matchmaking is not ready." end
		if nativeType and nativeType~=p.MatchmakingType then return false,"Crew members have incompatible cross-play settings." end
		nativeType=p.MatchmakingType
	end
	return true,nativeType
end

function Service:Join(player)
	if Config.GetMode()~="Lobby" then return false,"Matchmaking starts in the lobby." end
	local party,err=Parties:GetParty(player)
	if not party then return false,err or "Create a party and ready up first." end
	if party.LeaderId~=player.UserId then return false,"Only the crew leader can queue." end
	if party.RunId then return false,"Finish or save the current expedition first." end
	local valid,nativeType=self:_validate(party)
	if not valid then return false,nativeType end
	local saves=require(script.Parent.WorldSaveService)
	for _,member in pairs(party.Members) do
		local room,reason=saves:HasFreeSlot(member.UserId)
		if room~=true then return false,reason or "Save-slot availability is temporarily unavailable." end
	end
	local token=HttpService:GenerateGUID(false)
	local updated,reason=Parties:Mutate(party.Id,function(current)
		if current.Revision~=party.Revision or current.Queue or current.RunId then return false,"Your crew changed. Ready up and try again." end
		current.Queue={Token=token,QueuedAt=os.time(),Generation=DateTime.now().UnixTimestampMillis,MatchmakingType=nativeType,State="Searching"}
		return true
	end)
	return updated~=nil,reason or "Finding a six-player crew with complementary classes."
end

function Service:Cancel(player)
	local party,err=Parties:GetParty(player)
	if not party then return false,err or "You are not in a party." end
	if party.LeaderId~=player.UserId then return false,"Only the crew leader can cancel." end
	if party.RunId then return false,"Your expedition is already starting." end
	if not party.Queue then return true,"You are not matchmaking." end
	local updated,reason=Parties:CancelQueue(party.Id,party.Queue.Token)
	if updated then removeTicket(party.Id,party.Queue.Token) end
	return updated==true,reason or "Matchmaking cancelled."
end

function Service:_refresh(party)
	local queue=party.Queue
	if not queue then return end
	if queue.MatchId then return end
	local valid=self:_validate(party)
	if not valid then
		Parties:CancelQueue(party.Id,queue.Token)
		removeTicket(party.Id,queue.Token); return
	end
	local members={}
	for id,member in pairs(party.Members) do
		local ok,hint=attempt(function() return hints:GetAsync(id) end)
		if not ok or not hint or hint.QueueToken~=queue.Token or hint.ExpiresAt<=os.time() or hint.Class~=member.Role then return end
		table.insert(members,hint)
	end
	attempt(function() return tickets:UpdateAsync(party.Id,function(old)
		local generation=queue.Generation or queue.QueuedAt*1000
		if old and (old.Generation or old.QueuedAt*1000)>generation then return nil end
		if old and old.Token==queue.Token and old.Removed then return nil end
		return {Id=party.Id,Token=queue.Token,QueuedAt=queue.QueuedAt,Generation=generation,
			ExpiresAt=os.time()+50,MatchmakingType=queue.MatchmakingType,Members=members},queue.QueuedAt
	end,50) end)
end

function Service:_release(record)
	local released=Parties:AbortMatch(record.Sources,record.Id,record.WorldId,record.LeaseToken)
	if released~=true then return false end
	for _,source in ipairs(record.Sources) do removeTicket(source.Id,source.Token) end
	return terminal(record,"Aborted")
end

function Service:_process(record)
	if self._processing[record.Id] or record.Stage=="Done" or record.Stage=="Aborted" then return end
	self._processing[record.Id]=true
	local worked,problem=pcall(function()
	-- Unique acquisition tokens fence even an earlier worker on this same server.
	local leaseToken=HttpService:GenerateGUID(false)
	local ok,claimed=attempt(function() return pending:UpdateAsync(record.Id,function(old)
		if not old or old.Stage=="Done" or old.Stage=="Aborted" then return nil end
		if old.LeaseToken and (old.LeaseUntil or 0)>os.time() then return nil end
		old.Owner=workerId; old.LeaseToken=leaseToken; old.LeaseUntil=os.time()+90; return old,old.CreatedAt
	end,Config.PartyTTL) end)
	if not ok or not claimed or claimed.LeaseToken~=leaseToken then return end
	if not Parties:ClaimMerge(claimed.WorldId,claimed.Id,leaseToken) then return end
	if claimed.Stage~="Claimed" then
		if os.time()-claimed.CreatedAt>90 then self:_release(claimed) end
		return
	end
	local module=script.Parent:FindFirstChild("WorldSessionService")
	if not module then return end
	local success,result=pcall(function() return require(module):CreateMatchedExpedition(claimed) end)
	if success and result==true then
		for _,source in ipairs(claimed.Sources) do removeTicket(source.Id,source.Token) end
		terminal(claimed,"Done")
	elseif success and result==false then
		-- The world service returns false only before any irreversible crew commit.
		self:_release(claimed)
	elseif not success then warn("[Matchmaking] Expedition commit will retry:",result) end
	end)
	self._processing[record.Id]=nil
	if not worked then warn("[Matchmaking] Commit worker will retry:",problem) end
end

function Service:_match()
	local ok,entries=attempt(function() return tickets:GetRangeAsync(Enum.SortDirection.Ascending,100) end)
	if not ok then return end
	local candidates={}; for _,entry in ipairs(entries) do if not entry.value.Removed then table.insert(candidates,entry.value) end end
	local match=Policy.Choose(candidates,{Now=os.time(),MatchmakingType=Signals.MatchmakingType()})
	if not match then return end
	local id=HttpService:GenerateGUID(false)
	local record={Id=id,WorldId=HttpService:GenerateGUID(false),Sources={},Roster={},CreatedAt=os.time(),MatchmakingType=match.MatchmakingType,
		Stage="Preparing",Owner=workerId,LeaseToken=HttpService:GenerateGUID(false),LeaseUntil=os.time()+90}
	for _,ticket in ipairs(match.Parties) do table.insert(record.Sources,{Id=ticket.Id,Token=ticket.Token}) end
	for _,member in ipairs(match.Members) do table.insert(record.Roster,member.UserId) end
	table.sort(record.Roster)
	-- Write recovery intent before claiming any party. No chat-group data is copied.
	local saved=attempt(function() pending:SetAsync(id,record,Config.PartyTTL,record.CreatedAt) end)
	if not saved then return end
	if not Parties:ClaimMerge(record.WorldId,id,record.LeaseToken) then return end
	for _,source in ipairs(record.Sources) do
		local current=Parties:GetPartyById(source.Id)
		if not current or not self:_validate(current) then self:_release(record); return end
		local claimed=Parties:Mutate(source.Id,function(party)
			if record.LeaseUntil<=os.time() then return false,"The matching worker lease expired." end
			if not party.Queue or party.Queue.Token~=source.Token or party.Queue.MatchId then return false,"Already claimed." end
			party.Queue.MatchId=id; party.Queue.State="Matching"; return true
		end)
		if not claimed then self:_release(record); return end
	end
	local committed,ready=attempt(function() return pending:UpdateAsync(id,function(old)
		if not old or old.LeaseToken~=record.LeaseToken or old.LeaseUntil<=os.time() then return nil end
		old.Stage="Claimed"; old.LeaseUntil=0; return old,old.CreatedAt
	end,Config.PartyTTL) end)
	if not committed or not ready or ready.Stage~="Claimed" then return end
	-- Release the preparation lease so the processing acquisition can run immediately.
	Parties:ReleaseMergeLease(record.WorldId,id,record.LeaseToken)
	self:_process(record)
end

function Service:Init()
	if self._started or Config.GetMode()~="Lobby" then return end; self._started=true
	Signals.Invalidated:Connect(function(userId)
		local exported=self._exportedParty[userId]
		self._exportedParty[userId]=nil
		if exported then removeTicket(exported.Id,exported.Token) end
		-- Remove every ticket containing this player, even before the next refresh.
		local player=Players:GetPlayerByUserId(userId)
		if player then local party=Parties:GetParty(player); if party then
			if party.Queue then
				removeTicket(party.Id,party.Queue.Token)
				Parties:CancelQueue(party.Id,party.Queue.Token)
			end
		end end
	end)
	task.spawn(function()
		while true do
			local seen={}
			for _,player in ipairs(Players:GetPlayers()) do
				local party=Parties:GetParty(player)
				if party and party.Queue and not party.RunId and Profiles:IsLoaded(player) then
					local hint=Signals.Capture(player)
					if hint then
						local p=Parties:GetPresence(player.UserId)
						local member=party.Members[tostring(player.UserId)]
						if p and member and p.Session==member.Session then
							self._exportedParty[player.UserId]={Id=party.Id,Token=party.Queue.Token}
							hint.QueueToken=party.Queue.Token; hint.Generation=p.SessionAt or 0
							attempt(function() return hints:UpdateAsync(tostring(player.UserId),function(old)
								if old and (old.Generation or 0)>hint.Generation then return nil end
								return hint
							end,50) end)
						end
					end
					seen[party.Id]=party
				else
					local old=self._exportedParty[player.UserId]; self._exportedParty[player.UserId]=nil
					if old then removeTicket(old.Id,old.Token) end
				end
			end
			for _,party in pairs(seen) do self:_refresh(party) end
			local ok,commits=attempt(function() return pending:GetRangeAsync(Enum.SortDirection.Ascending,20) end)
			if ok then for _,entry in ipairs(commits) do self:_process(entry.value) end end
			self:_match()
			task.wait(5)
		end
	end)
end
return Service
