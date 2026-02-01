-- ItemDatabase.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Item)

local ItemDatabase = {}

local raw = {
	-- Resources
	{ Id = "Wood", Name = "Wood", StackSize = 99, Tags = { "Resource", "Organic" } },
	{ Id = "Stone", Name = "Stone", StackSize = 99, Tags = { "Resource", "Mineral" } },
	{ Id = "Reed", Name = "Reed", StackSize = 99, Tags = { "Resource", "Plant" } },
	{ Id = "Coal", Name = "Coal", StackSize = 99, Tags = { "Resource", "Fuel" } },
	{ Id = "IronOre", Name = "Iron Ore", StackSize = 99, Tags = { "Resource", "Ore" } },
	{ Id = "GoldOre", Name = "Gold Ore", StackSize = 99, Tags = { "Resource", "Ore" } },
	{ Id = "Diamond", Name = "Diamond", StackSize = 99, Tags = { "Resource", "Gem" } },
	{ Id = "Crystal", Name = "Crystal", StackSize = 99, Tags = { "Resource", "Gem" } },
	{ Id = "Sand", Name = "Sand", StackSize = 99, Tags = { "Resource", "Mineral" } },
	{ Id = "RawMeat", Name = "Raw Meat", StackSize = 20, Tags = { "Resource", "Food" } },
	{ Id = "RawHide", Name = "Raw Hide", StackSize = 50, Tags = { "Resource", "Organic" } },
	
	-- Processed Materials
	{ Id = "Stick", Name = "Stick", StackSize = 99, Tags = { "Material" } },
	{ Id = "Plank", Name = "Plank", StackSize = 99, Tags = { "Material" } },
	{ Id = "IronIngot", Name = "Iron Ingot", StackSize = 99, Tags = { "Material", "Metal" } },
	{ Id = "GoldIngot", Name = "Gold Ingot", StackSize = 99, Tags = { "Material", "Metal" } },
	{ Id = "Glass", Name = "Glass", StackSize = 99, Tags = { "Material" } },
	{ Id = "Cloth", Name = "Cloth", StackSize = 50, Tags = { "Material" } },
	{ Id = "Leather", Name = "Leather", StackSize = 50, Tags = { "Material" } },
	
	-- Food
	{ Id = "CookedMeat", Name = "Cooked Meat", StackSize = 20, Tags = { "Consumable", "Food" } },
	{ Id = "Meal_Stew", Name = "Stew", StackSize = 20, Tags = { "Consumable" } },
	
	-- Ammo
	{ Id = "Arrow", Name = "Arrow", StackSize = 99, Tags = { "Ammo" } },
	
	-- Tools - Basic
	{ Id = "Harvester", Name = "Harvester", StackSize = 1, Tags = { "Tool" } },
	{ Id = "StoneHatchet", Name = "Stone Hatchet", StackSize = 1, Tags = { "Tool" } },
	{ Id = "StonePickaxe", Name = "Stone Pickaxe", StackSize = 1, Tags = { "Tool" } },
	
	-- Tools - Iron
	{ Id = "IronHatchet", Name = "Iron Hatchet", StackSize = 1, Tags = { "Tool" } },
	{ Id = "IronPickaxe", Name = "Iron Pickaxe", StackSize = 1, Tags = { "Tool" } },
	
	-- Tools - Diamond
	{ Id = "DiamondPickaxe", Name = "Diamond Pickaxe", StackSize = 1, Tags = { "Tool" } },
	
	-- Weapons - Basic
	{ Id = "Sword", Name = "Sword", StackSize = 1, Tags = {"Weapon"}},
	{ Id = "WoodenSword", Name = "Wooden Sword", StackSize = 1, Tags = { "Weapon" } },
	{ Id = "Bow", Name = "Bow", StackSize = 1, Tags = { "Weapon" } },
	
	-- Weapons - Iron
	{ Id = "IronSword", Name = "Iron Sword", StackSize = 1, Tags = { "Weapon" } },
	{ Id = "Shield", Name = "Shield", StackSize = 1, Tags = { "Weapon" } },
	
	-- Weapons - Diamond/Endgame
	{ Id = "DiamondSword", Name = "Diamond Sword", StackSize = 1, Tags = { "Weapon" } },
	{ Id = "EnchantedBow", Name = "Enchanted Bow", StackSize = 1, Tags = { "Weapon" } },
	
	-- Armor
	{ Id = "ClothSet", Name = "Cloth Set", StackSize = 1, Tags = { "Armor" } },
	{ Id = "LeatherArmor", Name = "Leather Armor", StackSize = 1, Tags = { "Armor" } },
	{ Id = "IronArmor", Name = "Iron Armor", StackSize = 1, Tags = { "Armor" } },
	{ Id = "DiamondArmor", Name = "Diamond Armor", StackSize = 1, Tags = { "Armor" } },
	
	-- Utility Items
	{ Id = "Torch", Name = "Torch", StackSize = 99, Tags = { "Placeable", "Utility" } },
	
	-- Crafting Stations (Placeable)
	{ Id = "Workbench", Name = "Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "AdvancedWorkbench", Name = "Advanced Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "MasterWorkbench", Name = "Master Workbench", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Furnace", Name = "Furnace", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Anvil", Name = "Anvil", StackSize = 1, Tags = { "Placeable", "Station" } },
	{ Id = "Loom", Name = "Loom", StackSize = 1, Tags = { "Placeable", "Station" } },
	
	-- Structures (Placeable)
	{ Id = "Campfire", Name = "Campfire", StackSize = 1, Tags = { "Placeable", "Utility" } },
	{ Id = "Chest", Name = "Chest", StackSize = 1, Tags = { "Placeable", "Storage" } },
}

