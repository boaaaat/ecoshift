-- ToolService.lua
-- Syncs inventory tool items to player Backpack/Character.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(game:GetService("ReplicatedStorage").Shared.Items.ItemDatabase)

local ToolService = {}
local HOTBAR_SLOTS = 4

local function isHoldable(itemId)
	local item = ItemDatabase:Get(itemId)
	return item and item:HasTag("Holdable") or false
end

local function collectHoldableIds(inv)
	local set = {}
	for i = 1, HOTBAR_SLOTS do
		local slot = inv.Hotbar and inv.Hotbar[i]
		if slot and isHoldable(slot.Id) then
			set[slot.Id] = true
		end
	end
	return set
end

local function ensureTool(plr, itemId)
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild(itemId) or (plr.Character and plr.Character:FindFirstChild(itemId)) then
		return
	end
	local toolsFolder = ServerStorage:FindFirstChild("Tools")
	local template = toolsFolder and toolsFolder:FindFirstChild(itemId)
	if template and template:IsA("Tool") then
		local tool = template:Clone()
		-- Inventory owns item drops; native Backspace drops would duplicate items.
		tool.CanBeDropped = false
		tool.Parent = backpack
		print(string.format("[ToolService] Added tool %s to %s", itemId, plr.Name))
	else
		warn(string.format("[ToolService] Missing tool template for %s", itemId))
	end
end

local function removeTool(plr, itemId)
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if backpack then
		local t = backpack:FindFirstChild(itemId)
		if t then t:Destroy() end
	end
	if plr.Character then
		local t = plr.Character:FindFirstChild(itemId)
		if t then t:Destroy() end
	end
end

function ToolService:Sync(plr)
	local inv = InventoryService:GetAll(plr)
	if not inv then return end
	local desired = collectHoldableIds(inv)
	print(string.format("[ToolService] Sync %s holdables: %s", plr.Name, table.concat((function()
		local list = {}
		for id in pairs(desired) do list[#list + 1] = id end
		return list
	end)(), ", ")))
	-- add missing
	for itemId in pairs(desired) do
		ensureTool(plr, itemId)
	end
	-- remove extras
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and not desired[tool.Name] then
				tool:Destroy()
			end
		end
	end
	if plr.Character then
		for _, tool in ipairs(plr.Character:GetChildren()) do
			if tool:IsA("Tool") and not desired[tool.Name] then
				tool:Destroy()
			end
		end
	end
end

function ToolService:Init()
	if self._initialized then return end
	self._initialized = true
	InventoryService:OnChanged(function(plr)
		ToolService:Sync(plr)
	end)
	local function bindPlayer(plr)
		local function syncCharacter()
			local backpack = plr:WaitForChild("Backpack", 10)
			if not backpack then
				warn(string.format("[ToolService] No Backpack for %s", plr.Name))
				return
			end
			ToolService:Sync(plr)
		end
		plr.CharacterAdded:Connect(function()
			task.defer(syncCharacter)
		end)
		task.spawn(syncCharacter)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		bindPlayer(plr)
	end
end

return ToolService
