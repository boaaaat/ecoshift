-- Server-owned lobby actions, also serving the expedition's persistent party panel.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.SessionConfig)
local Economy=require(RS.Shared.EconomyConfig)
local Classes=require(RS.Shared.Config).ROLES
local Profile=require(script.Parent.ProfileService)
local Roles=require(script.Parent.RoleService)
local Parties=require(script.Parent.PartyService)
local HttpService=game:GetService("HttpService")
local Service={_clients={}}
local actions={Snapshot=true,CreateParty=true,Invite=true,AcceptInvite=true,LeaveParty=true,Ready=true,
	SelectClass=true,BuyClass=true,StartExpedition=true,Queue=true,CancelQueue=true,ResumeWorld=true,Rejoin=true,ReturnLobby=true,RenameWorld=true,RemoveWorld=true}
local sections={Core=true,Archive=true,Rejoin=true,InviteDirectory=true}
local messages={
	InsufficientCurrency="You need more "..Economy.CurrencyName.." to unlock this class. Earn them on expeditions.",
	InsufficientFunds="You need more "..Economy.CurrencyName.." to unlock this class. Earn them on expeditions.",
	ProfileUnavailable="Your profile is still loading. Try again shortly.",
	SavePending="Your change is still saving. We will retry it automatically.",
	PendingQueueFull="Your earlier changes are still saving. Try again shortly.",
	LobbyOnly="Return to the lobby to change or unlock your class.",
	RoleLocked="Unlock this class before equipping it.",
	InvalidRole="That class is unavailable. Refresh the outfitter and choose again.",
	RoleNotForSale="This class is not available to unlock right now.",
	AlreadyOwned="You already own this class.",
	Superseded="Your newer class choice is already applied.",
	RateLimited="Please wait a moment before trying that again.",
	ArchiveFull="You need a free save slot before starting a new expedition.",
	ArchiveUnavailable="The world archive is temporarily unavailable. Try again shortly.",
	CommitPending="Your crew's save slots are still being prepared. Please wait.",
	WorldResumeInProgress="Your crew's saved world is already being prepared. Please wait.",
	ResumeDecisionPending="Your crew's resume request is still being resolved. Keep your crew together.",
	CrewChanged="Your crew changed. Confirm everyone is ready, then try again.",
}
local function displayMessage(action,success,reason)
	if reason=="Saved" then
		if action=="SelectClass" then return "Class equipped. Ready up when your crew is prepared." end
		if action=="BuyClass" then return "Class unlocked. You can now equip it." end
		return "Your changes were saved."
	end
	if type(reason)=="string" then
		if messages[reason] then return messages[reason] end
		if not reason:match("^[%w_]+$") then return reason end
	end
	return success and "Updated." or "That action could not finish. Refresh the lobby and try again."
end
local function optional(name) local module=script.Parent:FindFirstChild(name); return module and require(module) end
function Service:Snapshot(player,section,data)
	if section=="Archive" then
		local worlds=optional("WorldSaveService")
		local saves,archiveError,archiveStatus={}
		if worlds then saves,archiveError,archiveStatus=worlds:List(player) end
		return {Worlds=saves or {},ArchiveAvailable=worlds~=nil and archiveError==nil,
			ArchiveError=archiveError,ArchiveStatus=archiveStatus or {PendingCount=0}}
	elseif section=="Rejoin" then
		local runs=optional("WorldSessionService")
		return {Rejoin=runs and runs:GetRejoinSummary(player) or false}
	elseif section=="InviteDirectory" then
		return {InviteDirectory=require(script.Parent.InviteDirectoryService):Snapshot(player,data and data.FriendIds)}
	end
	-- Party storage can yield; read the local profile after it, without waiting
	-- for the archive or world reservation lookups to finish.
	local party=Parties:Snapshot(player)
	local profile=Profile:GetProfile(player)
	local classes={}
	for id,def in pairs(Classes.Definitions) do
		table.insert(classes,{Id=id,Name=def.Name,Price=Economy.ClassPrices[id] or 0,
			Owned=profile and profile.UnlockedRoles[id]==true or false,Selected=profile and profile.Role==id or false,
			Gather=def.Gather,Build=def.Build,Combat=def.Combat,Heal=def.Heal,Craft=def.Craft})
	end
	table.sort(classes,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end)
	return {Mode=Config.GetMode(),ProfileReady=Profile:IsLoaded(player),Currency=profile and profile.Currency or 0,
		CurrencyName=Economy.CurrencyName,Classes=classes,Party=party}