-- OPTIMIZED: Pre-build lookup table for O(1) access
local rawLookup = {}
for _, def in ipairs(raw) do
	rawLookup[def.Id] = def
end

local cache = {}
-- OPTIMIZED: Cache ItemIcons folder reference
local _itemIconsFolder = nil
local function getItemIconsFolder()
	if _itemIconsFolder == nil then
		_itemIconsFolder = ReplicatedStorage:FindFirstChild("ItemIcons") or false
	end
	return _itemIconsFolder
end

local function resolveIcon(def)
	if def.Icon and def.Icon ~= "" then
		return def.Icon
	end
	local folder = getItemIconsFolder()
	if not folder then return nil end
	local node = folder:FindFirstChild(def.Id)
	if not node then return nil end
	if node:IsA("StringValue") then
		return node.Value
	end
	if node:IsA("ImageLabel") or node:IsA("ImageButton") then
		return node.Image
	end
	if node:IsA("Decal") or node:IsA("Texture") then
		return node.Texture
	end
	local attr = node:GetAttribute("Icon") or node:GetAttribute("Image")
	if type(attr) == "string" then
		return attr
	end
	return nil
end

function ItemDatabase:Get(id)
	if not id then return nil end
	if cache[id] then return cache[id] end
	-- OPTIMIZED: O(1) lookup instead of O(n) iteration
	local def = rawLookup[id]
	if def then
		local icon = resolveIcon(def)
		local item = Item.new({
			Id = def.Id,
			Name = def.Name,
			StackSize = def.StackSize,
			Tags = def.Tags,
			Icon = icon,
			IconColor = def.IconColor,
		})
		cache[id] = item
		return item
	end
	return nil
end

function ItemDatabase:All()
	local list = {}
	for _, def in ipairs(raw) do
		list[#list + 1] = Item.new({
			Id = def.Id,
			Name = def.Name,
			StackSize = def.StackSize,
			Tags = def.Tags,
			Icon = resolveIcon(def),
			IconColor = def.IconColor,
		})
	end
	return list
end

function ItemDatabase:Define(def)
	if type(def) ~= "table" or not def.Id then return end
	raw[#raw + 1] = def
	rawLookup[def.Id] = def -- OPTIMIZED: Update lookup table
	cache[def.Id] = nil
end

return ItemDatabase
