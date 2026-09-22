-- DropItemService.lua
-- Allows players to drop items from inventory as world pickups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)

local DropItemService = {}

local function canDrop(plr)
	return not ReplicatedStorage:GetAttribute("WorldRestoring") and not plr:GetAttribute("WorldPlayerRestoring")
		and not plr:GetAttribute("WorldPlayerLoading") and not plr:GetAttribute("IsDead")
end

local function createThenTake(plr, root, itemId, amount, take, entry)
	-- Preparation may fail. Keep inventory intact and the pickup unclaimable
	-- until the matching debit commits without yielding to inventory callbacks.
	local ok, drop = pcall(function()
		local forward = root.CFrame.LookVector
		return ItemDropService:SpawnDrop(itemId, amount, root.Position + forward * 4 + Vector3.new(0, 2, 0), {
			PendingPickup = true,
			Entry = entry,
			InitialVelocity = forward * 8 + Vector3.new(0, 5, 0),
			OwnerPickupBlockedUserId = plr.UserId,
			OwnerPickupCooldown = 2,
		})
	end)
	if not ok or not drop then return false end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not canDrop(plr) or not hum or hum.Health <= 0 or root.Parent ~= plr.Character or not drop.Parent or not take() then
		drop:Destroy()
		return false
	end
	drop:SetAttribute("PickupPending", nil)
	InventoryService:Sync(plr)
	return true
end

function DropItemService:Init()
	if self._initialized then return end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local remote = Util.GetRemote(remotesFolder, Config.RemoteNames.DropItem)
	if not remote then return end
	self._initialized = true
	remote.OnServerEvent:Connect(function(plr, payloadOrId, amount)
		if not canDrop(plr) then return end
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
			local slot = InventoryService:PeekSlot(plr, slotType, slotIndex)
			if not slot or slot.N < dropAmount then return end
			if payload.ExpectedId ~= nil and payload.ExpectedId ~= slot.Id then return end
			createThenTake(plr, root, slot.Id, dropAmount, function()
				return InventoryService:TakeFromSlot(plr, slotType, slotIndex, dropAmount, {ExpectedId = slot.Id, DeferSync = true}) ~= nil
			end, slot)
			return
		end
		-- Dropping requires an exact slot, including identity and installed modules.
	end)
end

return DropItemService
