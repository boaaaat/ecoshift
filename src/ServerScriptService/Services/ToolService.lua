-- Keeps hotbar items represented by visible Tools in the Backpack/character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local Instances = require(ReplicatedStorage.Shared.ItemInstance)
local GearModels = require(ReplicatedStorage.Shared.Art.OverhaulGearModels)
local ItemPresentation = require(ReplicatedStorage.Shared.Art.ItemPresentation)

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
	if definition and (definition.Kind == "Tool" or definition.Kind == "Weapon") then
		return GearModels.Create(entry.Id, definition)
	end
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

	if entry.Id == "Bucket" then
		handle.Size = Vector3.new(.75, .13, .18)
		handle.Color = Color3.fromRGB(128, 91, 52)
		handle.Material = Enum.Material.Wood
		local function detail(name, size, frame, color, material)
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, frame, color, material
			p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.Parent = false, false, false, true, tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = handle, p, p
		end
		for i = 0, 9 do
			local frame = CFrame.Angles(0, i * math.pi / 5, 0)
			detail("BucketStave", Vector3.new(.35, .92, .12), frame * CFrame.new(0, -.98, .51),
				handle.Color:Lerp(Color3.fromRGB(166, 127, 76), i % 3 * .13), Enum.Material.Wood)
			for _, y in ipairs({ -.62, -1.28 }) do
				detail("IronHoop", Vector3.new(.37, .08, .055), frame * CFrame.new(0, y, .59), Color3.fromRGB(85, 91, 87), Enum.Material.Metal)
			end
		end
		for side = -1, 1, 2 do
			detail("HandleHanger", Vector3.new(.075, .62, .1), CFrame.new(side * .39, -.3, 0), Color3.fromRGB(96, 99, 92), Enum.Material.Metal)
		end
		detail("BucketBase", Vector3.new(.87, .08, .87), CFrame.new(0, -1.41, 0), handle.Color, Enum.Material.Wood)
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
	local grip = Instance.new("Attachment")
	grip.Name, grip.Parent = "ItemGrip", handle
	return tool
end

local function inventoryKey(entry, slotIndex)
	return entry.Uid and ("uid:" .. entry.Uid) or ("slot:" .. tostring(slotIndex))
end

-- One construction path for inventory tools and editor-side asset inspection.
function ToolService:CreateTool(entry)
	local item = ItemDatabase:Get(entry.Id)
	local definition = Instances.Definition(entry.Id)
	local templates = ServerStorage:FindFirstChild("Tools")
	local template = templates and templates:FindFirstChild(entry.Id)
	local tool = template and template:IsA("Tool") and template:Clone() or makeFallbackTool(entry, item, definition)
	tool.CanBeDropped = false
	tool:SetAttribute("InventoryItemId", entry.Id)
	ItemPresentation.Configure(tool)
	return tool
end

local function bindActivation(tool)
	if tool:GetAttribute("InventoryActivationBound") then return end
	tool:SetAttribute("InventoryActivationBound", true)
	tool.Equipped:Connect(function()
		-- Roblox initially creates RightGrip for every Tool. Move bows to the lead
		-- hand on the server too, keeping their assembly attached during replication.
		if ItemPresentation.Family(tool) ~= "Bow" then return end
		task.defer(function()
			local character = tool.Parent
			local hand = character and (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"))
			local handle = tool:FindFirstChild("Handle")
			if not hand or not handle then return end
			for _, joint in ipairs(character:GetDescendants()) do
				if joint:IsA("JointInstance") and joint.Name == "RightGrip" and joint.Part1 == handle then
					local attachment = hand:FindFirstChild("LeftGripAttachment")
					joint.Part0 = hand
					joint.C0 = attachment and attachment.CFrame or CFrame.new(0, -hand.Size.Y * .5, 0)
					return
				end
			end
		end)
	end)
	local consumedThisPress = false
	tool.Deactivated:Connect(function() consumedThisPress = false end)
	tool.Unequipped:Connect(function()
		consumedThisPress = false
		tool:SetAttribute("BowDrawStarted", nil)
	end)
	tool.Activated:Connect(function()
		local character = tool.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		if tool:GetAttribute("HeldConsumable") then
			if consumedThisPress then return end
			consumedThisPress = true
			ItemPresentation.Action(tool, "Use")
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
			tool = self:CreateTool(entry)
		end

		tool:SetAttribute("InventoryKey", key)
		tool:SetAttribute("InventorySlotIndex", slotIndex)
		tool:SetAttribute("InventoryItemId", entry.Id)
		tool:SetAttribute("GearUid", entry.Uid)
		tool:SetAttribute("GearGrade", entry.Grade)
		tool:SetAttribute("Durability", entry.Durability)
		tool:SetAttribute("MaxDurability", entry.MaxDurability)
		tool:SetAttribute("HeldConsumable", isConsumable(item) == true)
		ItemPresentation.Configure(tool)

		if definition and (definition.Kind == "Tool" or definition.Kind == "Weapon") then
			tool:SetAttribute("Damage", (entry.Durability or 1) > 0 and definition.Damage or 0)
			tool:SetAttribute("Range", definition.Reach or 8)
			tool:SetAttribute("Cooldown", definition.AttackCycle or 0.6)
			tool:SetAttribute("AttackSpeed", 1 / (definition.AttackCycle or 1))
			local power = definition.Power and definition.Power * (entry.Id == "Harvester" and 1 or 2 ^ ((entry.Grade or definition.Grade) - definition.Grade))
			tool:SetAttribute("ToolPower", power)
			tool:SetAttribute("MiningGrade", entry.Grade)
			tool:SetAttribute("ToolFamily", definition.ToolFamily)
			tool:SetAttribute("WeaponFamily", definition.WeaponFamily)
			if definition.Kind == "Tool" then
				tool:SetAttribute("WeaponType", nil)
				tool:SetAttribute("ToolType", definition.ToolFamily or "Universal")
				tool:SetAttribute("CombatDamage", entry.Id == "Harvester" and 6 or 0)
				tool:SetAttribute("HarvestPower", power)
				tool:SetAttribute("CombatRange", 8)
				tool:SetAttribute("CombatCooldown", definition.AttackCycle or 0.6)
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
