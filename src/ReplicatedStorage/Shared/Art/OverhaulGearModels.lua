-- Current campaign gear: readable silhouettes, small part budgets, no imported scripts.
local Catalog = require(script.Parent.Parent.OverhaulCatalog)
local BowVisuals = require(script.Parent.Parent.Weapons.BowVisuals)
local BowRig = require(script.Parent.BowRig)
local ItemPresentation = require(script.Parent.ItemPresentation)
local PickHeadTemplate = script.Parent:WaitForChild("ForgedPickHead")
local CuttingEdges = script.Parent:WaitForChild("CuttingEdges")
local Art = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local WOOD = Color3.fromRGB(112, 84, 54)
local WRAP = Color3.fromRGB(75, 97, 77)
local BRASS = Color3.fromRGB(184, 145, 77)
local BONE = Color3.fromRGB(209, 199, 167)
local palettes = {
	{ Color3.fromRGB(126, 137, 125), Color3.fromRGB(173, 186, 155) },
	{ Color3.fromRGB(146, 164, 163), Color3.fromRGB(176, 220, 219) },
	{ Color3.fromRGB(57, 63, 72), Color3.fromRGB(223, 132, 73) },
	{ Color3.fromRGB(103, 98, 119), Color3.fromRGB(224, 179, 107) },
	{ Color3.fromRGB(76, 99, 123), Color3.fromRGB(132, 223, 235) },
	{ Color3.fromRGB(75, 102, 76), Color3.fromRGB(176, 202, 121) },
	{ Color3.fromRGB(60, 76, 88), Color3.fromRGB(109, 187, 199) },
	{ Color3.fromRGB(159, 164, 190), Color3.fromRGB(212, 196, 245) },
}

