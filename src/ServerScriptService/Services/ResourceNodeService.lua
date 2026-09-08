-- ResourceNodeService.lua
-- Adds prompts for duration-based resources.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryService = require(script.Parent.InventoryService)
local PromptQueueService = require(script.Parent.PromptQueueService)
local ResourceItemMap = require(ReplicatedStorage.Shared.ResourceItemMap)

local ResourceNodeService = {}
ResourceNodeService._bound = setmetatable({}, { __mode = "k" }) -- [Instance] = true
ResourceNodeService._promptOwners = setmetatable({}, { __mode = "k" })
ResourceNodeService._attachedCount = 0
ResourceNodeService._lastReport = 0

local function getPromptAnchor(instance)
	if instance:IsA("BasePart") then
		local y = instance.Position.Y - (instance.Size.Y * 0.5) + math.min(2, instance.Size.Y * 0.5)
		return instance, Vector3.new(instance.Position.X, y, instance.Position.Z)
	end
	if not instance:IsA("Model") then
		return nil, nil
	end

	local parts = {}
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[#parts + 1] = d
		end
	end
	if #parts == 0 then
		return nil, nil
	end

	local boundsCf, boundsSize = instance:GetBoundingBox()
	local center = boundsCf.Position
	local targetY = (center.Y - boundsSize.Y * 0.5) + math.clamp(boundsSize.Y * 0.2, 1.5, 3)
	local targetPoint = Vector3.new(center.X, targetY, center.Z)

	local bestPart = nil
	local bestWorldPoint = nil
	local bestDist = math.huge

	for _, part in ipairs(parts) do
		local worldPoint = part.Position
		local ok, closest = pcall(part.GetClosestPointOnSurface, part, targetPoint)
		if ok and typeof(closest) == "Vector3" then
			worldPoint = closest
		end
		local dist = (worldPoint - targetPoint).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestPart = part
			bestWorldPoint = worldPoint
		end
	end

	return bestPart, bestWorldPoint
end

local function getValueObject(instance, name)
	local obj = instance:FindFirstChild(name, true)
	if obj and obj:IsA("ValueBase") then
		return obj.Value
	end
	return nil
end

local function getAttr(instance, name)
	local v = instance:GetAttribute(name)
	if v ~= nil then return v end
	local vv = getValueObject(instance, name)
	if vv ~= nil then return vv end
	if instance:IsA("Model") then
		local pp = instance.PrimaryPart
		if pp then
			v = pp:GetAttribute(name)
			if v ~= nil then return v end
			vv = getValueObject(pp, name)
			if vv ~= nil then return vv end
		end
	end
	return nil
end

local function parseDropCount(instance)
	local count = getAttr(instance, "DropCount") or getAttr(instance, "LootCount")
	if typeof(count) == "number" then
		return math.max(1, math.floor(count))
	end
	local minRaw = getAttr(instance, "DropMin") or getAttr(instance, "LootMin")
	local maxRaw = getAttr(instance, "DropMax") or getAttr(instance, "LootMax")
	local min = tonumber(minRaw)
	local max = tonumber(maxRaw)
	if min and max then
		min = math.max(1, math.floor(min))
		max = math.max(1, math.floor(max))
		if max < min then
			min, max = max, min
		end
		return math.random(min, max)
	end
	if min then
		return math.max(1, math.floor(min))
	end
	if max then
		return math.max(1, math.floor(max))
	end
	return 1
end

local function attachDurationPrompt(instance)
	if not instance or not instance.Parent then return end
	local part, anchorPoint = getPromptAnchor(instance)
	if not part then return end
	if instance:IsA("Model") and not instance.PrimaryPart then
		instance.PrimaryPart = part
	end
	local duration = tonumber(getAttr(instance, "Duration")) or tonumber(getAttr(instance, "HarvestDuration")) or 0
	if duration <= 0 then return end
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	local attachment = part:FindFirstChild("HarvestPromptAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "HarvestPromptAttachment"
		attachment.Parent = part
	end
	if typeof(anchorPoint) == "Vector3" then
		attachment.WorldPosition = anchorPoint
	else
		attachment.Position = Vector3.new(0, 1.5, 0)
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Harvest"
		prompt.ObjectText = instance.Name
		prompt.RequiresLineOfSight = true
	end
	-- Nested prefab models can discover the same prompt during folder binding.
	if ResourceNodeService._promptOwners[prompt] then return end
	ResourceNodeService._promptOwners[prompt] = instance
	prompt.Parent = attachment
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = duration
	local holds = setmetatable({}, { __mode = "k" })
	local claimed = false
	local function canHarvest(plr)
		if claimed or ReplicatedStorage:GetAttribute("WorldRestoring") or not prompt.Enabled or not instance:IsDescendantOf(Workspace)
			or not attachment:IsDescendantOf(instance) or plr.Parent ~= Players
			or plr:GetAttribute("IsDead") then
			return false
		end
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
			and (root.Position - attachment.WorldPosition).Magnitude <= 11
	end
	prompt.PromptButtonHoldBegan:Connect(function(plr)
		if not canHarvest(plr) then return end
		local hold = { StartedAt = os.clock(), Character = plr.Character }
		holds[plr] = hold
		-- A client cannot bank a hold while dead or away from the resource.
		task.spawn(function()
			while holds[plr] == hold and not hold.EndedAt do
				if not canHarvest(plr) or plr.Character ~= hold.Character
					or os.clock() - hold.StartedAt > duration + 2 then
					holds[plr] = nil
					break
				end
				task.wait(0.1)
			end
		end)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(plr)
		local hold = holds[plr]
		if not hold then return end
		hold.EndedAt = os.clock()
		-- Ended and Triggered can arrive together; retain only a brief completion window.
		task.delay(0.5, function()
			if holds[plr] == hold then holds[plr] = nil end
		end)
	end)
	ResourceNodeService._attachedCount += 1
	local now = os.clock()
	if (now - ResourceNodeService._lastReport) >= 1 then
		if ResourceNodeService._attachedCount > 0 then
			print(string.format("[ResourceNodeService] Prompt attached (x%d)", ResourceNodeService._attachedCount))
			ResourceNodeService._attachedCount = 0
		end
		ResourceNodeService._lastReport = now
	end
	prompt.Triggered:Connect(function(plr)
		local hold = holds[plr]
		holds[plr] = nil
		local now = os.clock()
		if not hold or plr.Character ~= hold.Character or not canHarvest(plr)
			or now - hold.StartedAt > duration + 2
			or (hold.EndedAt and now - hold.EndedAt > 0.5)
			or (hold.EndedAt or now) - hold.StartedAt < math.max(0, duration - 0.1) then
			return
		end
		-- Claim before inventory callbacks can yield or another player completes a hold.
		claimed = true
		prompt.Enabled = false
		local itemId = getAttr(instance, "DropItemId") or getAttr(instance, "DropItemID") or getAttr(instance, "ItemId") or instance.Name
		itemId = ResourceItemMap.Normalize(itemId)
		local count = parseDropCount(instance)
		local roleMult = tonumber(plr:GetAttribute("Role_Gather")) or 1.0
		count = math.max(1, math.floor(count * roleMult))
		local added = InventoryService:Give(plr, itemId, count, true)
		if added > 0 then
			instance:Destroy()
		else
			claimed = false
			if prompt.Parent then prompt.Enabled = true end
		end
	end)
end

function ResourceNodeService:BindFolder(folder)
	if not folder then return end
	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("Model") and not self._bound[child] then
			self._bound[child] = true
			PromptQueueService:Enqueue(function()
				attachDurationPrompt(child)
			end)
		elseif child:IsA("BasePart") and not child:FindFirstAncestorOfClass("Model") and not self._bound[child] then
			self._bound[child] = true
			PromptQueueService:Enqueue(function()
				attachDurationPrompt(child)
			end)
		end
	end
	folder.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") and not self._bound[desc] then
			self._bound[desc] = true
			PromptQueueService:Enqueue(function()
				attachDurationPrompt(desc)
			end)
		elseif desc:IsA("BasePart") and not desc:FindFirstAncestorOfClass("Model") and not self._bound[desc] then
			self._bound[desc] = true
			PromptQueueService:Enqueue(function()
				attachDurationPrompt(desc)
			end)
		end
	end)
end

function ResourceNodeService:BindGeneratedWorld()
	local generated = Workspace:FindFirstChild("GeneratedWorld")
	if not generated then
		warn("[ResourceNodeService] GeneratedWorld not found")
		return
	end
	local resources = generated:FindFirstChild("Resources")
	if not resources then
		warn("[ResourceNodeService] Resources folder not found")
		return
	end
	self:BindFolder(resources)
end

return ResourceNodeService
