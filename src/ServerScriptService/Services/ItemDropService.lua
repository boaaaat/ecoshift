-- ItemDropService.lua
-- Spawns pickup items from ServerStorage/GameItems.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local InventoryService = require(script.Parent.InventoryService)

local ItemDropService = {}

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

local function attachPrompt(model)
	local part = model.PrimaryPart or getPrimary(model)
	if not part then return end
	model.PrimaryPart = part
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick Up"
		prompt.ObjectText = model:GetAttribute("ItemId") or model.Name
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.Parent = part
	end
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
	local itemsFolder = ServerStorage:FindFirstChild("GameItems")
	local prefab = itemsFolder and itemsFolder:FindFirstChild(itemId)
	local model
	if prefab then
		model = prefab:Clone()
	else
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 2, 2)
		part.Anchored = true
		part.Name = itemId .. "_Drop"
		model = Instance.new("Model")
		model.Name = itemId
		part.Parent = model
		model.PrimaryPart = part
	end
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Count", count)
	if model:IsA("Model") then
		model:PivotTo(CFrame.new(position))
	elseif model:IsA("BasePart") then
		model.CFrame = CFrame.new(position)
	end
	model.Parent = ensureFolder()
	attachPrompt(model)
	return model
end

return ItemDropService
