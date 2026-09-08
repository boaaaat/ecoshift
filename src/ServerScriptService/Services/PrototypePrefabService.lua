-- Original expedition art with gameplay bindings. Explicit prefab overrides win.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Biomes = require(ReplicatedStorage.Shared.BiomeConfig)
local Items = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ResourceMap = require(ReplicatedStorage.Shared.ResourceItemMap)
local Config = require(ReplicatedStorage.Shared.Config)
local Entities = require(script.Parent.Parent.AI.EntityConfig)
local ExpeditionModels = require(script.Parent.Parent.Art.ExpeditionModels)
local ExpeditionEquipment = require(script.Parent.Parent.Art.ExpeditionEquipment)
local FieldObjects = require(script.Parent.Parent.Art.ExpeditionFieldObjects)
local LootConfig = require(ReplicatedStorage.Shared.ExpeditionLootConfig)
local Service = {}

local GENERATOR = "ExpeditionPrefabService"
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
local function keepExisting(parent, name)
	local existing = parent:FindFirstChild(name)
	if not existing then return false end
	if existing:GetAttribute("PrefabOverride") == true then return true end
	-- Replace only known generated placeholders; unmarked authored prefabs survive.
	if existing:GetAttribute("ArtStyle") == "Expedition" and existing:GetAttribute("ArtVersion") == 1 then return true end
	if existing:GetAttribute("PrototypePrefab") or existing:GetAttribute("GeneratedBy") == GENERATOR then
		existing:Destroy()
		return false
	end
	return true
end
local function publish(model, parent)
	model:SetAttribute("GeneratedBy", GENERATOR)
	model.Parent = parent
end
local function entries(list, callback)
	for key, value in pairs(list or {}) do
		local name = type(key) == "string" and key or (type(value) == "string" and value or value.Name or value.name)
		if name then callback(name) end
	end
end
local function makeResource(parent, name, biome, resource)
	if keepExisting(parent, name) then return end
	local model = resource and ExpeditionModels.CreateResource(name, biome) or ExpeditionModels.CreateProp(name, biome)
	if not model then warn("[Art] No authored resource model:", name); return end
	if resource then
		local id = ResourceMap.Normalize(name)
		if not Items:Get(id) then model:Destroy(); return end
		model:SetAttribute("DropItemId", id)
		local profile = LootConfig.ResourceProfile(Items:Get(id))
		model:SetAttribute("DropMin", profile.Min)
		model:SetAttribute("DropMax", profile.Max)
		if profile.Health then
			model:SetAttribute("Health", profile.Health)
			model:SetAttribute("MaxHealth", profile.Health)
		else
			model:SetAttribute("Duration", profile.Duration)
		end
	end
	publish(model, parent)
end
local toolPower = { Harvester = 20, StoneHatchet = 30, StonePickaxe = 30, SanditePickaxe = 45,
	MireSickle = 45, CryoPickaxe = 60, ObsidianAxe = 75, PhaseMultitool = 100 }
local weaponPower = { StoneSpear = 18, BoneSpear = 18, SanditeBlade = 27, MireDagger = 23, FrostLance = 38,
	MagmaHammer = 50, CrystalBow = 44, VoidEdge = 65, MeteorPike = 82 }
local function makeTool(parent, item)
	if keepExisting(parent, item.Id) then return end
	local tool = ExpeditionModels.CreateTool(item.Id, item:HasTag("Weapon"))
	if not tool then warn("[Art] No authored tool model:", item.Id); return end
	tool.Name, tool.ToolTip, tool.CanBeDropped = item.Id, item.Name, false
	if item:HasTag("Tool") then
		tool:SetAttribute("ToolType", "Universal")
		tool:SetAttribute("Damage", toolPower[item.Id] or 20)
		tool:SetAttribute("Range", 10)
	else
		tool:SetAttribute("WeaponType", item.Id == "CrystalBow" and "Bow" or "Sword")
		tool:SetAttribute("Damage", weaponPower[item.Id] or 20)
		tool:SetAttribute("Range", item.Id == "CrystalBow" and 180 or 9)
	end
	tool:SetAttribute("Cooldown", 0.6)
	publish(tool, parent)
end
local function authoredBounds(model)
	-- Measure in authored ground axes, independently of the first wedge's rotation.
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local corner = p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x, y, z) * 0.5)
				low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
				high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
			end end end
		end
	end
	return (low + high) * 0.5, high - low
