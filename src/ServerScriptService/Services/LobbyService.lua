-- Server-owned lobby actions, also serving the expedition's persistent party panel.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.SessionConfig)
local Economy=require(RS.Shared.EconomyConfig)
local Classes=require(RS.Shared.Config).ROLES
local Profile=require(script.Parent.ProfileService)
local Roles=require(script.Parent.RoleService)
local Parties=require(script.Parent.PartyService)
local Service={_busy={},_requests={}}
local actions={Snapshot=true,CreateParty=true,Invite=true,AcceptInvite=true,LeaveParty=true,Ready=true,
	SelectClass=true,BuyClass=true,Queue=true,CancelQueue=true,ResumeWorld=true,Rejoin=true,ReturnLobby=true,RenameWorld=true,RemoveWorld=true}
local function optional(name) local module=script.Parent:FindFirstChild(name); return module and require(module) end
function Service:Snapshot(player)
	local profile=Profile:GetProfile(player)
	local classes={}
	for id,def in pairs(Classes.Definitions) do
		table.insert(classes,{Id=id,Name=def.Name,Price=Economy.ClassPrices[id] or 0,
			Owned=profile and profile.UnlockedRoles[id]==true or false,Selected=profile and profile.Role==id or false,
			Gather=def.Gather,Build=def.Build,Combat=def.Combat,Heal=def.Heal,Craft=def.Craft})
	end
	table.sort(classes,function(a,b) if a.Price==b.Price then return a.Name<b.Name end; return a.Price<b.Price end)
	local worlds=optional("WorldSaveService")
	local runs=optional("WorldSessionService")
	local saves,archiveError,archiveStatus={}
	if worlds then saves,archiveError,archiveStatus=worlds:List(player) end
	return {Mode=Config.GetMode(),ProfileReady=Profile:IsLoaded(player),Currency=profile and profile.Currency or 0,
		CurrencyName=Economy.CurrencyName,Classes=classes,Party=Parties:Snapshot(player),
		Worlds=saves or {},ArchiveAvailable=worlds~=nil and archiveError==nil,ArchiveError=archiveError,ArchiveStatus=archiveStatus,
		Rejoin=runs and runs:GetRejoinSummary(player) or nil}
end
function Service:_handle(player,action,data)
	if action=="CreateParty" then return Parties:Create(player)
	elseif action=="Invite" then return Parties:Invite(player,data.Username)
	elseif action=="AcceptInvite" then return Parties:Accept(player,data.Id)
	elseif action=="LeaveParty" then return Parties:Leave(player)
	elseif action=="Ready" then return Parties:SetReady(player,data.Ready)
	elseif action=="SelectClass" then return Roles:SetRole(player,data.Id)
	elseif action=="BuyClass" then return Roles:PurchaseRole(player,data.Id)
	elseif action=="Queue" or action=="CancelQueue" then
		if Config.GetMode()~="Lobby" then return false,"Return to the lobby to find a new expedition." end
		local queue=optional("MatchmakingService")
		if not queue then return false,"Matchmaking is temporarily unavailable." end
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
function Service:Init()
	if self._started then return end; self._started=true
	local remote=RS.Remotes:FindFirstChild("Lobby") or Instance.new("RemoteEvent")
	remote.Name="Lobby"; remote.Parent=RS.Remotes; self._remote=remote
	remote.OnServerEvent:Connect(function(player,action,data)
		if type(action)~="string" or not actions[action] or (data~=nil and type(data)~="table") then return end
		local now=os.clock(); local requests=self._requests[player] or {}; self._requests[player]=requests
		if now-(requests.Total or -math.huge)<.3 then return end
		if now-(requests[action] or -math.huge)<(action=="Snapshot" and 2 or .6) then return end
		requests[action]=now; requests.Total=now
		if self._busy[player] then return end
		self._busy[player]=true
		local ok,success,message=pcall(function()
			if action=="Snapshot" then return true end
			if not Profile:IsLoaded(player) then return false,"Your profile is still loading. Try again shortly." end
			return self:_handle(player,action,data or {})
		end)
		if player.Parent==Players then
			if action~="Snapshot" then remote:FireClient(player,"Result",{Success=ok and success==true,Message=ok and (message or (success and "Updated." or "Could not complete that action.")) or "Service unavailable. Please try again."}) end
			local fetched,snapshot=pcall(function() return self:Snapshot(player) end)
			if fetched then remote:FireClient(player,"Snapshot",snapshot) else warn("[LobbyService] Snapshot failed:",snapshot) end
		end
		self._busy[player]=nil
	end)
	Players.PlayerRemoving:Connect(function(player) self._requests[player]=nil; self._busy[player]=nil end)
end
return Service
