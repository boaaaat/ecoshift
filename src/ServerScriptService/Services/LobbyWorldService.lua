-- The expedition observatory: a walkable, original low-poly preparation camp.
local Lighting=game:GetService("Lighting")
local Service={}
local C={Stone=Color3.fromRGB(42,54,52),Edge=Color3.fromRGB(64,83,71),Wood=Color3.fromRGB(95,72,48),
	Moss=Color3.fromRGB(59,87,66),Brass=Color3.fromRGB(180,140,69),Glow=Color3.fromRGB(123,212,186),Paper=Color3.fromRGB(232,223,192)}
local function part(parent,name,size,cf,color,material,shape)
	local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf; p.Anchored=true
	p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
	if shape then p.Shape=shape end
	p.Parent=parent; return p
end
local function sign(parent,text,position)
	local p=part(parent,"Sign",Vector3.new(16,4,.6),CFrame.new(position),C.Wood)
	local gui=Instance.new("SurfaceGui"); gui.Face=Enum.NormalId.Back; gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud=35; gui.Parent=p
	local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1; label.Text=text; label.TextColor3=C.Paper; label.TextSize=38; label.Font=Enum.Font.GothamBold; label.Parent=gui
	return p
end
function Service:Init()
	if workspace:FindFirstChild("ExpeditionObservatory") then return end
	local root=Instance.new("Model"); root.Name="ExpeditionObservatory"; root.Parent=workspace
	part(root,"Island",Vector3.new(10,148,148),CFrame.new(0,-6,0)*CFrame.Angles(0,0,math.pi/2),C.Stone,Enum.Material.Slate,Enum.PartType.Cylinder)
	part(root,"CampFoundation",Vector3.new(130,2,130),CFrame.new(0,-1,0),C.Stone,Enum.Material.Slate)
	for i=0,7 do
		local a=i*math.pi/4
		local cf=CFrame.new(math.sin(a)*44,0,math.cos(a)*44)*CFrame.Angles(0,a,0)
		part(root,"Walkway",Vector3.new(17,.3,39),cf,C.Edge)
		part(root,"Boundary",Vector3.new(18,3,2),cf*CFrame.new(0,1,19),C.Wood,Enum.Material.Wood)
		for _,side in ipairs({-1,1}) do
			part(root,"BrassPost",Vector3.new(.8,7,.8),cf*CFrame.new(side*7,3,15),C.Brass,Enum.Material.Metal)
			local lamp=part(root,"Lantern",Vector3.new(1.6,2,1.6),cf*CFrame.new(side*7,7,15),C.Glow,Enum.Material.Neon)
			local light=Instance.new("PointLight"); light.Color=C.Glow; light.Brightness=.6; light.Range=24; light.Parent=lamp
		end
	end
	part(root,"InstrumentBase",Vector3.new(18,3,18),CFrame.new(0,1,0),C.Edge)
	for i=0,11 do
		local a=i*math.pi/6
		part(root,"CompassTick",Vector3.new(.35,.15,i%3==0 and 4 or 2),CFrame.new(math.sin(a)*12,.2,math.cos(a)*12)*CFrame.Angles(0,a,0),C.Brass,Enum.Material.Metal)
	end
	local core=part(root,"ShiftCrystal",Vector3.new(4,8,4),CFrame.new(0,8,0)*CFrame.Angles(0,math.pi/4,math.pi/8),C.Glow,Enum.Material.Neon)
	local light=Instance.new("PointLight"); light.Color=C.Glow; light.Brightness=1; light.Range=32; light.Parent=core
	for _,entry in ipairs({{"CLASS QUARTERMASTER",Vector3.new(-35,7,-32),"Classes"},{"EXPEDITION TABLE",Vector3.new(0,7,-48),"Party"},{"WORLD ARCHIVE",Vector3.new(35,7,-32),"Saves"}}) do
		local position=entry[2]
		part(root,"Desk",Vector3.new(18,1.2,8),CFrame.new(position.X,3,position.Z+3),C.Wood,Enum.Material.Wood)
		for _,x in ipairs({-7,7}) do part(root,"DeskLeg",Vector3.new(1,3,5),CFrame.new(position.X+x,1.5,position.Z+3),C.Edge) end
		local board=sign(root,entry[1],position)
		local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Open"; prompt.ObjectText=entry[1]; prompt.KeyboardKeyCode=Enum.KeyCode.F; prompt.HoldDuration=0; prompt.MaxActivationDistance=16; prompt.RequiresLineOfSight=false; prompt.Parent=board
		prompt.Triggered:Connect(function(player) player:SetAttribute("LobbyPanel",entry[3]); player:SetAttribute("LobbyPanelVersion",(player:GetAttribute("LobbyPanelVersion") or 0)+1) end)
	end
	for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("SpawnLocation") then v.Enabled=false end end
	local Art=require(script.Parent.Parent.Art.ExpeditionModels)
	local Objects=require(script.Parent.Parent.Art.ExpeditionFieldObjects)
	local Items=require(game.ReplicatedStorage.Shared.Items.ItemDatabase)
	-- A map table, working instruments and archive drawers make each desk legible
	-- in the world as well as through its corresponding UI section.
	part(root,"ExpeditionMap",Vector3.new(12,.06,5.5),CFrame.new(0,3.65,-45),C.Paper)
	for i=-2,2 do
		part(root,"MapContour",Vector3.new(1.6,.03,3.5),CFrame.new(i*2,3.7,-45)*CFrame.Angles(0,i*.3,0),C.Moss)
		part(root,"CrewMarker",Vector3.new(.25,.4,.25),CFrame.new(i*1.4,3.9,-44),C.Brass)
	end
	for _,entry in ipairs({{"FieldClock",-35,-29},{"ResourceCompass",-31,-29},{"ReviveKit",-39,-29},{"BiomePredictor",32,-29},{"EventSeismograph",38,-29}}) do
		local item=Objects.CreateDrop(Items:Get(entry[1])); item:PivotTo(CFrame.new(entry[2],3.65,entry[3])); item.Parent=root
	end
	for i=1,5 do
		local cache=Objects.CreateChest("Common_Chest","Forest"); cache:ScaleTo(.8)
		cache:PivotTo(CFrame.new(27+i*2.7,.05,-39)); cache.Parent=root
	end
	for i=0,11 do
		local angle=i*math.pi/6
		if i~=0 and i~=5 and i~=6 and i~=7 then
			local tree=Art.CreateResource("SmallTree","Forest")
			if tree then tree:PivotTo(CFrame.new(math.sin(angle)*58,0,math.cos(angle)*58)); tree.Parent=root end
		end
	end
	local spawn=Instance.new("SpawnLocation"); spawn.Name="LobbyArrival"; spawn.Size=Vector3.new(10,1,10); spawn.CFrame=CFrame.new(0,.5,35); spawn.Anchored=true; spawn.Transparency=1; spawn.Neutral=true; spawn.Duration=0; spawn.Parent=root
	Lighting.ClockTime=17.5; Lighting.Brightness=2; Lighting.Ambient=Color3.fromRGB(91,107,110); Lighting.OutdoorAmbient=Color3.fromRGB(103,121,125)
	local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere"); atmosphere.Density=.25; atmosphere.Color=Color3.fromRGB(153,177,176); atmosphere.Parent=Lighting
end
return Service
