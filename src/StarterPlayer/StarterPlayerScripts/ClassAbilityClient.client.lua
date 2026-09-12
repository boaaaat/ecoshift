local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
if require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode()~="Expedition" then return end
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Theme=require(RS.Shared.UI.UITheme)
local Settings=require(RS.Shared.ClientSettings)
local Config=require(RS.Shared.ClassConfig)
local remote=RS:WaitForChild("Remotes"):WaitForChild("ClassAbility")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="ClassAbilityUI";gui.ResetOnSpawn=false;gui.DisplayOrder=24;gui.Parent=player.PlayerGui
local icons={Generalist="Survey",Gatherer="Harvest",Builder="Build",Hunter="Bow",Medic="Health",Engineer="Craft",Scout="Sprint",Cook="Food",Botanist="Leaf",Prospector="Mineral",Warden="Shield",Climatologist="Exposure"}
local trigger=Instance.new("TextButton");trigger.Name="ClassAbility";trigger.Text="";trigger.Size=UDim2.fromOffset(58,58);trigger.Parent=gui;Theme.Button(trigger);Theme.TouchIcon(trigger,"Survey",30)
local countdown=Theme.Label(trigger,"",UDim2.fromScale(1,1),UDim2.new(),18,nil,true);countdown.TextXAlignment=Enum.TextXAlignment.Center;countdown.ZIndex=5
local binding=Theme.Label(trigger,"G",UDim2.new(1,0,0,18),UDim2.new(0,0,1,3),12,nil,true);binding.TextXAlignment=Enum.TextXAlignment.Center
local ring={}
for i=1,40 do
	local angle=(i/40)*math.pi*2-math.pi/2;local segment=Instance.new("Frame");segment.BorderSizePixel=0;segment.Size=UDim2.fromOffset(3,5);segment.AnchorPoint=Vector2.new(.5,.5);segment.Position=UDim2.new(.5,math.cos(angle)*25,.5,math.sin(angle)*25);segment.Rotation=math.deg(angle)+90;segment.ZIndex=4;segment.Parent=trigger;Theme.Bind(segment,"BackgroundColor3","Amber");ring[i]=segment
end
local notice=Theme.Label(gui,"",UDim2.fromOffset(340,54),UDim2.new(.5,0,.63,0),15,nil,true);notice.AnchorPoint=Vector2.new(.5,.5);notice.TextXAlignment=Enum.TextXAlignment.Center;notice.TextWrapped=true
local choice=Instance.new("Frame");choice.Name="DeploymentChoice";choice.Size=UDim2.fromOffset(240,144);choice.AnchorPoint=Vector2.new(.5,.5);choice.Position=UDim2.fromScale(.5,.55);choice.Visible=false;choice.Parent=gui;Theme.Panel(choice);Theme.CaptureCursor(choice)
local controls=Instance.new("Frame");controls.BackgroundTransparency=1;controls.Size=UDim2.fromOffset(180,52);controls.AnchorPoint=Vector2.new(.5,1);controls.Position=UDim2.new(.5,0,1,-155);controls.Visible=false;controls.Parent=gui
local mode,rotation,previewPart,placement,valid,pending,role=nil,0,nil,nil,false,nil,nil
local noticeSerial=0
local outlines=setmetatable({},{__mode="k"})
local function tell(message)
	noticeSerial+=1;local ticket=noticeSerial;notice.Text=message or "";task.delay(4,function() if ticket==noticeSerial then notice.Text="" end end)
end
local function cancel()
	mode=nil;choice.Visible=false;controls.Visible=false;placement=nil
	if previewPart then previewPart:Destroy();previewPart=nil end
	player.PlayerGui:SetAttribute("ClassPlacementActive",false)
end
local function request(payload)
	if pending then return end
	payload.RequestId=HttpService:GenerateGUID(false);pending=payload.RequestId;remote:FireServer("Activate",payload);tell("Activating…")
	task.delay(8,function() if pending==payload.RequestId then pending=nil;tell("No confirmation received. Please try again.") end end)
