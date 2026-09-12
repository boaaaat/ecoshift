-- InteractService.lua
-- Server-authoritative interaction handling for resource harvesting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ToolConfig = require(ReplicatedStorage.Modules.ToolConfig)
local ResourceItemMap = require(ReplicatedStorage.Shared.ResourceItemMap)
local ItemDropService = require(script.Parent.ItemDropService)
local GameStateService = require(script.Parent.GameStateService)

local InteractService = {}
InteractService._remotesFolder = nil
InteractService._remote = nil
InteractService._conns = {}

local _lastInteract = setmetatable({}, { __mode = "k" })
local _feedbackRemote = nil

local HARVEST_MARKER_NAMES = {
	"Health",
	"MaxHealth",
	"Duration",
	"HarvestDuration",
	"DropItemId",
	"DropItemID",
	"DropCount",
	"LootCount",
}
local _hasHarvestMarkerCache = setmetatable({}, { __mode = "k" })
local _markedDescendantCache = setmetatable({}, { __mode = "k" })

local function getFeedbackRemote()
	if _feedbackRemote then
		return _feedbackRemote
	end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	_feedbackRemote = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.HarvestFeedback) or nil
	return _feedbackRemote
end

local function getNodeAttr(node, name)
	local v = node:GetAttribute(name)
	if v ~= nil then
		return v
	end
	if node:IsA("Model") and node.PrimaryPart then
		v = node.PrimaryPart:GetAttribute(name)
		if v ~= nil then
			return v
		end
	end
	local obj = node:FindFirstChild(name, true)
	if obj and obj:IsA("ValueBase") then
		return obj.Value
	end
	return nil
end

local function getNodePosition(node)
	if node:IsA("BasePart") then
		return node.Position
	end
	if node:IsA("Model") then
		if node.PrimaryPart then
			return node.PrimaryPart.Position
		end
		local anyPart = node:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			return anyPart.Position
		end
	end
	return nil
end

local function getPrimary(node)
	if node:IsA("BasePart") then
		return node
	end
	if node:IsA("Model") then
		if node.PrimaryPart then
			return node.PrimaryPart
		end
		return node:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getClosestNodePoint(node, worldPoint)
	if typeof(node) ~= "Instance" or typeof(worldPoint) ~= "Vector3" then
		return nil, nil
	end

	local bestPoint = nil
	local bestDistance = math.huge

	local function considerPart(part)
		local closestPoint = part.Position
		local ok, result = pcall(part.GetClosestPointOnSurface, part, worldPoint)
		if ok and typeof(result) == "Vector3" then
			closestPoint = result
		end

		local dist = (worldPoint - closestPoint).Magnitude
		if dist < bestDistance then
			bestDistance = dist
			bestPoint = closestPoint
		end
	end

	if node:IsA("BasePart") then
		considerPart(node)
	elseif node:IsA("Model") then
		for _, inst in ipairs(node:GetDescendants()) do
			if inst:IsA("BasePart") then
				considerPart(inst)
			end
		end
	end

	if not bestPoint then
		return nil, nil
	end
	return bestPoint, bestDistance
end

local function hasMarker(node, name, allowRecursive)
	if node:GetAttribute(name) ~= nil then
		return true
	end
	local child = node:FindFirstChild(name, allowRecursive == true)
	return child ~= nil
end

local function hasHarvestMarker(node, allowRecursive)
	if typeof(node) ~= "Instance" then
		return false
	end
	if allowRecursive ~= false then
		local cached = _hasHarvestMarkerCache[node]
		if cached ~= nil then
			return cached
		end
	end

	for _, name in ipairs(HARVEST_MARKER_NAMES) do
		if hasMarker(node, name, false) then
			if allowRecursive ~= false then
				_hasHarvestMarkerCache[node] = true
			end
			return true
		end
	end
	if node:IsA("Model") and node.PrimaryPart then
		for _, name in ipairs(HARVEST_MARKER_NAMES) do
			if node.PrimaryPart:GetAttribute(name) ~= nil or node.PrimaryPart:FindFirstChild(name) then
				if allowRecursive ~= false then
					_hasHarvestMarkerCache[node] = true
				end
				return true
			end
		end
	end

	local found = false
	if allowRecursive ~= false then
		for _, name in ipairs(HARVEST_MARKER_NAMES) do
			if hasMarker(node, name, true) then
				found = true
				break
			end
		end
		if not found and node:IsA("Model") and node.PrimaryPart then
			for _, name in ipairs(HARVEST_MARKER_NAMES) do
				if node.PrimaryPart:GetAttribute(name) ~= nil or node.PrimaryPart:FindFirstChild(name, true) then
					found = true
					break
				end
			end
		end
	end

	if allowRecursive ~= false then
		_hasHarvestMarkerCache[node] = found
	end
	return found
end

