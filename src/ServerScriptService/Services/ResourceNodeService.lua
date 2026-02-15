-- ResourceNodeService.lua
-- Adds prompts for duration-based resources.
local Workspace = game:GetService("Workspace")

local InventoryService = require(script.Parent.InventoryService)
local PromptQueueService = require(script.Parent.PromptQueueService)

local ResourceNodeService = {}
ResourceNodeService._bound = setmetatable({}, { __mode = "k" }) -- [Instance] = true
ResourceNodeService._attachedCount = 0
ResourceNodeService._lastReport = 0

local function getPrimary(instance)
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Model") then
		if instance.PrimaryPart then return instance.PrimaryPart end
		for _, d in ipairs(instance:GetDescendants()) do
			if d:IsA("BasePart") then return d end
		end
	end
	return nil
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
	local part = getPrimary(instance)
	if not part then return end
	if instance:IsA("Model") then
		instance.PrimaryPart = part
	end
	local duration = tonumber(getAttr(instance, "Duration")) or tonumber(getAttr(instance, "HarvestDuration")) or 0
	if duration <= 0 then return end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Harvest"
		prompt.ObjectText = instance.Name
		prompt.RequiresLineOfSight = true
		prompt.Parent = part
	end
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = duration
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
		print(string.format("[ResourceNodeService] Prompt triggered by %s on %s", plr.Name, instance.Name))
		local itemId = getAttr(instance, "DropItemId") or getAttr(instance, "DropItemID") or getAttr(instance, "ItemId") or instance.Name
		local count = parseDropCount(instance)
		local roleMult = tonumber(plr:GetAttribute("Role_Gather")) or 1.0
		count = math.max(1, math.floor(count * roleMult))
		local added = InventoryService:Give(plr, itemId, count, true)
		print(string.format("[ResourceNodeService] Give %s x%d -> added %d", tostring(itemId), count, added))
		if added > 0 then
			instance:Destroy()
		else
			print("[ResourceNodeService] Inventory full or invalid item, no destroy")
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
