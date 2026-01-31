-- DropItemService.lua
-- Allows players to drop items from inventory as world pickups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)

local DropItemService = {}

function DropItemService:Init()
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)
	if not remote then return end
	remote.OnServerEvent:Connect(function(plr, payloadOrId, amount)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		if type(payloadOrId) == "table" then
			local payload = payloadOrId
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			local dropAmount = math.floor(tonumber(payload.Amount) or 0)
			if dropAmount <= 0 then return end
			local itemId = InventoryService:TakeFromSlot(plr, slotType, slotIndex, dropAmount)
			if not itemId then return end
			ItemDropService:SpawnDrop(itemId, dropAmount, root.Position + Vector3.new(0, 2, -4))
			return
		end
		local itemId = payloadOrId
		amount = math.floor(tonumber(amount) or 0)
		if amount <= 0 or type(itemId) ~= "string" then return end
		if not InventoryService:Has(plr, itemId, amount) then return end
		InventoryService:Consume(plr, itemId, amount)
		ItemDropService:SpawnDrop(itemId, amount, root.Position + Vector3.new(0, 2, -4))
	end)
end

return DropItemService
