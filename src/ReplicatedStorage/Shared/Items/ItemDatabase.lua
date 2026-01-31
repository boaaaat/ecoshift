-- ItemDatabase.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Item)

local ItemDatabase = {}

local raw = {
	{ Id = "Wood", Name = "Wood", StackSize = 99, Tags = { "Resource", "Organic" } },
	{ Id = "Stone", Name = "Stone", StackSize = 99, Tags = { "Resource", "Mineral" } },
	{ Id = "Reed", Name = "Reed", StackSize = 99, Tags = { "Resource", "Plant" } },
	{ Id = "Mushroom", Name = "Mushroom", StackSize = 10, Tags = {"Resource", "Plant"}},
	{ Id = "Arrow", Name = "Arrow", StackSize = 99, Tags = { "Ammo" } },
	{ Id = "Harvester", Name = "Harvester", StackSize = 1, Tags = { "Tool" } },
	{ Id = "StoneHatchet", Name = "Stone Hatchet", StackSize = 1, Tags = { "Tool" } },
	{ Id = "Bow", Name = "Bow", StackSize = 1, Tags = { "Weapon" } },
	{ Id = "Campfire", Name = "Campfire", StackSize = 1, Tags = { "Placeable", "Utility" } },
	{ Id = "ClothSet", Name = "Cloth Set", StackSize = 1, Tags = { "Armor" } },
	{ Id = "Meal_Stew", Name = "Stew", StackSize = 20, Tags = { "Consumable" } },
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
