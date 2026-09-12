-- Server owns cooldowns, targets and effects. Clients submit intent only.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Tags = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Classes = require(RS.Shared.ClassConfig)
local Stats = require(script.Parent.StatsService)
local Service = { _states={}, _effects={}, _fields={}, _marks={}, _overclocks={} }
local function pose(object)
	if typeof(object)~="Instance" then return nil end
	if object:IsA("Model") then local hrp=object:FindFirstChild("HumanoidRootPart"); return hrp and hrp.Position or object:GetPivot().Position end
	if object:IsA("BasePart") then return object.Position end
	return nil
end
local function living(player)
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return player and player.Parent==Players and hum and hum.Health>0 and not player:GetAttribute("IsDead")
		and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring")
end
local function root(player) return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function boss(model) return model:GetAttribute("IsBoss")==true or model:GetAttribute("Boss")==true or Tags:HasTag(model,"Boss") end
local function monster(model)
	if typeof(model)~="Instance" or not model:IsA("Model") or not model:IsDescendantOf(workspace) or not Tags:HasTag(model,"Monster") then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local health = model:FindFirstChild("Health")
	return (hum and hum.Health>0) or (health and health:IsA("ValueBase") and tonumber(health.Value) and health.Value>0)
end
local function visible(player,target,range)
	local origin,position = root(player),pose(target)
	if not origin or not position or (origin.Position-position).Magnitude>range then return false end
	local params = RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={player.Character}; params.RespectCanCollide=true
	local hit=workspace:Raycast(origin.Position,position-origin.Position,params)
	return not hit or hit.Instance==target or hit.Instance:IsDescendantOf(target)
end
local function restore(player,health,energy,hunger,exposure)
	if not living(player) then return end
	local hum=player.Character:FindFirstChildOfClass("Humanoid")
	if health and health>0 then hum.Health=math.min(hum.MaxHealth,hum.Health+health) end
	local values={}
	if energy and energy>0 then values.Stamina=math.min(Stats:GetStat(player,"MaxStamina") or 100,(Stats:GetBase(player,"Stamina") or 0)+energy) end
	if hunger and hunger>0 then values.Hunger=math.min(Stats:GetStat(player,"MaxHunger") or 100,(Stats:GetBase(player,"Hunger") or 0)+hunger) end
	if exposure and exposure>0 then local temp=Stats:GetBase(player,"Temperature") or 0; values.Temperature=math.sign(temp)*math.max(0,math.abs(temp)-exposure) end
	if next(values) then Stats:SetBaseStats(player,values) end
end
function Service:_state(player)
	local state=self._states[player]
	if not state then state={Remaining=0}; self._states[player]=state end
	return state
end
function Service:CapturePlayer(player) return {Version=1,Remaining=self:_state(player).Remaining} end
function Service:RestorePlayer(player,data)
	if data~=nil then
		assert(type(data)=="table" and data.Version==1 and type(data.Remaining)=="number" and data.Remaining==data.Remaining and data.Remaining>=0 and data.Remaining<=240,"Invalid class ability cooldown")
	end
	self:_clearOwner(player)
	self._states[player]={Remaining=data and data.Remaining or 0}
	Stats:SetModifier(player,"MaxHealth",player:GetAttribute("Class_MaxHealth") or 0,"Add","ClassHealth")
	Stats:SetModifier(player,"Speed",player:GetAttribute("Class_SpeedBonus") or 0,"Mult","ClassSpeed")
	player:SetAttribute("AbilityCooldownRemaining",self._states[player].Remaining)
end
function Service:_effect(owner,target,kind,values,duration)
	table.insert(self._effects,{Owner=owner,Target=target,Kind=kind,Values=values,Started=os.clock(),Until=os.clock()+duration,Character=target.Character})
end
function Service:_strongest(target,kind,key)
	local value=0
	for _,effect in ipairs(self._effects) do
		if effect.Target==target and effect.Kind==kind and effect.Until>os.clock() and living(effect.Owner) and target.Character==effect.Character then value=math.max(value,effect.Values[key] or 0) end
	end
	return value
end
function Service:_restoration(target,kind,key,from,to)
	local points={from,to}
	for _,e in ipairs(self._effects) do
		if e.Target==target and e.Kind==kind and e.Character==target.Character and living(e.Owner) then
			table.insert(points,math.clamp(e.Started,from,to)); table.insert(points,math.clamp(e.Until,from,to))
		end
	end
	table.sort(points)
	local total=0
	for i=2,#points do
		local middle=(points[i-1]+points[i])*.5; local strongest=0
		for _,e in ipairs(self._effects) do
			if e.Target==target and e.Kind==kind and e.Character==target.Character and living(e.Owner) and e.Started<=middle and e.Until>middle then strongest=math.max(strongest,e.Values[key] or 0) end
		end
		total+=strongest*(points[i]-points[i-1])
	end
	return total