end
local function choose(value)
	choice.Visible=false;mode=value;controls.Visible=true;rotation=0
	player.PlayerGui:SetAttribute("ClassPlacementActive",true)
	previewPart=Instance.new("Part");previewPart.Name="DeploymentPreview";previewPart.Size=value=="Shelter" and Vector3.new(12,10,12) or Vector3.new(4,5,4);previewPart.Anchored=true;previewPart.CanCollide=false;previewPart.CanQuery=false;previewPart.CanTouch=false;previewPart.Transparency=.7;previewPart.Material=Enum.Material.ForceField;previewPart.Parent=workspace
	tell("Choose clear ground · confirm to deploy · cancel to leave")
end
local function iconButton(parent,kind,x,callback,label)
	local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(48,48);b.Position=UDim2.fromOffset(x,0);b.Parent=parent;Theme.Button(b);Theme.TouchIcon(b,kind,28);b.Activated:Connect(callback)
	if label then local l=Theme.Label(parent,label,UDim2.fromOffset(94,24),UDim2.fromOffset(x-23,54),13,nil,true);l.TextXAlignment=Enum.TextXAlignment.Center end
	return b
end
iconButton(choice,"Attack",36,function() choose("Turret") end,"TURRET")
iconButton(choice,"Build",156,function() choose("Shelter") end,"SHELTER")
local closeChoice=Instance.new("TextButton");closeChoice.Text="CANCEL";closeChoice.Font=Enum.Font.GothamBold;closeChoice.TextSize=14;closeChoice.Position=UDim2.fromOffset(12,92);closeChoice.Size=UDim2.fromOffset(216,44);closeChoice.Parent=choice;Theme.Button(closeChoice);closeChoice.Activated:Connect(cancel)
local function confirm() if mode and placement and valid then request({Mode=mode,Position=placement,Rotation=rotation}) elseif mode then tell("Choose clear, level ground within 16 studs.") end end
iconButton(controls,"Place",0,confirm)
iconButton(controls,"Rotate",62,function() rotation=(rotation+90)%360 end)
iconButton(controls,"Close",124,cancel)
local function aimRay()
	local camera=workspace.CurrentCamera;if not camera then return end
	if Theme.IsMobile() or UIS.PreferredInput==Enum.PreferredInput.Gamepad then return camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2) end
	local mouse=UIS:GetMouseLocation();return camera:ScreenPointToRay(mouse.X,mouse.Y)
end
local function raycast()
	local ray=aimRay();if not ray then return end
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character,previewPart}
	return workspace:Raycast(ray.Origin,ray.Direction*120,params)
end
local function activate()
	if choice.Visible then cancel();return end
	if not Settings.CanInput() or player.PlayerGui:GetAttribute("MenuCursorOpen") or player.PlayerGui:GetAttribute("BuildPlacementActive") or player:GetAttribute("IsDead") then return end
	if mode then confirm();return end
	if (player:GetAttribute("ClassLevel") or 1)<3 then tell("Unlocks at class level 3");return end
	if (player:GetAttribute("AbilityCooldownRemaining") or 0)>0 then tell("Ability is recovering.");return end
	if role=="Builder" then choice.Visible=true;return end
	local payload={}
	if role=="Hunter" or role=="Engineer" then local hit=raycast();if not hit then tell(role=="Hunter" and "Aim at a visible monster." or "Aim at a crew crafting station.");return end;payload.Target=hit.Instance end
	request(payload)
