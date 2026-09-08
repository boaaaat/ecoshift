-- DropItemService.lua
-- Allows players to drop items from inventory as world pickups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)

local DropItemService = {}

function DropItemService:Init()
	if self._initialized then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)
	if not remote then return end
	self._initialized = true
	remote.OnServerEvent:Connect(function(plr, payloadOrId, amount)
		if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring")
			or plr:GetAttribute("WorldPlayerLoading") then return end
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then return end
		local position = root.Position
		if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z or position.Magnitude == math.huge then return end
		if type(payloadOrId) == "table" then
			local payload = payloadOrId
			local slotType = payload.SlotType
			local slotIndex = payload.SlotIndex
			local dropAmount = math.floor(tonumber(payload.Amount) or 0)
			if dropAmount ~= dropAmount or dropAmount == math.huge or dropAmount <= 0 then return end
			local itemId = InventoryService:TakeFromSlot(plr, slotType, slotIndex, dropAmount)
			if not itemId then return end
			ItemDropService:SpawnDrop(itemId, dropAmount, root.Position + Vector3.new(0, 2, -4))
			return
		end
		local itemId = payloadOrId
		amount = math.floor(tonumber(amount) or 0)
		if amount ~= amount or amount == math.huge or amount <= 0 or type(itemId) ~= "string" then return end
		if not InventoryService:Has(plr, itemId, amount) then return end
		if not InventoryService:Consume(plr, itemId, amount) then return end
		ItemDropService:SpawnDrop(itemId, amount, root.Position + Vector3.new(0, 2, -4))
	end)
end

return DropItemService