end
function Service:_publishEffects(player)
	player:SetAttribute("ClassHarvestPower",self:_strongest(player,"Harvest","Power"))
	player:SetAttribute("ClassHarvestReduction",self:_strongest(player,"Harvest","GatherReduction"))
	player:SetAttribute("ClassMineralPower",self:_strongest(player,"Mineral","Power"))
	player:SetAttribute("ClassReviveReduction",self:_strongest(player,"Rally","ReviveReduction"))
end
function Service:_clearOwner(owner)
	if self._remote then self._remote:FireAllClients("ClearMarkers",{Keys={tostring(owner.UserId)..":Scout",tostring(owner.UserId)..":Mineral","Mark:"..owner.UserId}}) end
	for i=#self._effects,1,-1 do if self._effects[i].Owner==owner then table.remove(self._effects,i) end end
	for i=#self._fields,1,-1 do if self._fields[i].Owner==owner then self._fields[i].Visual:Destroy(); table.remove(self._fields,i) end end
	for target,entries in pairs(self._marks) do
		entries[owner]=nil
		if not next(entries) then self._marks[target]=nil; if target.Parent then target:SetAttribute("ClassMarkedUntil",nil) end end
	end
	for station,entries in pairs(self._overclocks) do entries[owner]=nil; if not next(entries) then self._overclocks[station]=nil end end
	for _,model in ipairs(Tags:GetTagged("Monster")) do
		if model:GetAttribute("ClassTauntUserId")==owner.UserId then model:SetAttribute("ClassTauntUntil",nil); model:SetAttribute("ClassTauntUserId",nil) end
	end
	local deploy=script.Parent:FindFirstChild("ClassDeploymentService")
	if deploy then require(deploy):RemoveForPlayer(owner) end
	for _,player in ipairs(Players:GetPlayers()) do self:_publishEffects(player) end
end
function Service:GetMarkedBonus(target)
	local bonus=0
	for owner,mark in pairs(self._marks[target] or {}) do if living(owner) and mark.Until>os.clock() then bonus=math.max(bonus,mark.Bonus) end end
	return boss(target) and bonus*.5 or bonus
end
function Service:GetMonsterReduction(player)
	return math.clamp((player:GetAttribute("Class_MonsterReduction") or 0)+self:_strongest(player,"Warden","Reduction"),0,.5)
end
function Service:GetCraftRate(player,station)
	local bonus=0
	for owner,effect in pairs(self._overclocks[station] or {}) do if living(owner) and effect.Until>os.clock() then bonus=math.max(bonus,effect.Rate) end end
	return math.clamp(1+(player:GetAttribute("Class_CraftBonus") or 0)+bonus,1,2)
end
function Service:GetShelterEffect(player)
	local reduction,recovery=0,0
	local origin=root(player)
	if not origin then return 0,0 end
	for _,field in ipairs(self._fields) do
		if field.Until>os.clock() and living(field.Owner) and (origin.Position-field.Position).Magnitude<=20 then
			reduction=math.max(reduction,field.Reduction); recovery=math.max(recovery,field.Recovery)
		end
	end
	return reduction,recovery
end
function Service:_markers(player,radius,duration,mineralsOnly)
	local origin=root(player).Position
	local markers=require(script.Parent.ChunkStreamingService):GetClassScanMarkers(origin,radius,mineralsOnly)
	if not mineralsOnly then
		for _,model in ipairs(Tags:GetTagged("Monster")) do local pos=pose(model)
			if monster(model) and pos and (pos-origin).Magnitude<=radius then table.insert(markers,{Id=tostring(model),Position=pos,Kind="Monster",Label=model.Name,Target=model}) end
		end
	end
	self._remote:FireAllClients("Markers",{Markers=markers,Duration=duration,Key=tostring(player.UserId)..":"..(mineralsOnly and "Mineral" or "Scout")})