end
function Service:_handle(player,action,data)
	if action=="CreateParty" then return Parties:Create(player)
	elseif action=="Invite" then return Parties:Invite(player,data.UserId~=nil and data.UserId or data.Username)
	elseif action=="AcceptInvite" then return Parties:Accept(player,data.Id)
	elseif action=="LeaveParty" then return Parties:Leave(player)
	elseif action=="Ready" then return Parties:SetReady(player,data.Ready)
	elseif action=="SelectClass" then return Roles:SetRole(player,data.Id)
	elseif action=="BuyClass" then return Roles:PurchaseRole(player,data.Id)
	elseif action=="StartExpedition" or action=="Queue" or action=="CancelQueue" then
		if Config.GetMode()~="Lobby" then return false,"Return to the lobby to find a new expedition." end
		local queue=optional("MatchmakingService")
		if not queue then return false,"Matchmaking is temporarily unavailable." end
		if action=="StartExpedition" then return queue:StartParty(player) end
		if action=="Queue" then return queue:Join(player) end
		return queue:Cancel(player)
	elseif action=="ResumeWorld" or action=="Rejoin" or action=="ReturnLobby" then
		local runs=optional("WorldSessionService")
		if not runs then return false,"Expedition travel is temporarily unavailable." end
		if action=="ResumeWorld" then return runs:Resume(player,data.Id)
		elseif action=="Rejoin" then return runs:Rejoin(player)
		else return runs:ReturnToLobby(player) end
	elseif action=="RenameWorld" or action=="RemoveWorld" then
		local worlds=optional("WorldSaveService")
		if not worlds then return false,"The world archive is temporarily unavailable." end
		if action=="RemoveWorld" then return worlds:RemoveCopy(player,data.Id) end
		return worlds:Rename(player,data.Id,data.Name)
	end
	return false,"That action is unavailable."
end

function Service:_send(player,event,payload)
	if player.Parent==Players then self._remote:FireClient(player,event,payload) end
end

function Service:_read(player,state,section,requestId,data)
	local reader=state.Reads[section]
	if not reader then reader={}; state.Reads[section]=reader end
	reader.Pending={RequestId=requestId,Data=data}
	if reader.Running then return end
	reader.Running=true
	task.spawn(function()
		while self._clients[player]==state and player.Parent==Players and reader.Pending do
			while state.Busy and self._clients[player]==state do task.wait(.05) end
			if self._clients[player]~=state or player.Parent~=Players then break end
			local request=reader.Pending; reader.Pending=nil
			local revision=state.Revision
			state.SnapshotId+=1; local snapshotId=state.SnapshotId
			local ok,payload=pcall(self.Snapshot,self,player,section,request.Data)
			if self._clients[player]~=state then break end
			if state.Revision~=revision or state.Busy then
				-- A read begun before a mutation cannot publish after its result.
				reader.Pending=reader.Pending or request
			elseif ok then
				payload.Partial=true; payload.Section=section; payload.StateRevision=revision
				payload.SnapshotId=snapshotId; payload.RequestId=request.RequestId; payload.ServerTime=os.time()
				self:_send(player,"Snapshot",payload)
			else
				self:_send(player,"SnapshotError",{RequestId=request.RequestId,Action="Snapshot",Section=section,
					StateRevision=revision,SnapshotId=snapshotId,Message="This part of the lobby could not refresh. Try again shortly."})
				warn("[LobbyService] Section refresh will retry:",section)
			end
		end
		reader.Running=false
	end)
end

function Service:_refresh(player,state,scope,requestId,data)
	if scope=="All" then
		for _,section in ipairs({"Core","Archive","Rejoin"}) do self:_read(player,state,section,requestId,data) end
	else self:_read(player,state,scope,requestId,data) end
end