local function findMarkedDescendant(root, hintPosition)
	if typeof(root) ~= "Instance" then
		return nil
	end

	local cached = _markedDescendantCache[root]
	local bestNode = nil
	local bestDist = math.huge
	if cached and cached.Parent and cached:IsDescendantOf(root) and hasHarvestMarker(cached, false) then
		bestNode = cached
		if hintPosition then
			local cachedPos = getNodePosition(cached)
			if cachedPos then
				bestDist = (cachedPos - hintPosition).Magnitude
			end
		else
			return cached
		end
	end

	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("Model") or inst:IsA("BasePart")) and hasHarvestMarker(inst, false) then
			if not hintPosition then
				_markedDescendantCache[root] = inst
				return inst
			end
			local pos = getNodePosition(inst)
			if pos then
				local dist = (pos - hintPosition).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestNode = inst
				end
			elseif not bestNode then
				bestNode = inst
			end
		end
	end

	if not bestNode then
		for _, inst in ipairs(root:GetDescendants()) do
			if (inst:IsA("Model") or inst:IsA("BasePart")) and hasHarvestMarker(inst, true) then
				if not hintPosition then
					bestNode = inst
					break
				end
				local pos = getNodePosition(inst)
				if pos then
					local dist = (pos - hintPosition).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestNode = inst
					end
				elseif not bestNode then
					bestNode = inst
				end
			end
		end
	end

	if bestNode then
		_markedDescendantCache[root] = bestNode
	end
	return bestNode
end

local function resolveHarvestNode(payload)
	local node = nil
	if typeof(payload) == "Instance" then
		node = payload
	elseif type(payload) == "table" then
		node = payload.Node or payload.Hit
	end
	if typeof(node) ~= "Instance" or not node.Parent then
		return nil
	end

	local hintPosition = getNodePosition(node)
	local cur = node
	while cur and cur ~= Workspace do
		if hasHarvestMarker(cur) then
			if cur:IsA("Model") or cur:IsA("BasePart") then
				return cur
			end
			local descendant = findMarkedDescendant(cur, hintPosition)
			if descendant then
				return descendant
			end
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function isAllowedResourceNode(node)
	if typeof(node) ~= "Instance" or not node.Parent then
		return false
	end
	if not hasHarvestMarker(node) then
		return false
	end

	local resourcesAncestor = node:FindFirstAncestor("Resources")
	if resourcesAncestor and resourcesAncestor:IsDescendantOf(Workspace) then
		return true
	end

	return false
end

local function readString(tool, name)
	if not tool then
		return ""
	end
	local attr = tool:GetAttribute(name)
	if typeof(attr) == "string" then
		return attr
	elseif attr ~= nil then
		return tostring(attr)
	end
	local child = tool:FindFirstChild(name)
	if child and child:IsA("ValueBase") then
		if typeof(child.Value) == "string" then
			return child.Value
		end
		return tostring(child.Value or "")
	end
	return ""
end

local function getEquippedHarvestTool(plr)
	local char = plr and plr.Character
	if not char then
		return nil
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			local weaponType = readString(child, "WeaponType")
			local toolType = readString(child, "ToolType")
			if weaponType == "" and toolType ~= "" then
				return child
			end
		end
	end
	return nil
end

local function setNodeAttr(node, name, value)
	local obj = node:FindFirstChild(name, true)
	if obj and obj:IsA("ValueBase") then
		obj.Value = value
		return
	end
	if node:IsA("Model") and node.PrimaryPart then
		local primaryObj = node.PrimaryPart:FindFirstChild(name, true)
		if primaryObj and primaryObj:IsA("ValueBase") then
			primaryObj.Value = value
			return
		end
	end
	node:SetAttribute(name, value)
end

local function parseDropCount(node)
	local count = getNodeAttr(node, "DropCount") or getNodeAttr(node, "LootCount")
	if typeof(count) == "number" then
		return math.max(1, math.floor(count))
	end
	local min = getNodeAttr(node, "DropMin") or getNodeAttr(node, "LootMin")
	local max = getNodeAttr(node, "DropMax") or getNodeAttr(node, "LootMax")
	if typeof(min) == "number" and typeof(max) == "number" then
		return math.random(math.floor(min), math.floor(max))
	end
	return 1
end

local function destroyNodeWithDrop(node, plr)
	local explicitDropItemId = getNodeAttr(node, "DropItemId") or getNodeAttr(node, "DropItemID")
	local itemId = explicitDropItemId or getNodeAttr(node, "ItemId") or getNodeAttr(node, "PickupItemId") or node.Name
	itemId = ResourceItemMap.Normalize(itemId)
	local dropScale = tonumber(getNodeAttr(node, "DropScale"))
	local count = parseDropCount(node)

	local nightMult = 1
	if _G.Ecoshift and _G.Ecoshift.DayNightService and _G.Ecoshift.DayNightService.GetResourceMultiplier then
		nightMult = tonumber(_G.Ecoshift.DayNightService:GetResourceMultiplier()) or 1
	elseif _G.Ecoshift and _G.Ecoshift.Mods and _G.Ecoshift.Mods.ResourceMultiplier then
		nightMult = tonumber(_G.Ecoshift.Mods.ResourceMultiplier) or 1
	end
	count = math.max(1, math.floor(count * nightMult))
	count += require(script.Parent.ClassEffects).Extra(plr, node)

	local dropOptions = nil
	if not explicitDropItemId and dropScale and dropScale > 0 then
		dropOptions = {
			FallbackModel = node,
			DropScale = dropScale,
		}
	end

	local nodePos = getNodePosition(node)
	if nodePos then
		local drop = ItemDropService:SpawnDrop(itemId, count, nodePos + Vector3.new(0, 2, 0), dropOptions)
		if drop then node:Destroy() end
	end
