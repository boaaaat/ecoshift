-- Replaceable, geometry-only test art. Authored prefabs always take precedence.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Biomes = require(ReplicatedStorage.Shared.BiomeConfig)
local Items = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ResourceMap = require(ReplicatedStorage.Shared.ResourceItemMap)
local Config = require(ReplicatedStorage.Shared.Config)
local Entities = require(script.Parent.Parent.AI.EntityConfig)
local Visuals = require(ServerStorage:WaitForChild("PrototypeVisuals"))
local Service = {}

local colors = {
	Forest = Color3.fromRGB(102, 138, 78), Desert = Color3.fromRGB(202, 161, 92),
	Swamp = Color3.fromRGB(107, 133, 94), FrozenTundra = Color3.fromRGB(142, 203, 217),
	Volcanic = Color3.fromRGB(192, 102, 71), CrystalWastes = Color3.fromRGB(163, 139, 217),
}
local function folder(parent, name)
	local result = parent:FindFirstChild(name)
	if not result then result = Instance.new("Folder"); result.Name = name; result.Parent = parent end
	return result
end
local function part(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
local function visual(name, kind, scale, tint)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("PrototypePrefab", true)
	for _, d in ipairs(Visuals[kind] or Visuals.Rock) do
		local size = Vector3.new(unpack(d.size)) * scale
		local cf = CFrame.new(unpack(d.cf))
		cf = CFrame.new(cf.Position * scale) * cf.Rotation
		local p = part(model, d.name, size, cf, tint or Color3.new(unpack(d.color)))
		if d.mesh then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId, mesh.TextureId = d.mesh, d.texture or ""
			local original = Vector3.new(unpack(d.meshSize))
			mesh.Scale = size / original
			mesh.Parent = p
		end
		model.PrimaryPart = model.PrimaryPart or p
	end
	-- Base pivot lets world generation place the visual on the terrain surface.
	model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:Inverse()
	return model
end
local function kindFor(name)
	local n = name:lower()
	if n:find("tree") or n:find("wood") then return "Tree", 0.85 end
	if n:find("log") or n:find("bone") or n:find("bark") then return "Log", 0.45 end
	if n:find("mushroom") or n:find("cap") then return "Mushroom", 0.9 end
	if n:find("reed") or n:find("fiber") or n:find("grass") or n:find("root") then return "Grass", 1 end
	if n:find("bush") or n:find("flower") or n:find("bloom") or n:find("lichen") or n:find("cactus") then return "Bush", 0.55 end
	return "Rock", 0.55
end
local function entries(list, callback)
	for key, value in pairs(list or {}) do
		local name = type(key) == "string" and key or (type(value) == "string" and value or value.Name or value.name)
		if name then callback(name) end
	end
end
local function makeResource(parent, name, biome, resource)
	if parent:FindFirstChild(name) then return end
	local kind, scale = kindFor(name)
	local tint = biome ~= "Forest" and colors[biome] or nil
	local model = visual(name, kind, scale, tint)
	local override = (Biomes.asset_overrides or {})[name]
	if override and override.yOffset then
		local offset = Instance.new("NumberValue"); offset.Name = "Offset"; offset.Value = -override.yOffset; offset.Parent = model
	end
	if resource then
		local id = ResourceMap.Normalize(name)
		if not Items:Get(id) then model:Destroy(); return end
		model:SetAttribute("DropItemId", id)
		model:SetAttribute("DropMin", 3)
		model:SetAttribute("DropMax", 5)
		if kind == "Tree" or kind == "Rock" or kind == "Log" then
			model:SetAttribute("Health", 60)
			model:SetAttribute("MaxHealth", 60)
		else
			model:SetAttribute("Duration", 1)
		end
	end
	model.Parent = parent
end
local toolPower = { Harvester = 20, StoneHatchet = 30, StonePickaxe = 30, SanditePickaxe = 45,
	MireSickle = 45, CryoPickaxe = 60, ObsidianAxe = 75, PhaseMultitool = 100 }
local weaponPower = { StoneSpear = 18, BoneSpear = 18, SanditeBlade = 27, MireDagger = 23, FrostLance = 38,
	MagmaHammer = 50, CrystalBow = 44, VoidEdge = 65 }
local function makeTool(parent, item)
	if parent:FindFirstChild(item.Id) then return end
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip, tool.CanBeDropped = item.Id, item.Name, false
	local art
	if item:HasTag("Tool") then
		art = visual("Art", "Pickaxe", 1.35)
		tool:SetAttribute("ToolType", "Universal")
		tool:SetAttribute("Damage", toolPower[item.Id] or 20)
		tool:SetAttribute("Range", 10)
	else
		art = Instance.new("Model")
		local h = part(art, "Handle", Vector3.new(0.3, 1.2, 0.3), CFrame.new(), Color3.fromRGB(92, 72, 49))
		part(art, "Blade", Vector3.new(0.4, 3, 0.15), CFrame.new(0, 1.8, 0), Color3.fromRGB(197, 208, 191))
		art.PrimaryPart = h
		tool:SetAttribute("WeaponType", item.Id == "CrystalBow" and "Bow" or "Sword")
		tool:SetAttribute("Damage", weaponPower[item.Id] or 20)
		tool:SetAttribute("Range", item.Id == "CrystalBow" and 180 or 9)
	end
	local handle = art:FindFirstChild("Handle", true) or art.PrimaryPart
	handle.Name = "Handle"
	for _, p in ipairs(art:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.Massless = false, false, true
			p.PivotOffset = CFrame.identity
			if p ~= handle then local w = Instance.new("WeldConstraint"); w.Part0, w.Part1, w.Parent = handle, p, p end
			p.Parent = tool
		end
	end
	art:Destroy()
	tool:SetAttribute("Cooldown", 0.6)
	tool.Parent = parent
end
local function makeEnemy(parent, id, def, biome)
	if parent:FindFirstChild(id) then return end
	local boss = id == "LavaGolem" or id == "VoidSentinel"
	local model = visual(id, "Wolf", boss and 0.45 or 0.22, colors[biome])
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 3), CFrame.new(0, 2, 0), colors[biome])
	root.Transparency = 1
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide = false, p == root
			if p ~= root then
				p.Massless = true
				local w = Instance.new("WeldConstraint"); w.Part0, w.Part1, w.Parent = root, p, p
			end
		end
	end
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = boss and 350 or 85
	hum.Health = hum.MaxHealth
	hum.HipHeight, hum.RequiresNeck = 1, false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model:SetAttribute("EntityId", id)
	model:SetAttribute("EntityType", def.Type or "Monster")
	model.Parent = parent
