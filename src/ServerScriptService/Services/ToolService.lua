-- Keeps hotbar items represented by visible Tools in the Backpack/character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local Instances = require(ReplicatedStorage.Shared.ItemInstance)

local ToolService = {}
local HOTBAR_SLOTS = 6

local function isConsumable(item)
	return item and (item.Id == "WaterFlask" or item:HasTag("Food") or item:HasTag("Consumable"))
end

function ToolService:IsHoldable(itemId)
	local item = ItemDatabase:Get(itemId)
	if not item then return false end
	local definition = Instances.Definition(itemId)
	-- Armor and worn accessories still use their equipment slots. The flask is
	-- carried because its stored water is activated from the player's hand.
	if definition and (definition.Kind == "Armor" or definition.Kind == "Accessory") then
		return itemId == "WaterFlask"
	end
	return true
end

local function itemColor(item)
	if item and typeof(item.IconColor) == "Color3" then return item.IconColor end
	if item and item:HasTag("Food") then return Color3.fromRGB(193, 135, 73) end
	if item and item:HasTag("Consumable") then return Color3.fromRGB(116, 157, 112) end
	if item and item:HasTag("Structure") then return Color3.fromRGB(132, 101, 66) end
	return Color3.fromRGB(138, 126, 96)
end

local function makeFallbackTool(entry, item, definition)
	local tool = Instance.new("Tool")
	tool.Name = entry.Id
	tool.ToolTip = item and (item.Name or entry.Id) or entry.Id
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = itemColor(item)
	handle.Parent = tool

	if definition and (definition.Kind == "Tool" or definition.Kind == "Weapon") then
		handle.Size = Vector3.new(0.35, 2.8, 0.35)
		handle.Color = Color3.fromRGB(112, 91, 63)
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.2, 0.65, 0.3)
		head.Color = Color3.fromRGB(149, 165, 151)
		head.Material = Enum.Material.SmoothPlastic
		head.CanCollide = false
		head.CanTouch = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, 1.1, 0)
		head.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, head, handle
	elseif entry.Id == "Bucket" then
		handle.Size = Vector3.new(1.25, 1.15, 1.25)
		handle.Shape = Enum.PartType.Cylinder
		handle.Color = Color3.fromRGB(128, 91, 52)
		handle.Material = Enum.Material.Wood
		tool.Grip = CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, -0.25, 0)
	elseif item and item:HasTag("Food") then
		handle.Size = Vector3.new(1.05, 1.05, 1.05)
		handle.Shape = Enum.PartType.Ball
		tool.GripPos = Vector3.new(0, -0.3, 0)
	elseif isConsumable(item) then
		handle.Size = Vector3.new(0.72, 1.4, 0.72)
		handle.Material = Enum.Material.Glass
		tool.GripPos = Vector3.new(0, -0.35, 0)
	else
		handle.Size = Vector3.new(1.05, 1.05, 1.05)
		handle.Material = item and item:HasTag("Structure") and Enum.Material.Wood or Enum.Material.SmoothPlastic
	end
	return tool
end

local function inventoryKey(entry, slotIndex)
	return entry.Uid and ("uid:" .. entry.Uid) or ("slot:" .. tostring(slotIndex))
end

local function bindActivation(tool)
	if tool:GetAttribute("InventoryActivationBound") then return end
	tool:SetAttribute("InventoryActivationBound", true)
	local consumedThisPress = false
	tool.Deactivated:Connect(function() consumedThisPress = false end)
	tool.Unequipped:Connect(function() consumedThisPress = false end)
	tool.Activated:Connect(function()
		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		if tool:GetAttribute("HeldConsumable") then
			if consumedThisPress then return end
			consumedThisPress = true
		end
		-- Required lazily to avoid a module-load cycle with InventoryActionService.
		require(script.Parent.InventoryActionService):UseHeld(player, tool)
	end)
end

