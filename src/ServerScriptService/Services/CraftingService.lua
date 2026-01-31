-- CraftingService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InventoryService = require(script.Parent.InventoryService)

local CraftingService = {}

function CraftingService:CanCraft(plr, itemId)
	local recipe = Config.RECIPES[itemId]
	if not recipe then return false, "NoRecipe" end
	local craftMult = tonumber(plr:GetAttribute("Role_Craft")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(recipe) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(craftMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	if not InventoryService:CanAfford(plr, adjusted) then
		return false, "MissingItems"
	end
	return true
end

function CraftingService:Craft(plr, itemId)
	local ok, reason = self:CanCraft(plr, itemId)
	if not ok then return false, reason end
	local craftMult = tonumber(plr:GetAttribute("Role_Craft")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(Config.RECIPES[itemId]) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(craftMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	if not InventoryService:PayCost(plr, adjusted) then
		return false, "ConsumeFailed"
	end
	InventoryService:Give(plr, itemId, 1)
	return true
end

return CraftingService