function Service:_receive(player,action,data)
	if type(action)~="string" or (data~=nil and type(data)~="table") then return end
	data=data or {}
	local requestId=data.RequestId
	if requestId~=nil and (type(requestId)~="string" or #requestId<1 or #requestId>80) then return end
	requestId=requestId or HttpService:GenerateGUID(false)
	local state=self._clients[player]
	if not state then state={Revision=0,SnapshotId=0,Reads={},Requests={},Rates={}}; self._clients[player]=state end
	local function reject(code,message,retryAfter)
		self:_send(player,"Result",{RequestId=requestId,Action=action,Success=false,Code=code,
			Message=message,RetryAfter=retryAfter,StateRevision=state.Revision})
	end
	if not actions[action] then reject("InvalidAction","That action is unavailable."); return end
	local scope=action=="Snapshot" and (data.Scope or "All") or nil
	if scope and scope~="All" and not sections[scope] then reject("InvalidScope","That lobby section is unavailable."); return end
	local now=os.clock()
	local previous=state.Requests[requestId]
	if previous then
		if previous.Action~=action then reject("RequestIdConflict","Use a new request for that action."); return end
		if previous.Result then
			local replay=table.clone(previous.Result); replay.Replayed=true; replay.StateRevision=state.Revision
			self:_send(player,"Result",replay)
		else self:_send(player,"Accepted",{RequestId=requestId,Action=action,StateRevision=state.Revision,Replayed=true}) end
		return
	end
	local rateKey=scope and ("Snapshot:"..scope) or action
	local cooldown=scope and (scope=="InviteDirectory" and 5 or 1) or (action=="Invite" and 2 or .45)
	local remaining=cooldown-(now-(state.Rates[rateKey] or -math.huge))
	if remaining>0 then reject("RateLimited","Please wait a moment before trying that again.",remaining); return end
	if not scope and state.Busy then reject("Busy","Your previous action is still finishing.",.5); return end
	if not scope and now-(state.LastMutation or -math.huge)<.15 then reject("RateLimited","Please wait a moment before trying that again.",.15); return end
	local count=0
	for id,entry in pairs(state.Requests) do
		if entry.Result and now-entry.At>120 then state.Requests[id]=nil else count+=1 end
	end
	if count>=128 then reject("RateLimited","Too many recent requests. Please wait a moment.",2); return end
	state.Rates[rateKey]=now
	local request={Action=action,At=now}; state.Requests[requestId]=request
	if not scope then
		state.Busy=requestId; state.LastMutation=now; state.Revision+=1
	end
	self:_send(player,"Accepted",{RequestId=requestId,Action=action,StateRevision=state.Revision})
	if scope then
		self:_refresh(player,state,scope,requestId,data)
		request.Result={RequestId=requestId,Action=action,Success=true,Code="RefreshQueued",Message="Refreshing.",StateRevision=state.Revision}
		self:_send(player,"Result",request.Result)
		return
	end
	local ok,success,message=pcall(function()
		if not Profile:IsLoaded(player) then return false,"Your profile is still loading. Try again shortly." end
		return self:_handle(player,action,data)
	end)
	-- Never hold the mutation lock across archive, directory or party refreshes.
	state.Busy=nil; state.Revision+=1
	request.Result={RequestId=requestId,Action=action,Success=ok and success==true,
		Code=not ok and "ServiceUnavailable" or success==true and "Completed" or "ActionRejected",
		Message=ok and displayMessage(action,success==true,message) or "Service unavailable. Please try again.",
		StateRevision=state.Revision}
	if ok and success==true and (action=="SelectClass" or action=="BuyClass") then
		local profile=Profile:GetProfile(player)
		request.Result.ConfirmedRole=profile and profile.Role or player:GetAttribute("Role")
	end
	self:_send(player,"Result",request.Result)
	if self._clients[player]~=state then return end
	self:_refresh(player,state,"Core",requestId)
	if action=="RenameWorld" or action=="RemoveWorld" or action=="ResumeWorld" then self:_refresh(player,state,"Archive",requestId) end
	if action=="ResumeWorld" or action=="Rejoin" or action=="ReturnLobby" or action=="LeaveParty" then self:_refresh(player,state,"Rejoin",requestId) end
end

function Service:Init()
	if self._started then return end; self._started=true
	local remote=RS.Remotes:FindFirstChild("Lobby") or Instance.new("RemoteEvent")
	remote.Name="Lobby"; remote.Parent=RS.Remotes; self._remote=remote
	remote.OnServerEvent:Connect(function(player,action,data) self:_receive(player,action,data) end)
	Players.PlayerRemoving:Connect(function(player)
		self._clients[player]=nil
		local directory=script.Parent:FindFirstChild("InviteDirectoryService")
		if directory then require(directory):Forget(player) end
	end)
end
return Service