function ToolService:Sync(player)
	local inventory = InventoryService:GetAll(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not inventory or not backpack then return end

	local desired = {}
	for slotIndex = 1, HOTBAR_SLOTS do
		local entry = inventory.Hotbar[slotIndex]
		if entry and self:IsHoldable(entry.Id) then
			desired[inventoryKey(entry, slotIndex)] = { Entry = entry, SlotIndex = slotIndex }
		end
	end

	local existing = {}
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local key = tool:GetAttribute("InventoryKey")
					local wanted = key and desired[key]
					if not wanted or tool:GetAttribute("InventoryItemId") ~= wanted.Entry.Id or existing[key] then
						tool:Destroy()
					else
						existing[key] = tool
					end
				end
			end
		end
	end

	for key, wanted in pairs(desired) do
		local entry, slotIndex = wanted.Entry, wanted.SlotIndex
		local item = ItemDatabase:Get(entry.Id)
		local definition = Instances.Definition(entry.Id)
		local tool = existing[key]
		if not tool then
			local templates = ServerStorage:FindFirstChild("Tools")
			local template = templates and templates:FindFirstChild(entry.Id)
			tool = template and template:IsA("Tool") and template:Clone() or makeFallbackTool(entry, item, definition)
			tool.CanBeDropped = false
		end

		tool:SetAttribute("InventoryKey", key)
		tool:SetAttribute("InventorySlotIndex", slotIndex)
		tool:SetAttribute("InventoryItemId", entry.Id)
		tool:SetAttribute("GearUid", entry.Uid)
		tool:SetAttribute("GearGrade", entry.Grade)
		tool:SetAttribute("Durability", entry.Durability)
		tool:SetAttribute("MaxDurability", entry.MaxDurability)
		tool:SetAttribute("HeldConsumable", isConsumable(item) == true)

		if definition and (definition.Kind == "Tool" or definition.Kind == "Weapon") then
			tool:SetAttribute("Damage", (entry.Durability or 1) > 0 and definition.Damage or 0)
			tool:SetAttribute("Range", definition.Reach or 8)
			tool:SetAttribute("AttackSpeed", 1 / (definition.AttackCycle or 1))
			local power = definition.Power and definition.Power * (entry.Id == "Harvester" and 1 or 2 ^ ((entry.Grade or definition.Grade) - definition.Grade))
			tool:SetAttribute("ToolPower", power)
			tool:SetAttribute("MiningGrade", entry.Grade)
			tool:SetAttribute("ToolFamily", definition.ToolFamily)
			if definition.Kind == "Tool" then
				tool:SetAttribute("WeaponType", nil)
				tool:SetAttribute("ToolType", definition.ToolFamily or "Universal")
				tool:SetAttribute("CombatDamage", entry.Id == "Harvester" and 6 or 0)
				tool:SetAttribute("HarvestPower", power)
				tool:SetAttribute("CombatRange", 8)
			elseif definition.Kind == "Weapon" then
				local weaponType = definition.WeaponFamily == "Bow" and "Bow" or definition.WeaponFamily == "Staff" and "Gun" or "Sword"
				tool:SetAttribute("ToolType", nil)
				tool:SetAttribute("WeaponType", weaponType)
				for _, name in ipairs({ "Damage", "Range", "AttackSpeed", "WeaponType", "ToolType", "CombatDamage", "Ammo" }) do
					local child = tool:FindFirstChild(name)
					if child and child:IsA("ValueBase") then child:Destroy() end
				end
			end
		end
		bindActivation(tool)
		if not tool.Parent then tool.Parent = backpack end
	end
end

function ToolService:Init()
	if self._initialized then return end
	self._initialized = true
	InventoryService:OnChanged(function(player)
		ToolService:Sync(player)
	end)
	local function bindPlayer(player)
		local function syncCharacter()
			local backpack = player:WaitForChild("Backpack", 10)
			if not backpack then
				warn(string.format("[ToolService] No Backpack for %s", player.Name))
				return
			end
			ToolService:Sync(player)
		end
		player.CharacterAdded:Connect(function()
			task.defer(syncCharacter)
		end)
		task.spawn(syncCharacter)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
end

return ToolService