local function part(tool, name, size, cf, color, material, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	if not class and (name == "CoreGrip" or name == "Haft" or name == "Ferrule" or name == "HeadBinding"
		or name == "StaffCollar" or name == "GripEndBand" or name == "LeatherBinding" or name == "Pommel") then
		p.Shape, p.Size, p.CFrame = Enum.PartType.Cylinder, V(size.Y, size.X, size.Z), cf * A(0, 0, math.pi / 2)
	end
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = tool
	return p
end

local function beam(tool, name, from, to, width, color, material)
	return part(tool, name, V(width, (to - from).Magnitude, width),
		CFrame.lookAt((from + to) / 2, to) * A(math.pi / 2, 0, 0), color, material)
end

local function shard(tool, name, base, height, width, color, material)
	-- Two opposed wedges make a pointed, solid spear/crystal head with a central ridge.
	for side = -1, 1, 2 do
		part(tool, name, V(width * .42, height, width * .5),
			CF(base + V(0, height / 2, side * width * .25)) * A(0, side == 1 and math.pi or 0, 0),
			color, material, "WedgePart")
	end
end

local function axeHead(tool, y, color, edge, large)
	local scale = large and 1.22 or 1
	part(tool, "AxeSocket", V(.48, .5, .46), CF(0, y, 0), color, Enum.Material.Metal)
	part(tool, "AxeCheek", V(1.05 * scale, .85 * scale, .27), CF(-.5 * scale, y, 0) * A(0, 0, .08), color, Enum.Material.Metal, "WedgePart")
	part(tool, "AxeEdge", V(.21, 1.14 * scale, .18), CF(-1.03 * scale, y - .07, 0) * A(0, 0, -.1), edge, Enum.Material.Metal, "WedgePart")
	part(tool, "AxePoll", V(.4, .36, .36), CF(.38, y + .03, 0), color, Enum.Material.Metal)
end
local function forgedEdge(tool,name,template,offset,color)
	local blade=template:Clone()
	blade.Name,blade.Color,blade.Material=name,color,Enum.Material.Metal
	blade.CFrame=offset*blade.CFrame
	blade.Anchored,blade.CanCollide,blade.CanTouch,blade.CanQuery,blade.Massless=false,false,false,false,true
	blade.Parent=tool
	return blade
end

function Art.Create(id, definition)
	local def = definition or Catalog.Gear[id]
	if not def or (def.Kind ~= "Tool" and def.Kind ~= "Weapon") then return nil end
	local family = def.WeaponFamily or def.ToolFamily
	local grade = math.clamp(def.Grade or 1, 1, #palettes)
	local color, accent = palettes[grade][1], palettes[grade][2]
	local edge = color:Lerp(Color3.new(1, 1, 1), .3)
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip, tool.RequiresHandle, tool.CanBeDropped = id, Catalog.Items[id].Name, true, false
	tool:SetAttribute("ArtStyle", "Expedition")
	tool:SetAttribute("ArtVersion", 3)
	tool:SetAttribute("ArtKind", def.Kind)
	tool:SetAttribute("ArtFamily", family)
	local handle = part(tool, "Handle", V(.26, .88, .28), CF(), WOOD, Enum.Material.Wood)
	handle.Transparency = 1
	part(tool, "CoreGrip", V(.26, .88, .28), CF(), WOOD, Enum.Material.Wood)
	local long = family == "Spear" or family == "Staff"
	if family ~= "Bow" and family ~= "Dagger" and family ~= "Sword" then
		part(tool, "Haft", V(.23, long and 4.2 or 2.3, .25), CF(0, long and .6 or .5, 0), WOOD, Enum.Material.Wood)
		part(tool, "Ferrule", V(.28, .2, .3), CF(0, long and -1.4 or -.58, 0), color, Enum.Material.Metal)
	end
	if family == "Sword" or family == "Dagger" then
		local short = family == "Dagger"
		local length, width = short and 1.3 or 2.35, short and .34 or .51
		local blade = id == "BoneKnife" and BONE or color
		part(tool, "Crossguard", V(short and .64 or 1.05, .17, .34), CF(0, .52, 0), BRASS, Enum.Material.Metal)
		part(tool, "Blade", V(width, length, .14), CF(0, .65 + length / 2, 0), blade, Enum.Material.Metal)
		forgedEdge(tool,"BladePoint",short and CuttingEdges.DaggerPoint or CuttingEdges.SwordPoint,CF(0,.65+length,0),blade)
		part(tool, "SharpenedEdge", V(.04, length, .16), CF(-width / 2, .65 + length / 2, 0), edge, Enum.Material.Metal)
		part(tool, "Pommel", V(.36, .25, .35), CF(0, -.55, 0), BRASS, Enum.Material.Metal)
		if grade >= 3 then part(tool, "BladeInlay", V(.055, length * .6, .02), CF(0, .9 + length / 2, -.081), accent) end
		if id == "ThornBlade" then
			for i = 0, 2 do part(tool, "ThornBarb", V(.26, .3, .16), CF(.33, 1 + i * .55, 0) * A(0, 0, -.4), color, nil, "WedgePart") end
		end
	elseif family == "Spear" then
		shard(tool, "SpearHead", V(0, 2.6, 0), id == "MeteorPike" and 1.4 or 1.05, .55, color, Enum.Material.Metal)
		part(tool, "HeadBinding", V(.33, .3, .35), CF(0, 2.6, 0), WRAP, Enum.Material.Fabric)
		if grade >= 4 then
			for side = -1, 1, 2 do beam(tool, "WingedSocket", V(0, 2.65, 0), V(side * .45, 2.95, 0), .14, accent) end
		end
	elseif family == "Axe" then
		axeHead(tool, 1.5, color, edge, def.Kind == "Weapon")
		if id == "EmberAxe" then part(tool, "EmberChannel", V(.06, .7, .025), CF(-.65, 1.5, -.155), accent, Enum.Material.Neon) end
	elseif family == "Pickaxe" or family == "Universal" then
		part(tool, "HeadSocket", V(.46, .5, .46), CF(0, 1.5, 0), color, Enum.Material.Metal)
		-- One closed curved solid replaces disconnected shoulder/beak primitives.
		-- The saved CSG geometry needs no runtime mesh authoring or asset upload.
		local head = PickHeadTemplate:Clone()
		head.Name, head.Color, head.Material = "ForgedPickHead", color, Enum.Material.Metal
		head.CFrame = CF(0, 1.5, 0) * head.CFrame
		head.Anchored, head.CanCollide, head.CanTouch, head.CanQuery, head.Massless = false, false, false, false, true
		head.Parent = tool
		tool:SetAttribute("PickHeadArtVersion", 1)
		if id == "ExpeditionTool" then part(tool, "FieldCore", V(.22, .23, .04), CF(0, 1.5, -.243), accent, Enum.Material.Neon) end
	elseif family == "Sickle" then
		part(tool,"HookSocket",V(.33,.35,.3),CF(0,1.5,0),color,Enum.Material.Metal)
		forgedEdge(tool,"SickleEdge",CuttingEdges.SickleEdge,CF(0,1.5,0),color)
	elseif family == "Hammer" then
		part(tool, "HammerCore", V(1.6, .86, .8), CF(0, 1.6, 0), color, Enum.Material.Metal)
		for side = -1, 1, 2 do
			part(tool, "StrikingFace", V(.25, 1, .96), CF(side * .85, 1.6, 0), edge, Enum.Material.Metal)
			part(tool, "HeadBand", V(.16, .91, .84), CF(side * .5, 1.6, 0), BRASS, Enum.Material.Metal)
		end
		part(tool, "HammerSigil", V(.32, .32, .035), CF(0, 1.6, -.42) * A(0, 0, math.pi / 4), accent, grade >= 5 and Enum.Material.Neon or nil)
	elseif family == "Staff" then
		part(tool, "StaffCollar", V(.54, .25, .54), CF(0, 2.52, 0), BRASS, Enum.Material.Metal)
		if id == "LanternStaff" then
			part(tool, "LanternCap", V(.85, .17, .85), CF(0, 3.55, 0), color, Enum.Material.Metal)
			part(tool, "LanternHeart", V(.43, .65, .43), CF(0, 3.05, 0), accent, Enum.Material.Neon)
			for x = -1, 1, 2 do for z = -1, 1, 2 do part(tool, "LanternRib", V(.09, .95, .09), CF(x * .32, 3.08, z * .32), BRASS) end end
		else
			shard(tool, "StaffCrystal", V(0, 2.6, 0), 1.15, .65, accent, Enum.Material.Neon)
			for side = -1, 1, 2 do beam(tool, "CrystalFork", V(side * .2, 2.4, 0), V(side * .52, 3.25, 0), .16, id == "RootStaff" and WOOD or color) end
		end
	elseif family == "Bow" then
		local profile = BowVisuals.Profile(id, grade)
		BowRig.Create(tool, handle, WOOD, color, profile.Accent, grade)
	end
	for i = 0, 7 do
		part(tool, "LeatherBinding", V(.285, .055, .305), CF(0, -.34 + i * .098, 0) * A(0, 0, .12),
			WRAP:Lerp(Color3.fromRGB(123, 98, 60), i % 2 == 0 and .25 or .05), Enum.Material.Fabric)
	end
	for _, y in ipairs({ -.43, .45 }) do
		part(tool, "GripEndBand", V(.3, .06, .32), CF(0, y, 0), BRASS, Enum.Material.Metal)
		for side = -1, 1, 2 do
			local rivet = part(tool, "PeenedRivet", V(.07, .07, .035), CF(0, y, side * .175), edge, Enum.Material.Metal)
			rivet.Shape = Enum.PartType.Ball
		end
	end
	if family == "Sword" or family == "Dagger" then
		local length = family == "Dagger" and .9 or 1.75
		for side = -1, 1, 2 do
			part(tool, "BladeFuller", V(.07, length, .012), CF(0, 1 + length / 2, side * .077), color:Lerp(Color3.new(0, 0, 0), .3), Enum.Material.Metal)
		end
	elseif family == "Axe" or family == "Pickaxe" or family == "Hammer" or family == "Universal" then
		for side = -1, 1, 2 do
			local depth = family == "Hammer" and .42 or (family == "Pickaxe" or family == "Universal") and .238 or .25
			part(tool, "SocketPlate", V(.28, .35, .035), CF(0, 1.5, side * depth), BRASS, Enum.Material.Metal)
		end
	end
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p ~= handle and not p:FindFirstChild("BowJoint") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = handle, p, p
		end
	end
	ItemPresentation.Configure(tool)
	return tool
end

return Art
