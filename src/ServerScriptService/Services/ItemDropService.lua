-- ItemDropService.lua
-- Spawns pickup items from ServerStorage/GameItems with optional fallback cloning.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent.InventoryService)
local PromptQueueService = require(script.Parent.PromptQueueService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)

local ItemDropService = {}

local function getPromptObjectText(itemId, count)
	local item = ItemDatabase:Get(itemId)
	local itemName = (item and item.Name) or itemId or "Item"
	local qty = math.max(1, math.floor(tonumber(count) or 1))
	return string.format("%dx %s", qty, itemName)
end

local function ensureFolder()
	local folder = Workspace:FindFirstChild("ItemDrops")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ItemDrops"
		folder.Parent = Workspace
	end
	return folder
end

local function getPrimary(model)
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function toModel(instance, name)
	if instance:IsA("Model") then
		if not instance.PrimaryPart then
			local primary = getPrimary(instance)
			if primary then
				instance.PrimaryPart = primary
			end
		end
		return instance
	end
	if instance:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = name
		instance.Parent = model
		model.PrimaryPart = instance
		return model
	end
	return nil
end

local function stripPrompts(instance)
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
end

local function setAnchoredRecursive(instance, anchored)
	if instance:IsA("BasePart") then
		instance.Anchored = anchored
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

local function cloneFallbackResourceModel(sourceModel, itemId, dropScale)
	if typeof(sourceModel) ~= "Instance" then return nil end
	if not sourceModel:IsA("Model") and not sourceModel:IsA("BasePart") then return nil end

	local clone = sourceModel:Clone()
	local model = toModel(clone, itemId)
	if not model then return nil end

	stripPrompts(model)

	local scale = tonumber(dropScale)
	if scale and scale > 0 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end

	model.Name = itemId
	return model
end

local function attachPrompt(model)
	if not model or not model.Parent then return end
	local part = model.PrimaryPart or getPrimary(model)
	if not part then return end
	model.PrimaryPart = part
	local itemId = model:GetAttribute("ItemId") or model.Name
	local count = model:GetAttribute("Count") or 1
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = part
	end
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = getPromptObjectText(itemId, count)
	prompt.RequiresLineOfSight = true
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Triggered:Connect(function(plr)
		local id = model:GetAttribute("ItemId")
		local count = model:GetAttribute("Count") or 1
		if not id then return end
		local added = InventoryService:Give(plr, id, count, true)
		if added > 0 then
			model:Destroy()
		end
	end)
end

function ItemDropService:SpawnDrop(itemId, count, position)
	count = math.max(1, math.floor(tonumber(count) or 1))
	local itemsFolder = ServerStorage:FindFirstChild("GameItems")
	local prefab = itemsFolder and itemsFolder:FindFirstChild(itemId)
	local fallbackModel = options and options.FallbackModel
	local fallbackScale = options and options.DropScale
	local model
	if prefab then
		model = toModel(prefab:Clone(), itemId)
	elseif fallbackModel and fallbackScale ~= nil then
		model = cloneFallbackResourceModel(fallbackModel, itemId, fallbackScale)
	end
	if not model then
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 2, 2)
		part.Anchored = false
		part.Name = itemId .. "_Drop"
		model = Instance.new("Model")
		model.Name = itemId
		part.Parent = model
		model.PrimaryPart = part
	end
	setAnchoredRecursive(model, false)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Count", count)
	model:PivotTo(CFrame.new(position))
	model.Parent = ensureFolder()
	PromptQueueService:Enqueue(function()
		attachPrompt(model)
	end)
	return model
end

return ItemDropService
