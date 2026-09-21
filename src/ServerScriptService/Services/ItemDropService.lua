-- ItemDropService.lua
-- Spawns pickup items from ServerStorage/GameItems with optional fallback cloning.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local ResourceItemMap = require(ReplicatedStorage.Shared.ResourceItemMap)

local ItemInstance = require(ReplicatedStorage.Shared.ItemInstance)
local ItemDropService = { _worldActive = false }
-- Own live drops until they are removed. Parenting an Instance to Workspace
-- does not keep its Luau wrapper alive in a weak-key table: GC can otherwise
-- erase the pickup entry while the physical item is still on the ground.
local entries = {}
local lifetimes = {}
local claiming = {}
local shiftAnchors = {}
local DROP_LIFETIME_SECONDS = 10 * 60
local AUTO_PICKUP_RADIUS = 4

local function forgetDrop(model)
	entries[model], lifetimes[model], claiming[model], shiftAnchors[model] = nil, nil, nil, nil
end

local function withinPickupRange(root, collider)
	-- Large or rotated drops can keep the avatar outside a center-based radius.
	-- Measure from the lower torso to the nearest point on the actual collider.
	local origin = root.Position - Vector3.new(0, root.Size.Y * .5, 0)
	local point = collider.CFrame:PointToObjectSpace(origin)
	local half = collider.Size * .5
	local nearest = Vector3.new(
		math.clamp(point.X, -half.X, half.X),
		math.clamp(point.Y, -half.Y, half.Y),
		math.clamp(point.Z, -half.Z, half.Z)
	)
	return (point - nearest).Magnitude <= AUTO_PICKUP_RADIUS
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y
		and value.Z == value.Z and value.Magnitude < math.huge
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

local function tryAutoPickup(model, plr)
	if not model or not model.Parent or claiming[model] then return false end
	local part = model.PrimaryPart or getPrimary(model)
	if not part then return false end
	model.PrimaryPart = part
	if model:GetAttribute("PickupPending") or ReplicatedStorage:GetAttribute("WorldRestoring") or not model:IsDescendantOf(Workspace) then return false end
	if plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") then return false end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root or plr:GetAttribute("IsDead") then return false end
	if not withinPickupRange(root, part) then return false end
	local id = ResourceItemMap.Normalize(model:GetAttribute("ItemId"))
	local count = model:GetAttribute("Count") or 1
	if type(id) ~= "string" or not ItemDatabase:Get(id) then return false end
	if typeof(count) ~= "number" or count % 1 ~= 0 or count <= 0 or count == math.huge then return false end
	claiming[model] = true
	local entry = ItemInstance.Copy(entries[model] or {Id=id,N=count})
	entry.N = count
	-- Commit inventory and ground count together, before Sync callbacks can yield.
	-- A nearly full pack should collect what fits without losing the remainder.
	local added = InventoryService:GiveEntry(plr, entry, false, true)
	if added > 0 then
		local remaining = count - added
		if remaining > 0 then
			entry.N = remaining
			entries[model] = entry
			model:SetAttribute("Count", remaining)
		else
			forgetDrop(model)
			model:Destroy()
		end
		claiming[model] = nil
		return true
	end
	claiming[model] = nil
	return false
end

local function freezeForBiomeShift(model)
	if not model or not model.Parent or shiftAnchors[model] then return end
	local states = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			states[part] = part.Anchored
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	shiftAnchors[model] = states
	model:SetAttribute("BiomeShiftDropFrozen", true)
end

local function restoreShiftAnchors(model)
	local states = shiftAnchors[model]
	if not states then return end
	for part, anchored in pairs(states) do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = anchored
		end
	end
	shiftAnchors[model] = nil
	model:SetAttribute("BiomeShiftDropFrozen", nil)
end

local function settleOnTerrain(model, world)
	if not model or not model.Parent or not world then return false end
	local pivot = model:GetPivot()
	local expectedY = world:GetHeight(pivot.Position.X, pivot.Position.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {Workspace.Terrain}
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(pivot.Position.X, expectedY + 32, pivot.Position.Z), Vector3.new(0, -72, 0), params)
	local surfaceY = hit and hit.Position.Y or expectedY
	local bounds, size = model:GetBoundingBox()
	local bottomY = bounds.Position.Y - size.Y * .5
	local targetBottomY = surfaceY + .18
	model:PivotTo(CFrame.new(pivot.Position + Vector3.new(0, targetBottomY - bottomY, 0)) * pivot.Rotation)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	return hit ~= nil
end

