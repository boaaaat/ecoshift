-- The client gets online friends through LocalPlayer:GetFriendsOnlineAsync.
-- Submitted IDs are lookup hints only; this service exposes EcoShift presence,
-- never a client's assertion of friendship, location, or invitation authority.
local Players=game:GetService("Players")
local Config=require(game:GetService("ReplicatedStorage").Shared.SessionConfig)
local Parties=require(script.Parent.PartyService)
local Service={_cache={},_inflight={}}
local MAX_FRIENDS=200
local function validId(id)
	return type(id)=="number" and id>0 and id<2^53 and id%1==0
end
function Service:Forget(player) self._cache[player]=nil; self._inflight[player]=nil end
function Service:Snapshot(player,friendIds)
	local ids,seen={},{}
	if type(friendIds)=="table" then
		for index,id in ipairs(friendIds) do
			if index>MAX_FRIENDS then break end
			if validId(id) and id~=player.UserId and not seen[id] then seen[id]=true; table.insert(ids,id) end
		end
	end
	local entries,byId={},{}
	for _,target in ipairs(Players:GetPlayers()) do
		if target~=player then
			local item={UserId=target.UserId,Name=target.Name,DisplayName=target.DisplayName,InServer=true,
				InExperience=true,Location=Config.GetMode(),CanPartyInvite=Config.GetMode()=="Lobby",PresenceAvailable=true}
			byId[target.UserId]=item; table.insert(entries,item)
		end
	end
	local cache=self._cache[player] or {}; self._cache[player]=cache
	local inflight=self._inflight[player] or {Count=0}; self._inflight[player]=inflight
	local pending,nextIndex,finished={},1,0
	for _,id in ipairs(ids) do if not byId[id] then table.insert(pending,id) end end
	-- Bounded workers keep a large friend list from serially waiting on storage.
	local deadline=os.clock()+8
	local workers=math.min(math.max(0,6-inflight.Count),#pending)
	for _=1,workers do
		inflight.Count+=1
		task.spawn(function()
		pcall(function() while os.clock()<deadline and player.Parent==Players do
			local index=nextIndex; nextIndex+=1
			local id=pending[index]; if not id then return end
			local cached=cache[id]
			local presence,available
			if cached and cached.Until>os.clock() then presence,available=cached.Presence,cached.Available
			else
				presence,available=Parties:GetPresence(id)
				if self._cache[player]~=cache then return end
				cache[id]={Presence=presence,Available=available,Until=os.clock()+15}
			end
			local inExperience=available and presence and (presence.Online or (presence.TransferUntil or 0)>os.time()) and (presence.ExpiresAt or 0)>os.time() or false
			byId[id]={UserId=id,InServer=false,InExperience=inExperience==true,
				Location=inExperience and presence.Mode or "OutsideEcoShift",CanPartyInvite=inExperience and presence.Mode=="Lobby" or false,
				PresenceAvailable=available==true}
			finished+=1
		end end)
		inflight.Count-=1
	end) end
	while workers>0 and finished<#pending and os.clock()<deadline and player.Parent==Players do task.wait(.05) end
	local complete=true
	for _,id in ipairs(pending) do
		local entry=byId[id]
		if not entry then entry={UserId=id,InServer=false,InExperience=false,CanPartyInvite=false,PresenceAvailable=false}; complete=false end
		if not entry.PresenceAvailable then complete=false end
		table.insert(entries,entry)
	end
	-- Do not retain unbounded arbitrary lookup IDs between picker refreshes.
	for id in pairs(cache) do if not seen[id] then cache[id]=nil end end
	table.sort(entries,function(a,b) if a.InServer~=b.InServer then return a.InServer end; return a.UserId<b.UserId end)
	return {Available=true,PresenceComplete=complete,Entries=entries,UpdatedAt=os.time(),
		Message=not complete and "Some crew connections are still synchronizing." or nil}
end
return Service
