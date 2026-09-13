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
local function configureResource(model, name)
	local id = ResourceMap.Normalize(name)
	local item = Items:Get(id)
	if not item then return false end
	local profile = LootConfig.ResourceProfile(item, name)
	-- Preserve geometry, but replace legacy child values and hold prompts so they
	-- cannot override the current balance or leave a second harvest route active.
	local markers = { Health = true, MaxHealth = true, CurrentHealth = true, Duration = true, HarvestDuration = true }
	for _, child in ipairs(model:GetDescendants()) do
		for marker in pairs(markers) do child:SetAttribute(marker, nil) end
		if child:IsA("ProximityPrompt") or child.Name == "HarvestPromptAttachment"
			or (child:IsA("ValueBase") and markers[child.Name]) then
			child:Destroy()
		end
	end
	model:SetAttribute("DropItemId", id)
	model:SetAttribute("DropMin", profile.Min)
	model:SetAttribute("DropMax", profile.Max)
	model:SetAttribute("Health", profile.Health)
	model:SetAttribute("MaxHealth", profile.Health)
	model:SetAttribute("CurrentHealth", nil)
	model:SetAttribute("Duration", profile.Duration)
	model:SetAttribute("HarvestDuration", nil)
	model:SetAttribute("HarvestProfileVersion", 2)
 model:SetAttribute("MiningGrade",profile.MiningGrade or 1)
 model:SetAttribute("ResourceKind",profile.Kind)
	model:SetAttribute("ContactDamage", id == "Cactus" and 4 or nil)
	return true
end
local function makeResource(parent, name, biome, resource)
	if keepExisting(parent, name) then
		local existing = parent:FindFirstChild(name)
		if resource and existing and existing:GetAttribute("PrefabOverride") ~= true then
			configureResource(existing, name)
		end
		return
	end
	local model = resource and ExpeditionModels.CreateResource(name, biome) or ExpeditionModels.CreateProp(name, biome)
	if not model then warn("[Art] No authored resource model:", name); return end
	if resource and not configureResource(model, name) then model:Destroy(); return end
	publish(model, parent)
end
local Catalog=require(ReplicatedStorage.Shared.OverhaulCatalog)
local function configureTool(tool,item)
 tool.Name,tool.ToolTip,tool.CanBeDropped=item.Id,item.Name,false
 local gear=Catalog.Gear[item.Id]
 for _,key in ipairs({"ToolType","WeaponType","Type","Damage","CombatDamage","Range","Cooldown","CombatRange","CombatCooldown","ToolPower","HarvestPower","MiningGrade","ToolFamily","WeaponFamily","AttackSpeed"}) do
  tool:SetAttribute(key,nil)
  local child=tool:FindFirstChild(key);if child and child:IsA("ValueBase") then child:Destroy() end
 end
 tool:SetAttribute("PlaceableItem",item:HasTag("Placeable") and true or nil)
 if item:HasTag("Placeable") then tool:SetAttribute("Damage",0);return end
 if not gear then return end
 tool:SetAttribute("GearGrade",gear.Grade);tool:SetAttribute("Damage",gear.Damage or 0)
 tool:SetAttribute("Range",gear.Reach or 8);tool:SetAttribute("Cooldown",gear.AttackCycle or .6)
 tool:SetAttribute("AttackSpeed",1/(gear.AttackCycle or .6))
 if gear.Kind=="Tool" then
  tool:SetAttribute("ToolType",gear.ToolFamily or "Universal");tool:SetAttribute("ToolFamily",gear.ToolFamily)
  tool:SetAttribute("ToolPower",gear.Power);tool:SetAttribute("HarvestPower",gear.Power);tool:SetAttribute("MiningGrade",gear.Grade)
  tool:SetAttribute("CombatDamage",gear.Damage or 0);tool:SetAttribute("CombatRange",gear.Reach or 8);tool:SetAttribute("CombatCooldown",gear.AttackCycle or .6)
 elseif gear.Kind=="Weapon" then
  tool:SetAttribute("WeaponFamily",gear.WeaponFamily)
  tool:SetAttribute("WeaponType",gear.WeaponFamily=="Bow" and "Bow" or gear.WeaponFamily=="Staff" and "Gun" or "Sword")
 end
end
local function makeTool(parent, item)
	if keepExisting(parent, item.Id) then
		local existing = parent:FindFirstChild(item.Id)
		-- Preserve generated artwork while bringing its gameplay bindings forward.
		-- Authored overrides retain their own statistics and behavior.
		if existing and existing:IsA("Tool") and existing:GetAttribute("GeneratedBy") == GENERATOR
			and existing:GetAttribute("PrefabOverride") ~= true then
			configureTool(existing, item)
		end
		return
	end
	local tool
	if item:HasTag("Placeable") then
		tool = Instance.new("Tool")
		local handle = Instance.new("Part")
		handle.Name, handle.Size = "Handle", Vector3.new(1.2, .8, 1.2)
		handle.Color, handle.Material = Color3.fromRGB(121, 104, 67), Enum.Material.Wood
		handle.CanCollide, handle.Massless, handle.Parent = false, true, tool
	else
		tool = ExpeditionModels.CreateTool(item.Id, item:HasTag("Weapon"))
	end
	if not tool then warn("[Art] No authored tool model:", item.Id); return end
	configureTool(tool, item)
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
local function makeEnemy(parent,id,def,biome)
 local existing=parent:FindFirstChild(id)
 if existing then existing:Destroy() end
 local model=require(script.Parent.Parent.Art.OverhaulCreatures).Create(id)
 if model then publish(model,parent) end
end
local function makeBuild(parent,name)
 local existing=parent:FindFirstChild(name)
 if existing and existing:GetAttribute("PrefabOverride")==true then return end
 if existing then existing:Destroy() end
 local model=require(ReplicatedStorage.Shared.Art.OverhaulBuildModels).Create(name)
 if not model then warn("[Art] No build model:",name);return end
 publish(model,parent)
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
			local drop = Config.BUILD.AllowedTypes[item.Id] and require(ReplicatedStorage.Shared.Art.OverhaulBuildModels).Create(item.Id) or FieldObjects.CreateDrop(item)
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