function ItemDropService:SpawnDrop(itemId, count, position, options)
	itemId = ResourceItemMap.Normalize(itemId)
	if type(itemId) ~= "string" or not ItemDatabase:Get(itemId) or not finiteVector(position) then return nil end
	count = tonumber(count) or 1
	if count ~= count or count <= 0 or count == math.huge then return nil end
	count = math.max(1, math.floor(count))
 if count>1 and ItemInstance.Definition(itemId) then
  if options and options.Entry and options.Entry.Uid then return nil end
  local first
  for i=1,count do local drop=self:SpawnDrop(itemId,1,position+Vector3.new((i-1)%3,0,math.floor((i-1)/3)),options);first=first or drop end
  return first
 end
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
	model.Destroying:Connect(function() forgetDrop(model) end)
	entries[model] = ItemInstance.New(itemId,count,options and options.Entry)
	lifetimes[model] = math.clamp(tonumber(options and options.LifetimeRemaining) or DROP_LIFETIME_SECONDS, 0, DROP_LIFETIME_SECONDS)
	if options and options.PendingPickup then model:SetAttribute("PickupPending", true) end
	model:PivotTo(CFrame.new(position))
	model.Parent = ensureFolder()
	if root then pcall(function() root:SetNetworkOwner(nil) end) end
	applyInitialVelocity(model, options and options.InitialVelocity)
	if ReplicatedStorage:GetAttribute("WorldShifting") then freezeForBiomeShift(model) end
	return model
end

function ItemDropService:BeginBiomeShift()
	for _, model in ipairs(ensureFolder():GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("ItemId") then freezeForBiomeShift(model) end
	end
end

function ItemDropService:CompleteBiomeShift(world)
	self._surfaceProvider = world
	for model in pairs(shiftAnchors) do
		if not model.Parent then
			shiftAnchors[model] = nil
		elseif settleOnTerrain(model, world) then
			restoreShiftAnchors(model)
		end
	end
end

function ItemDropService:CaptureWorldState()
	local codec, result = require(script.Parent.WorldSnapshotCodec), {}
	local folder = Workspace:FindFirstChild("ItemDrops")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:IsA("Model") and model:GetAttribute("ItemId") and not model:GetAttribute("PickupPending") then
			assert(#result < codec.MaxDrops, "Ground drop snapshot capacity exceeded; refusing partial save")
			local remaining = math.clamp(tonumber(lifetimes[model]) or DROP_LIFETIME_SECONDS, 0, DROP_LIFETIME_SECONDS)
			if remaining > 0 then
				table.insert(result, { Id = model:GetAttribute("ItemId"), N = model:GetAttribute("Count"), Entry = ItemInstance.Copy(entries[model]),
					Transform = codec.CFrame(model:GetPivot()), LifetimeRemaining = remaining })
			end
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
		if state.LifetimeRemaining ~= nil then codec.Number(state.LifetimeRemaining, 0, DROP_LIFETIME_SECONDS) end
	end
	ensureFolder():ClearAllChildren()
	for _, state in ipairs(states) do
		local remaining = state.LifetimeRemaining == nil and DROP_LIFETIME_SECONDS or state.LifetimeRemaining
		if remaining <= 0 then continue end
		local transform = codec.ReadCFrame(state.Transform)
		local model = assert(self:SpawnDrop(state.Id, state.N, transform.Position, {Entry=state.Entry, LifetimeRemaining=remaining}), "Could not restore ground drop")
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
	self._worldActive = true
end

local lifetimeAccumulator = 0
local pickupAccumulator = 0
RunService.Heartbeat:Connect(function(delta)
	if not ItemDropService._worldActive or ReplicatedStorage:GetAttribute("WorldRestoring") or ReplicatedStorage:GetAttribute("WorldShifting") then return end
	pickupAccumulator += delta
	if pickupAccumulator >= 0.15 then
		pickupAccumulator = 0
		for model in pairs(shiftAnchors) do
			if not model.Parent then
				shiftAnchors[model] = nil
			elseif settleOnTerrain(model, ItemDropService._surfaceProvider) then
				restoreShiftAnchors(model)
			end
		end
		local players = Players:GetPlayers()
		local collected = {}
		for model in pairs(entries) do
			if not model.Parent then
				forgetDrop(model)
			elseif not model:GetAttribute("PickupPending") then
				for _, plr in ipairs(players) do
					if tryAutoPickup(model, plr) then collected[plr] = true; break end
				end
			end
		end
		-- One update per collector, after every claimed drop has been settled.
		for plr in pairs(collected) do
			if plr.Parent == Players then InventoryService:Sync(plr) end
		end
	end
	lifetimeAccumulator += delta
	if lifetimeAccumulator < 1 then return end
	local elapsed = lifetimeAccumulator
	lifetimeAccumulator = 0
	for model, remaining in pairs(lifetimes) do
		if not model.Parent then
			forgetDrop(model)
		elseif not model:GetAttribute("PickupPending") then
			remaining -= elapsed
			if remaining <= 0 then
				lifetimes[model] = nil
				model:Destroy()
			else
				lifetimes[model] = remaining
			end
		end
	end
end)

return ItemDropService