end
local function makeBuild(parent, name)
	if parent:FindFirstChild(name) or name == "Torch" then return end
	local model = Instance.new("Model"); model.Name = name
	model:SetAttribute("PrototypePrefab", true)
	local top = part(model, "Surface", Vector3.new(5, 0.5, 3), CFrame.new(0, 2.75, 0), Color3.fromRGB(140, 109, 73))
	for _, x in ipairs({-2, 2}) do for _, z in ipairs({-1, 1}) do
		part(model, "Leg", Vector3.new(0.4, 2.5, 0.4), CFrame.new(x, 1.25, z), Color3.fromRGB(73, 85, 65))
	end end
	if name:find("Chest") then
		part(model, "Crate", Vector3.new(4.6, 2, 2.6), CFrame.new(0, 1.5, 0), Color3.fromRGB(115, 91, 64))
	end
	model.PrimaryPart = top; top.PivotOffset = top.CFrame:Inverse()
	model.Parent = parent
end
function Service:Init()
	if self._initialized then return end
	self._initialized = true
	local resources, props = folder(ServerStorage, "ResourcePrefabs"), folder(ServerStorage, "PropPrefabs")
	local enemies = folder(ServerStorage, "EnemyPrefabs")
	for biome, data in pairs(Biomes.biomes) do
		local r, p = folder(resources, biome), folder(props, biome)
		local function addRegion(region)
			entries(region.resources, function(name) makeResource(r, name, biome, true) end)
			entries(region.props, function(name) makeResource(p, name, biome, false) end)
		end
		addRegion(data)
		for _, region in ipairs(data.regions or {}) do addRegion(region) end
		for id, def in pairs(Entities.Entities) do
			if def.Spawn and def.Spawn.Biomes and def.Spawn.Biomes[biome] then makeEnemy(folder(enemies, biome), id, def, biome) end
		end
	end
	local tools = folder(ServerStorage, "Tools")
	for _, item in ipairs(Items:All()) do if item:HasTag("Holdable") then makeTool(tools, item) end end
	local builds = folder(ServerStorage, "BuildPrefabs")
	for name in pairs(Config.BUILD.AllowedTypes) do makeBuild(builds, name) end
	print("[PrototypePrefabService] Temporary resource, tool, creature and station art ready")
end
return Service