end

local function handleHarvest(plr, payload)
	if GameStateService:IsGameOver() or ReplicatedStorage:GetAttribute("WorldRestoring")
		or plr:GetAttribute("IsDead") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") then
		return
	end
	local node = resolveHarvestNode(payload)
	if not node or not isAllowedResourceNode(node) then
		return
	end
	if node:GetAttribute("Enabled") == false then
		return
	end

	local tool = getEquippedHarvestTool(plr)
	if not tool then
		return
	end

	local duration = tonumber(getNodeAttr(node, "Duration")) or tonumber(getNodeAttr(node, "HarvestDuration")) or 0
	if duration > 0 then
		return
	end

	local cd = tonumber(node:GetAttribute("CooldownUntil")) or 0
	if os.clock() < cd then
		return
	end

	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local rootPos = root.Position

	local closestNodePoint, nodeDistance = getClosestNodePoint(node, rootPos)
	if not closestNodePoint or not nodeDistance then
		local primary = getPrimary(node)
		if not primary then
			return
		end
		closestNodePoint = primary.Position
		nodeDistance = (rootPos - primary.Position).Magnitude
	end

	local nodePos = closestNodePoint or getNodePosition(node)

	local cfg = ToolConfig.Read(tool)
	cfg.Range = math.max(cfg.Range or 0, 8)
	cfg.Cooldown = math.max(0.05, tonumber(cfg.Cooldown) or 0.5)
	local nextUse = (_lastInteract[plr] or 0) + cfg.Cooldown
	if os.clock() < nextUse then
		return
	end

	if nodeDistance > (cfg.Range or 8) then
		return
	end

	local baseDamage = tonumber(cfg.Damage)
	if not baseDamage or baseDamage <= 0 then
		baseDamage = tonumber(tool:GetAttribute("HarvestDamage"))
	end
	if not baseDamage or baseDamage <= 0 then
		baseDamage = 1
	end
	baseDamage = math.clamp(baseDamage, 1, 500)
	local roleMult = require(script.Parent.ClassEffects).Power(plr, node)
	local damage = math.max(1, math.floor(baseDamage * roleMult))
	local weakness = tostring(getNodeAttr(node, "Weakness") or "")
	if weakness ~= "" and cfg.ToolType == weakness then
		local weaknessMult = tonumber(cfg.Multiplier) or 1.5
		damage = math.max(1, math.floor(damage * weaknessMult))
	end

	local maxHealth = tonumber(getNodeAttr(node, "MaxHealth")) or tonumber(getNodeAttr(node, "Health")) or 100
	local currentHealth = tonumber(node:GetAttribute("CurrentHealth"))
	if not currentHealth then
		currentHealth = tonumber(getNodeAttr(node, "Health")) or maxHealth
		setNodeAttr(node, "CurrentHealth", currentHealth)
		setNodeAttr(node, "MaxHealth", maxHealth)
	end

	currentHealth = math.max(0, currentHealth - damage)
	setNodeAttr(node, "CurrentHealth", currentHealth)
	setNodeAttr(node, "Health", currentHealth)
	_lastInteract[plr] = os.clock()
	require(script.Parent.ExpeditionRewardsService):RecordActivity(plr)

	local feedbackRemote = getFeedbackRemote()
	if feedbackRemote then
		feedbackRemote:FireClient(plr, {
			Node = node,
			Position = nodePos,
			Damage = damage,
			Health = currentHealth,
			CurrentHealth = currentHealth,
			MaxHealth = maxHealth,
			Destroyed = currentHealth <= 0,
		})
	end

	if currentHealth <= 0 then
		destroyNodeWithDrop(node, plr)
	else
		node:SetAttribute("CooldownUntil", os.clock() + 0.1)
	end
end

function InteractService:_bindRemote(remote)
	if not remote or self._conns[remote] then
		return
	end
	self._conns[remote] = remote.OnServerEvent:Connect(function(plr, action, payload)
		if typeof(plr) ~= "Instance" then
			return
		end
		if action ~= "Harvest" then
			return
		end
		local ok, err = pcall(handleHarvest, plr, payload)
		if not ok then
			warn(string.format("[InteractService] Harvest handling failed for %s: %s", plr.Name, tostring(err)))
		end
	end)
end

function InteractService:Bind()
	self._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	if not self._remotesFolder then
		warn("[InteractService] Missing remotes folder:", Config.Paths.Remotes)
		return
	end
	self._remote = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Interact)
	if not self._remote then
		warn("[InteractService] Missing interact remote:", Config.RemoteNames.Interact)
		return
	end
	self:_bindRemote(self._remote)
end

return InteractService