end
local function makeEnemy(parent, id, def, biome)
	if keepExisting(parent, id) then return end
	local model = ExpeditionEquipment.CreateCreature(id, biome)
	if not model then warn("[Art] No authored creature model:", id); return end
	local center, size = authoredBounds(model)
	-- A compact central collider avoids catching antlers, tails and outstretched legs.
	local rootSize = Vector3.new(math.clamp(size.X * 0.55, 0.7, 3), math.clamp(size.Y * 0.55, 0.6, 3.4), math.clamp(size.Z * 0.55, 0.8, 3.6))
	local root = part(model, "HumanoidRootPart", rootSize, CFrame.new(center), Color3.fromRGB(47, 49, 56))
	root.Transparency = 1
	root.CastShadow = false
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide = false, p == root
			if p ~= root then
				p.Massless, p.CanTouch = true, false
				local w = Instance.new("WeldConstraint"); w.Part0, w.Part1, w.Parent = root, p, p
			end
		end
	end
	model.PrimaryPart = root
	-- The physical root follows the model bounds, while placement keeps ground Y=0.
	root.PivotOffset = root.CFrame:Inverse()
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = def.Health or 85
	hum.Health = hum.MaxHealth
	hum.HipHeight, hum.RequiresNeck = math.max(0, center.Y - rootSize.Y * 0.5), false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model:SetAttribute("EntityId", id)
	model:SetAttribute("EntityType", def.Type or "Monster")
	model:SetAttribute("ArtWidth", size.X)
	model:SetAttribute("ArtHeight", size.Y)
	model:SetAttribute("ArtDepth", size.Z)
	publish(model, parent)
end
local function makeBuild(parent, name)
	if keepExisting(parent, name) then return end
	local model = ExpeditionEquipment.CreateBuild(name)
	if not model then warn("[Art] No authored build model:", name); return end
	if name == "Torch" then
		local light = Instance.new("PointLight")
		light.Name, light.Brightness, light.Range = "TorchLight", 2, 16
		light.Color, light.Shadows = Color3.fromRGB(255, 214, 138), true
		light.Parent = model:FindFirstChild("FlameFacet") or model.PrimaryPart
	end
	publish(model, parent)
end
local function makeArmor(parent, item)
	if keepExisting(parent, item.Id) then return end
	local accessory = ExpeditionEquipment.CreateArmor(item.Id)
	if not accessory then warn("[Art] No authored armor model:", item.Id); return end
	-- ArmorService already mounts GameItems accessories and reapplies resistance stats.
	publish(accessory, parent)
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
		local structures = folder(folder(ServerStorage,"StructurePrefabs"),biome)
		entries(data.structures,function(name)
			if not keepExisting(structures,name) then
				local site=FieldObjects.CreateStructure(name,biome)
				if site then publish(site,structures) end
			else
				local site=structures:FindFirstChild(name)
				if site and site:GetAttribute("GeneratedBy")==GENERATOR and site:GetAttribute("PrefabOverride")~=true then
					FieldObjects.EnsureStructureChestSpawn(site)
				end
			end
		end)
		for id, def in pairs(Entities.Entities) do
			if def.Spawn and def.Spawn.Biomes and def.Spawn.Biomes[biome] then makeEnemy(folder(enemies, biome), id, def, biome) end
		end
	end
	local tools = folder(ServerStorage, "Tools")
	local gameItems = folder(ServerStorage, "GameItems")
	local drops = folder(ServerStorage,"ItemDropPrefabs")
	for _, item in ipairs(Items:All()) do
		if item:HasTag("Holdable") then makeTool(tools, item) end
		if item:HasTag("Armor") then makeArmor(gameItems, item) end
		if not item:HasTag("Holdable") and not item:HasTag("Armor") and not keepExisting(drops,item.Id) then
			local drop = Config.BUILD.AllowedTypes[item.Id] and ExpeditionEquipment.CreateBuild(item.Id) or FieldObjects.CreateDrop(item)
			if Config.BUILD.AllowedTypes[item.Id] then drop:ScaleTo(.2) end
			publish(drop,drops)
		end
	end
	local builds = folder(ServerStorage, "BuildPrefabs")
	for name in pairs(Config.BUILD.AllowedTypes) do makeBuild(builds, name) end
	local chests=folder(ServerStorage,"Chests")
	for _,name in ipairs({"Common_Chest","Rare_Chest"}) do
		if not keepExisting(chests,name) then
			local chest=FieldObjects.CreateChest(name,"Forest")
			chest:SetAttribute("ChestTier",name=="Rare_Chest" and 2 or 1)
			chest:SetAttribute("LootTable","ForestSupplies")
			game:GetService("CollectionService"):AddTag(chest,name)
			publish(chest,chests)
		end
	end
	print("[PrototypePrefabService] Original expedition resources, props, tools, creatures, builds and armor ready")
end
return Service
