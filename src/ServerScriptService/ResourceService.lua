local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InteractRE = Remotes:WaitForChild("ResourceInteract")
local CarryRE = Remotes:WaitForChild("ResourceCarry")

-- HarvestFeedback remote for damage numbers/health bars
local HarvestFeedbackRE = Remotes:FindFirstChild("HarvestFeedback")
if not HarvestFeedbackRE then
	HarvestFeedbackRE = Instance.new("RemoteEvent")
	HarvestFeedbackRE.Name = "HarvestFeedback"
	HarvestFeedbackRE.Parent = Remotes
end

local ToolConfig = require(ReplicatedStorage.Modules.ToolConfig)
local ItemDropService = require(script.Parent.Services.ItemDropService)

-- Per-player cooldowns
local lastUse = setmetatable({}, {__mode = "k"})

local function now()
	return os.clock()
end

local function getPrimary(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function getValueObject(instance: Instance, name: string)
	local obj = instance:FindFirstChild(name, true)
	if obj and obj:IsA("ValueBase") then
		return obj.Value
	end
	return nil
end

local function getAttr(modelOrPart: Instance, name: string)
	local v = modelOrPart:GetAttribute(name)
	if v ~= nil then return v end
	local vv = getValueObject(modelOrPart, name)
	if vv ~= nil then return vv end
	if modelOrPart:IsA("Model") and modelOrPart.PrimaryPart then
		v = modelOrPart.PrimaryPart:GetAttribute(name)
		if v ~= nil then return v end
		vv = getValueObject(modelOrPart.PrimaryPart, name)
		if vv ~= nil then return vv end
	end
	if modelOrPart.Parent and modelOrPart.Parent:IsA("Model") and modelOrPart.Parent.PrimaryPart then
		v = modelOrPart.Parent.PrimaryPart:GetAttribute(name)
		if v ~= nil then return v end
		vv = getValueObject(modelOrPart.Parent.PrimaryPart, name)
		if vv ~= nil then return vv end
	end
	return nil
end

local function setAttr(modelOrPart: Instance, name: string, value: any)
	local function setValueObject(instance)
		local obj = instance:FindFirstChild(name, true)
		if obj and obj:IsA("ValueBase") then
			obj.Value = value
			return true
		end
		return false
	end
	if setValueObject(modelOrPart) then return end
	if modelOrPart:IsA("Model") and modelOrPart.PrimaryPart then
		if setValueObject(modelOrPart.PrimaryPart) then return end
		modelOrPart.PrimaryPart:SetAttribute(name, value)
		return
	end
	modelOrPart:SetAttribute(name, value)
end

local function isNode(instance: Instance)
	if not instance then return false end
	local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
	if not model then return false end
	local health = getAttr(model, "Health")
	return typeof(health) == "number"
end

local function withinRange(player: Player, targetPart: BasePart, range: number)
	local char = player.Character
	if not char or not targetPart then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - targetPart.Position).Magnitude <= range
end

local function parseDropCount(nodeModel)
	local count = getAttr(nodeModel, "DropCount") or getAttr(nodeModel, "LootCount")
	if typeof(count) == "number" then
		return math.max(1, math.floor(count))
	end
	local min = getAttr(nodeModel, "DropMin") or getAttr(nodeModel, "LootMin")
	local max = getAttr(nodeModel, "DropMax") or getAttr(nodeModel, "LootMax")
	if typeof(min) == "number" and typeof(max) == "number" then
		return math.random(math.floor(min), math.floor(max))
	end
	return 1
end

local function destroyNode(nodeModel: Model, player: Player?)
	local itemId = getAttr(nodeModel, "DropItemId") or getAttr(nodeModel, "ItemId") or getAttr(nodeModel, "PickupItemId") or nodeModel.Name
	local count = parseDropCount(nodeModel)
	if player then
		local roleMult = tonumber(player:GetAttribute("Role_Gather")) or 1.0
		count = math.max(1, math.floor(count * roleMult))
		-- Apply night resource multiplier
		local nightMult = (_G.Ecoshift and _G.Ecoshift.DayNightService and _G.Ecoshift.DayNightService.GetResourceMultiplier)
			and _G.Ecoshift.DayNightService:GetResourceMultiplier() or 1
		count = math.max(1, math.floor(count * nightMult))
	end
	local pos = nodeModel:GetPivot().Position
	ItemDropService:SpawnDrop(itemId, count, pos + Vector3.new(0, 2, 0))
	nodeModel:Destroy()
end

