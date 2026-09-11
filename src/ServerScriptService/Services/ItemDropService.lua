-- ItemDropService.lua
-- Spawns pickup items from ServerStorage/GameItems with optional fallback cloning.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent.InventoryService)
local PromptQueueService = require(script.Parent.PromptQueueService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ResourceItemMap = require(ReplicatedStorage.Shared.ResourceItemMap)

local ItemDropService = {}

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y
		and value.Z == value.Z and value.Magnitude < math.huge
end

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
	if instance:IsA("Tool") or instance:IsA("Accessory") then
		local wrapper=Instance.new("Model")
		wrapper.Name=name
		for _,child in ipairs(instance:GetChildren()) do child.Parent=wrapper end
		instance:Destroy()
		wrapper.PrimaryPart=wrapper:FindFirstChild("Handle") or getPrimary(wrapper)
		return wrapper
	end
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

local function applyInitialVelocity(model, velocity)
	if not model or not finiteVector(velocity) then return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = velocity
		end
	end
	local primary = model.PrimaryPart or getPrimary(model)
	if primary then
		primary.AssemblyLinearVelocity = velocity
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
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.ObjectText = getPromptObjectText(itemId, count)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	local claimed = false
	prompt.Triggered:Connect(function(plr)
		if claimed or model:GetAttribute("PickupPending") or ReplicatedStorage:GetAttribute("WorldRestoring") or not model:IsDescendantOf(Workspace) then return end
		if plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") then return end
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not root or plr:GetAttribute("IsDead") then return end
		if not ((root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 0.5) then return end
		local id = ResourceItemMap.Normalize(model:GetAttribute("ItemId"))
		local count = model:GetAttribute("Count") or 1
		if type(id) ~= "string" or not ItemDatabase:Get(id) then return end
		if typeof(count) ~= "number" or count % 1 ~= 0 or count <= 0 or count == math.huge then return end
		claimed = true
		local added = InventoryService:Give(plr, id, count, true)
		if added > 0 then
			model:Destroy()
		else
			claimed = false
		end
	end)
end

function ItemDropService:SpawnDrop(itemId, count, position, options)
	itemId = ResourceItemMap.Normalize(itemId)
	if type(itemId) ~= "string" or not ItemDatabase:Get(itemId) or not finiteVector(position) then return nil end
	count = tonumber(count) or 1
	if count ~= count or count <= 0 or count == math.huge then return nil end
	count = math.max(1, math.floor(count))
	if type(options) ~= "table" then options = nil end
	local itemsFolder = ServerStorage:FindFirstChild("GameItems")
	local prefab = itemsFolder and itemsFolder:FindFirstChild(itemId)
	local dropsFolder=ServerStorage:FindFirstChild("ItemDropPrefabs")
	local toolsFolder=ServerStorage:FindFirstChild("Tools")
	prefab=prefab or (dropsFolder and dropsFolder:FindFirstChild(itemId)) or (toolsFolder and toolsFolder:FindFirstChild(itemId))
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
	-- Held tools/armor intentionally have no collisions, and small resource art
	-- has very thin pieces. Every pickup needs its own solid physics body.
	local pivot = model:GetPivot()
	local bounds, size = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "PickupCollider"
	root.Size = Vector3.new(math.max(.75, size.X), math.max(.75, size.Y), math.max(.75, size.Z))
	root.CFrame = bounds
	root.PivotOffset = bounds:ToObjectSpace(pivot)
	root.Transparency, root.CanCollide, root.CanTouch = 1, true, false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root
	do
		for _,p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanTouch=false
				if p~=root then
					p.CanCollide=false
					p.Massless=true
					local weld=Instance.new("WeldConstraint"); weld.Part0,weld.Part1,weld.Parent=root,p,p
				end
			elseif p:IsA("Script") or p:IsA("LocalScript") or p:IsA("ProximityPrompt") then p:Destroy() end
		end
	end
	setAnchoredRecursive(model, false)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Count", count)
	if options and options.PendingPickup then model:SetAttribute("PickupPending", true) end
	model:PivotTo(CFrame.new(position))
	model.Parent = ensureFolder()
	if root then pcall(function() root:SetNetworkOwner(nil) end) end
	applyInitialVelocity(model, options and options.InitialVelocity)
	PromptQueueService:Enqueue(function()
		attachPrompt(model)
	end)
	return model
end

function ItemDropService:CaptureWorldState()
	local codec, result = require(script.Parent.WorldSnapshotCodec), {}
	local folder = Workspace:FindFirstChild("ItemDrops")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:IsA("Model") and model:GetAttribute("ItemId") and not model:GetAttribute("PickupPending") then
			assert(#result < codec.MaxDrops, "Ground drop snapshot capacity exceeded; refusing partial save")
			table.insert(result, { Id = model:GetAttribute("ItemId"), N = model:GetAttribute("Count"), Transform = codec.CFrame(model:GetPivot()) })
		end
	end
	return result
end

function ItemDropService:RestoreWorldState(states)
	local codec = require(script.Parent.WorldSnapshotCodec)
	assert(type(states) == "table" and #states <= codec.MaxDrops, "Invalid ground drop snapshot")
	for _, state in ipairs(states) do
		assert(ItemDatabase:Get(state.Id), "Unknown saved ground item")
		local count = codec.Number(state.N, 1, 1e8)
		assert(count % 1 == 0, "Invalid saved ground count")
		codec.ReadCFrame(state.Transform)
	end
	ensureFolder():ClearAllChildren()
	for _, state in ipairs(states) do
		local transform = codec.ReadCFrame(state.Transform)
		local model = assert(self:SpawnDrop(state.Id, state.N, transform.Position), "Could not restore ground drop")
		model:PivotTo(transform)
		-- Terrain is generated in Tier3; prevent drops falling before it exists.
		setAnchoredRecursive(model, true)
		model:SetAttribute("SnapshotDropFrozen", true)
	end
end

function ItemDropService:CompleteWorldRestore()
	for _, model in ipairs(ensureFolder():GetChildren()) do
		if model:GetAttribute("SnapshotDropFrozen") then
			setAnchoredRecursive(model, false)
			model:SetAttribute("SnapshotDropFrozen", nil)
		end
	end
end

return ItemDropService