end
trigger.Activated:Connect(activate)
UIS.InputBegan:Connect(function(input,processed)
	if processed then return end
	if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB or input.UserInputType==Enum.UserInputType.MouseButton2 then if mode or choice.Visible then cancel() end;return end
	if mode and input.KeyCode==Enum.KeyCode.R then rotation=(rotation+90)%360;return end
	if mode and input.UserInputType==Enum.UserInputType.MouseButton1 then confirm();return end
	if input.KeyCode==Settings.Key("Ability") or input.KeyCode==Enum.KeyCode.ButtonY then activate() end
end)
remote.OnClientEvent:Connect(function(action,data)
	if action=="ClearMarkers" and type(data)=="table" then
		for model,record in pairs(outlines) do
			for _,key in ipairs(data.Keys or {}) do record.Sources[tostring(key)]=nil end
			if not next(record.Sources) then record.Highlight:Destroy();outlines[model]=nil end
		end
	elseif action=="Markers" and type(data)=="table" then
		local key=tostring(data.Key or "scan")
		local expires=os.clock()+math.clamp(tonumber(data.Duration) or 0,0,60)
		for _,marker in ipairs(data.Markers or {}) do
			local target=marker.Target
			if marker.Kind=="Monster" and typeof(target)=="Instance" and target:IsDescendantOf(workspace) then
				local model=target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
				if model then
					local record=outlines[model]
					if not record then
						local highlight=Instance.new("Highlight");highlight.Name="ClassMarkedTarget";highlight.Adornee=model;highlight.FillColor=Color3.fromRGB(229,176,75);highlight.OutlineColor=highlight.FillColor;highlight.FillTransparency=.85;highlight.Parent=gui
						record={Highlight=highlight,Sources={}};outlines[model]=record
					end
					record.Sources[key]=math.max(record.Sources[key] or 0,expires)
				end
			end
		end
	end
	if action=="Result" and type(data)=="table" and data.RequestId==pending then
		local reasons={NotAlive="Abilities require a living explorer.",Locked="Unlocks at class level 3",Cooldown="Ability is recovering.",InvalidTarget="Aim at a valid target.",NoPlants="No eligible harvested plants nearby.",OutOfRange="Move closer to your target.",Blocked="Choose clear ground.",Unsupported="Choose level, supported ground."}
		pending=nil;tell(data.Success and "Ability activated" or reasons[data.Reason] or data.Reason or "Unable to activate here.");if data.Success then cancel() end
	end
end)
player:GetAttributeChangedSignal("IsDead"):Connect(function() if player:GetAttribute("IsDead") then cancel() end end)
player.CharacterRemoving:Connect(cancel)
local tickBudget=0
local footprintChecked=0
local footprintValid=false
RunService.RenderStepped:Connect(function(dt)
	if previewPart and mode then
		local hit=raycast();local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		valid=hit~=nil and root~=nil and hit.Normal.Y>.92 and (hit.Position-root.Position).Magnitude<=16
		if hit then placement=hit.Position;previewPart.CFrame=CFrame.new(hit.Position+Vector3.new(0,previewPart.Size.Y/2,0))*CFrame.Angles(0,math.rad(rotation),0) end
		if hit and os.clock()-footprintChecked>.1 then
			footprintChecked=os.clock();footprintValid=true
			local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character,previewPart}
			local low,high=math.huge,-math.huge
			for _,corner in ipairs({Vector3.new(-1,0,-1),Vector3.new(-1,0,1),Vector3.new(1,0,-1),Vector3.new(1,0,1)}) do
				local offset=previewPart.CFrame:VectorToWorldSpace(corner*previewPart.Size/2)
				local support=workspace:Raycast(hit.Position+offset+Vector3.new(0,4,0),Vector3.new(0,-8,0),params)
				if not support then footprintValid=false;break end
				low=math.min(low,support.Position.Y);high=math.max(high,support.Position.Y)
			end
			if high-low>2 then footprintValid=false end
			local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={previewPart};overlap.MaxParts=40
			for _,part in ipairs(workspace:GetPartBoundsInBox(previewPart.CFrame+Vector3.new(0,.2,0),previewPart.Size-Vector3.new(.2,.4,.2),overlap)) do
				if part.CanCollide or part:FindFirstAncestorOfClass("Model") and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then footprintValid=false;break end
			end
		end
		valid=valid and footprintValid
		previewPart.Color=valid and Color3.fromRGB(153,191,123) or Color3.fromRGB(225,99,82)
	end
	tickBudget+=dt;if tickBudget<.1 then return end;tickBudget=0
	for model,record in pairs(outlines) do
		for key,expires in pairs(record.Sources) do if expires<=os.clock() then record.Sources[key]=nil end end
		if not model:IsDescendantOf(workspace) or not next(record.Sources) then record.Highlight:Destroy();outlines[model]=nil end
	end
	local currentRole=player:GetAttribute("Role") or "Generalist"
	if role~=currentRole then role=currentRole;Theme.Icon(trigger,icons[role] or "Survey",30) end
	local mobile=Theme.IsMobile();trigger.AnchorPoint=Vector2.new(1,1);trigger.Position=mobile and UDim2.new(1,-100,1,-210) or UDim2.new(1,-26,1,-145)
	local menus=player.PlayerGui:GetAttribute("MenuCursorOpen")
	trigger.Visible=not player:GetAttribute("IsDead") and not menus and not player.PlayerGui:GetAttribute("BuildPlacementActive")
	if mode and menus then cancel() end
	local level=player:GetAttribute("ClassLevel") or 1;local remaining=player:GetAttribute("AbilityCooldownRemaining") or 0
	local def=Config.Definitions[role] or Config.Definitions.Generalist;local fraction=math.clamp(remaining/def.Ability.Cooldown,0,1)
	countdown.Text=pending and "…" or level<3 and "L3" or remaining>0 and tostring(math.ceil(remaining)) or ""
	local glyph=trigger:FindFirstChild("Glyph");if glyph then glyph.Visible=countdown.Text=="" end
	for i,segment in ipairs(ring) do segment.Visible=remaining>0 and i/40<=fraction end
	binding.Text=mobile and "" or UIS.PreferredInput==Enum.PreferredInput.Gamepad and "Y" or Settings.Key("Ability").Name
