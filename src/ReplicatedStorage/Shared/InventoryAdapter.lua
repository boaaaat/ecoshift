-- InventoryAdapter.lua
-- Adapter over InventoryService for systems expecting Provider(plr).
local RunService = game:GetService("RunService")
local InventoryService = nil
if RunService:IsServer() then
	InventoryService = require(game.ServerScriptService.Services.InventoryService)
end

local Adapter = {}

function Adapter.Provider(plr)
	if not InventoryService then
		return {
			Has = function() return false end,
			Consume = function() return false end,
			Give = function() end,
		}
	end
	return {
		Has = function(id, n) return InventoryService:Has(plr, id, n) end,
		Consume = function(id, n) return InventoryService:Consume(plr, id, n) end,
		Give = function(id, n) InventoryService:Give(plr, id, n) end,
	}
end

return Adapter
