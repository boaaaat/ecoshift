-- CraftingService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)

local CraftingService = {}
CraftingService._initialized = false

function CraftingService:CanCraft(plr, itemId)
	local recipe = Config.RECIPES[itemId]
	if not recipe then 
		print("[CraftingService] No recipe found for:", itemId)
		return false, "NoRecipe" 
	end
	local craftMult = tonumber(plr:GetAttribute("Role_Craft")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(recipe) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(craftMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	if not InventoryService:CanAfford(plr, adjusted) then
		print("[CraftingService] Player cannot afford recipe:", itemId)
		return false, "MissingItems"
	end
	return true
end

function CraftingService:Craft(plr, itemId)
	print(string.format("[CraftingService] %s attempting to craft: %s", plr.Name, tostring(itemId)))
	
	local ok, reason = self:CanCraft(plr, itemId)
	if not ok then 
		print("[CraftingService] Craft failed:", reason)
		return false, reason 
	end
	
	local craftMult = tonumber(plr:GetAttribute("Role_Craft")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(Config.RECIPES[itemId]) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(craftMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	
	if not InventoryService:PayCost(plr, adjusted) then
		print("[CraftingService] PayCost failed")
		return false, "ConsumeFailed"
	end
	
	local added = InventoryService:Give(plr, itemId, 1)
	print(string.format("[CraftingService] Crafted %s for %s (added: %d)", itemId, plr.Name, added))
	return true
end

function CraftingService:Init()
	if self._initialized then return end
	self._initialized = true
	
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local rCraft = Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)
	
	if rCraft then
		rCraft.OnServerEvent:Connect(function(plr, itemId)
			print(string.format("[CraftingService] Received craft request from %s for %s", plr.Name, tostring(itemId)))
			local ok, reason = self:Craft(plr, itemId)
			if not ok then
				warn(string.format("[CraftingService] Craft failed for %s: %s", plr.Name, tostring(reason)))
			end
		end)
		print("[CraftingService] Initialized - listening for craft requests")
	else
		warn("[CraftingService] Could not find Craft remote!")
	end
end

return CraftingService