local function serverApplyHarvest(player: Player, nodeModel: Model, toolOrNil: Tool?)
	if not nodeModel or not nodeModel.Parent then return end

	local prim = getPrimary(nodeModel)
	if not prim then return end

	local duration = getAttr(nodeModel, "Duration") or getAttr(nodeModel, "HarvestDuration")
	if typeof(duration) == "number" and duration > 0 then
		return -- duration-based handled by prompts
	end

	-- Read current values
	local health = getAttr(nodeModel, "Health") or 1
	-- MaxHealth: check attribute first, then use stored _MaxHealth, then default to 100
	local maxH = getAttr(nodeModel, "MaxHealth") or getAttr(nodeModel, "_MaxHealth")
	if not maxH then
		-- First hit - store the initial health as max
		maxH = health
		setAttr(nodeModel, "_MaxHealth", maxH)
	end
	local weakness = getAttr(nodeModel, "Weakness") or ""

	-- Determine tool data
	local cfg
	if toolOrNil and toolOrNil:IsA("Tool") then
		cfg = ToolConfig.Read(toolOrNil)
	else
		cfg = { ToolType = "", Damage = 0, Range = 6, Cooldown = 0.5, Multiplier = 1 }
	end
	cfg.Range = math.max(cfg.Range or 0, 8)
	cfg.Damage = math.max(cfg.Damage or 0, 0)

	-- Range and cooldown checks
	if not withinRange(player, prim, cfg.Range or 6) then return end
	local t = now()
	local cdKey = player
	local nextTime = (lastUse[cdKey] or 0)
	if t < nextTime then return end
	lastUse[cdKey] = t + (cfg.Cooldown or 0.5)

	-- If health > 1 then a tool with damage is required
	if health > 1 then
		if (cfg.Damage or 0) <= 0 then
			return -- tool has no damage
		end
	end

	-- Apply damage (use universal Damage value)
	local hit = cfg.Damage
	if not hit or hit <= 0 then
		hit = 1
	end
	
	-- Bonus multiplier if tool matches weakness (e.g., Axe vs Tree)
	-- Any tool can harvest, but matching tools get bonus damage!
	if weakness ~= "" and cfg.ToolType == weakness then
		local multiplier = cfg.Multiplier or 1.5
		hit = math.floor(hit * multiplier)
	end
	
	local oldHealth = health
	health = math.max(health - hit, 0)
	setAttr(nodeModel, "Health", health)

	-- Send feedback to client for damage numbers/health bar
	local feedbackPosition = prim and prim.Position or nodeModel:GetPivot().Position
	print(string.format("[ResourceService] Sending HarvestFeedback: damage=%d health=%d/%d destroyed=%s", 
		hit, health, maxH, tostring(health <= 0)))
	HarvestFeedbackRE:FireClient(player, {
		Node = nodeModel,
		Position = feedbackPosition,
		Damage = hit,
		Health = health,
		MaxHealth = maxH,
		Destroyed = health <= 0,
	})

	-- Destroy if depleted
	if health <= 0 then
		destroyNode(nodeModel, player)
	end
end

local function findNearbyNode(player: Player, range: number)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local generated = game:GetService("Workspace"):FindFirstChild("GeneratedWorld")
	if not generated then return nil end
	
	local best = nil
	local bestDist = range
	
	-- Helper to check a folder for resource nodes
	local function searchFolder(folder)
		if not folder then return end
		for _, model in ipairs(folder:GetDescendants()) do
			if model:IsA("Model") then
				local health = getAttr(model, "Health")
				local duration = getAttr(model, "Duration") or getAttr(model, "HarvestDuration")
				if typeof(health) == "number" or typeof(duration) == "number" then
					local pos = model:GetPivot().Position
					local dist = (pos - hrp.Position).Magnitude
					if dist <= bestDist then
						best = model
						bestDist = dist
					end
				end
			end
		end
	end
	
	-- Search top-level Resources folder (legacy/non-streaming)
	local resources = generated:FindFirstChild("Resources")
	searchFolder(resources)
	
	-- Search chunk folders (streaming mode: GeneratedWorld/Chunk_X,Z/Resources)
	for _, child in ipairs(generated:GetChildren()) do
		if child:IsA("Folder") and child.Name:match("^Chunk_") then
			local chunkResources = child:FindFirstChild("Resources")
			searchFolder(chunkResources)
		end
	end
	
	return best
end

-- Client requests to harvest a node (validate all on server)
InteractRE.OnServerEvent:Connect(function(player: Player, action: string, nodeRef: Instance)
	print(string.format("[ResourceService] %s -> %s", player.Name, tostring(action)))
	if action ~= "Harvest" then return end

	-- Determine currently equipped tool
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local tool: Tool? = nil
	if char then
		tool = char:FindFirstChildOfClass("Tool")
	end
	if not tool and hum then
		tool = hum:FindFirstChildOfClass("Tool")
	end
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		tool = backpack and backpack:FindFirstChildOfClass("Tool") or nil
	end
	if tool then
		print(string.format("[ResourceService] Using tool %s", tool.Name))
	else
		print("[ResourceService] No tool equipped")
	end

	local model = nil
	if nodeRef and isNode(nodeRef) then
		model = nodeRef:IsA("Model") and nodeRef or nodeRef:FindFirstAncestorOfClass("Model")
	else
		if nodeRef ~= nil then
			warn("[ResourceService] Invalid node ref")
		else
			print("[ResourceService] No node provided, using fallback search")
		end
	end
	if not model then
		local range = 6
		if tool and tool:IsA("Tool") then
			local cfg = ToolConfig.Read(tool)
			range = cfg.Range or 8
		end
		model = findNearbyNode(player, range)
		if model then
			print(string.format("[ResourceService] Fallback nearest node %s", model.Name))
		else
			warn("[ResourceService] No valid node found")
			return
		end
	end

	serverApplyHarvest(player, model, tool)
end)

-- Carry / release requests (optional lightweight physics carry)
CarryRE.OnServerEvent:Connect(function(player: Player, action: string, dropModel: Model?)
	if action == "RequestNetworkOwnership" and dropModel and dropModel.Parent then
		if getAttr(dropModel, "IsResourceDrop") then
			local pp = getPrimary(dropModel)
			if pp then pp:SetNetworkOwner(player) end
		end
	elseif action == "ReleaseNetworkOwnership" and dropModel and dropModel.Parent then
		local pp = getPrimary(dropModel)
		if pp then pcall(function() pp:SetNetworkOwnershipAuto() end) end
	end
end)