end)

-- Prompts display the requesting player's own harvest duration; the server validates it independently.
local watched=setmetatable({},{__mode="k"})
local function updatePrompt(prompt)
	local revive=prompt:GetAttribute("BaseReviveDuration")
	if type(revive)=="number" then
		prompt.HoldDuration=revive*math.max(.25,(1-(player:GetAttribute("Class_ReviveReduction") or 0))*(1-(player:GetAttribute("ClassReviveReduction") or 0)));return
	end
	local base=prompt:GetAttribute("BaseHarvestDuration");if type(base)~="number" then return end
	local kind=prompt:GetAttribute("ResourceKind") or (prompt.Parent and prompt.Parent:GetAttribute("ResourceKind"))
	local reduction=(player:GetAttribute("Class_GatherTimeReduction") or 0)+(player:GetAttribute("ClassHarvestReduction") or 0)
	if kind=="Plant" then reduction+=player:GetAttribute("Class_PlantTimeReduction") or 0 end
	prompt.HoldDuration=base*(1-math.clamp(reduction,0,.5))
end
local function watch(instance)
	if not instance:IsA("ProximityPrompt") or watched[instance] then return end;watched[instance]=true
	instance:GetAttributeChangedSignal("BaseReviveDuration"):Connect(function() updatePrompt(instance) end)
	instance:GetAttributeChangedSignal("BaseHarvestDuration"):Connect(function() updatePrompt(instance) end);updatePrompt(instance)
end
for _,instance in ipairs(workspace:GetDescendants()) do watch(instance) end
workspace.DescendantAdded:Connect(watch)
for _,attr in ipairs({"Class_GatherTimeReduction","Class_PlantTimeReduction","ClassHarvestReduction","Class_ReviveReduction","ClassReviveReduction"}) do player:GetAttributeChangedSignal(attr):Connect(function() for prompt in pairs(watched) do updatePrompt(prompt) end end) end