end
function Service:_activate(player,payload)
	if RS:GetAttribute("PlaceMode")~="Expedition" or RS:GetAttribute("WorldRestoring") or not living(player) or not root(player) then return false,"NotAlive" end
	if require(script.Parent.GameStateService):IsGameOver() then return false,"GameOver" end
	local id=player:GetAttribute("Role")
	local level=Classes.Level(player:GetAttribute("ClassLevel"))
	if not Classes.Definitions[id] or level<3 then return false,"Unlocks at class level 3" end
	local state=self:_state(player)
	if state.Remaining>0 then return false,"Ability is cooling down" end
	local a=Classes.GetAbility(id,level)
	if id=="Generalist" then restore(player,a.Health,a.Energy,0,a.Exposure)
	elseif id=="Gatherer" then self:_effect(player,player,"Harvest",a,a.Duration)
	elseif id=="Builder" then
		local ok,reason=require(script.Parent.ClassDeploymentService):Activate(player,payload,level)
		if not ok then return false,reason end
	elseif id=="Hunter" then
		local target=payload.Target
		while typeof(target)=="Instance" and target.Parent and not Tags:HasTag(target,"Monster") do target=target.Parent end
		if not monster(target) or not visible(player,target,a.Range) then return false,"Aim at a visible monster within 60 studs" end
		self._marks[target]=self._marks[target] or {}; self._marks[target][player]={Bonus=a.Bonus,Until=os.clock()+a.Duration}
		target:SetAttribute("ClassMarkedUntil",workspace:GetServerTimeNow()+a.Duration)
		self._remote:FireAllClients("Markers",{Markers={{Id=tostring(target),Target=target,Position=pose(target),Kind="Monster",Label="Marked prey"}},Duration=a.Duration,Key="Mark:"..player.UserId})
	elseif id=="Medic" or id=="Cook" then
		for _,target in ipairs(Players:GetPlayers()) do
			if living(target) and root(target) and (root(target).Position-root(player).Position).Magnitude<=a.Radius then
				if id=="Medic" then self:_effect(player,target,"Rally",a,a.Duration); self:_effect(player,target,"Heal",{Health=a.Health/5},5)
				else self:_effect(player,target,"Meal",{Hunger=a.Hunger/10,Energy=a.Energy/10},10) end
			end
		end
	elseif id=="Engineer" then
		local station=payload.Target
		while typeof(station)=="Instance" and station.Parent and not Tags:HasTag(station,"Structure") do station=station.Parent end
		local cfg=require(RS.Shared.WorkbenchConfig)
		if typeof(station)~="Instance" or not Tags:HasTag(station,"Structure") or not station:IsDescendantOf(workspace)
			or not station:GetAttribute("OwnerUserId") or not cfg.STATIONS[station:GetAttribute("BuildType") or station:GetAttribute("StationType")]
			or not visible(player,station,a.Range) then return false,"Aim at a crew crafting station within 12 studs" end
		self._overclocks[station]=self._overclocks[station] or {}; self._overclocks[station][player]={Rate=a.Rate,Until=os.clock()+a.Duration}
	elseif id=="Scout" then
		require(script.Parent.TeamExplorationService):RevealRadius(root(player).Position,a.Radius)
		self:_markers(player,a.Radius,a.Duration,false)
	elseif id=="Botanist" then
		local count=require(script.Parent.ChunkStreamingService):RegrowPlants(root(player).Position,a.Radius,a.Count)
		if count==0 then return false,"No eligible harvested plants nearby" end
	elseif id=="Prospector" then
		self:_effect(player,player,"Mineral",a,a.PowerDuration); self:_markers(player,a.Radius,a.Duration,true)
	elseif id=="Warden" then
		local targets={}
		for _,model in ipairs(Tags:GetTagged("Monster")) do local pos=pose(model)
			if monster(model) and not boss(model) and pos and (pos-root(player).Position).Magnitude<=a.Radius then table.insert(targets,model) end
		end
		table.sort(targets,function(x,y) return (pose(x)-root(player).Position).Magnitude<(pose(y)-root(player).Position).Magnitude end)
		for index=1,math.min(6,#targets) do targets[index]:SetAttribute("ClassTauntUserId",player.UserId); targets[index]:SetAttribute("ClassTauntUntil",os.clock()+a.TauntDuration) end
		self:_effect(player,player,"Warden",a,a.Duration)
	elseif id=="Climatologist" then
		local visual=Instance.new("Part"); visual.Name="ShelterField"; visual.Shape=Enum.PartType.Cylinder
		visual.Size=Vector3.new(.15,40,40); visual.CFrame=CFrame.new(root(player).Position-Vector3.new(0,2.8,0))*CFrame.Angles(0,0,math.pi/2)
		visual.Anchored=true; visual.CanCollide=false; visual.CanQuery=false; visual.CanTouch=false; visual.Transparency=.7; visual.Material=Enum.Material.Neon; visual.Color=Color3.fromRGB(127,184,169); visual.Parent=workspace
		table.insert(self._fields,{Owner=player,Position=root(player).Position,Reduction=a.Reduction,Recovery=a.Recovery,Until=os.clock()+a.Duration,Visual=visual})
	end
	state.Remaining=a.Cooldown; player:SetAttribute("AbilityCooldownRemaining",a.Cooldown)
	for _,target in ipairs(Players:GetPlayers()) do self:_publishEffects(target) end
	require(script.Parent.ExpeditionRewardsService):RecordActivity(player)
	return true,"Ability activated"
end
function Service:Init()
	if self._initialized then return end; self._initialized=true
	local remotes=RS:WaitForChild("Remotes")
	self._remote=remotes:FindFirstChild("ClassAbility") or Instance.new("RemoteEvent"); self._remote.Name="ClassAbility"; self._remote.Parent=remotes
	require(script.Parent.ClassDeploymentService):Init()
	self._remote.OnServerEvent:Connect(function(player,action,payload)
		if action~="Activate" or type(payload)~="table" then return end
		local state=self:_state(player); local now=os.clock()
		if state.Busy or now-(state.LastRequest or -math.huge)<.25 then return end
		state.LastRequest=now; state.Busy=true
		local called,ok,reason=pcall(self._activate,self,player,payload); state.Busy=false
		if not called then warn("[ClassAbility]",ok); ok,reason=false,"Ability unavailable; try again" end
		if player.Parent==Players then self._remote:FireClient(player,"Result",{Success=ok==true,Reason=reason,RequestId=payload.RequestId}) end
	end)
	local function bind(player)
		self:_state(player)
		local function stats()
			Stats:SetModifier(player,"MaxHealth",player:GetAttribute("Class_MaxHealth") or 0,"Add","ClassHealth")
			Stats:SetModifier(player,"Speed",player:GetAttribute("Class_SpeedBonus") or 0,"Mult","ClassSpeed")
		end
		player:GetAttributeChangedSignal("Class_MaxHealth"):Connect(stats)
		player:GetAttributeChangedSignal("Class_SpeedBonus"):Connect(stats)
		player.CharacterAdded:Connect(function() task.defer(stats) end)
		stats()
		player:GetAttributeChangedSignal("IsDead"):Connect(function() if player:GetAttribute("IsDead") then self:_clearOwner(player) end end)
	end
	Players.PlayerAdded:Connect(bind); for _,player in ipairs(Players:GetPlayers()) do bind(player) end
	Players.PlayerRemoving:Connect(function(player) self:_clearOwner(player); self._states[player]=nil end)
	local epoch=require(script.Parent.BiomeService):GetTiming().ShiftCount
	local elapsed=0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; if elapsed<.1 then return end; local step=elapsed; elapsed=0
		local now=os.clock(); local restoring=RS:GetAttribute("WorldRestoring"); local ended=require(script.Parent.GameStateService):IsGameOver()
		local currentEpoch=require(script.Parent.BiomeService):GetTiming().ShiftCount
		if currentEpoch~=epoch then epoch=currentEpoch; for _,player in ipairs(Players:GetPlayers()) do self:_clearOwner(player) end end
		for i=#self._fields,1,-1 do local f=self._fields[i]; if f.Until<=now or not living(f.Owner) or ended then f.Visual:Destroy(); table.remove(self._fields,i) end end
		for target,entries in pairs(self._marks) do for owner,mark in pairs(entries) do if not target.Parent or mark.Until<=now then entries[owner]=nil end end; if not next(entries) then self._marks[target]=nil end end
		for station,entries in pairs(self._overclocks) do for owner,effect in pairs(entries) do if not station.Parent or effect.Until<=now then entries[owner]=nil end end; if not next(entries) then self._overclocks[station]=nil end end
		for _,player in ipairs(Players:GetPlayers()) do
			local state=self:_state(player)
			if not restoring and not ended and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") then state.Remaining=math.max(0,state.Remaining-step) end
			player:SetAttribute("AbilityCooldownRemaining",math.ceil(state.Remaining*10)/10)
			self:_publishEffects(player)
			if not restoring and not ended and living(player) then restore(player,self:_restoration(player,"Heal","Health",now-step,now),self:_restoration(player,"Meal","Energy",now-step,now),self:_restoration(player,"Meal","Hunger",now-step,now),0) end
		end
		for i=#self._effects,1,-1 do local e=self._effects[i]; if e.Until<=now or not living(e.Owner) or e.Target.Character~=e.Character or ended then table.remove(self._effects,i) end end
	end)
end
return Service
