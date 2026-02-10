-- InteractService.lua (expanded: Harvest, Revive)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ObjectiveService = require(script.Parent.ObjectiveService)
local InventoryService = require(script.Parent.InventoryService)

local InteractService = {}
InteractService._remotesFolder = nil
InteractService._remote = nil

local _lastInteract = {}

local function tooSoon(plr, minGap)
	local now = os.clock(); local last = _lastInteract[plr] or 0
	if now - last < (minGap or 0.05) then return true end
	_lastInteract[plr] = now; return false
end

local ACTIONS = {}

ACTIONS.ObjectiveProgress = function(plr, payload)
	if type(payload) ~= "table" then return end
	local id = payload.ObjectiveId; local delta = tonumber(payload.Delta) or 0
	if not id or delta <= 0 then return end
	ObjectiveService:Advance(id, delta)
end

ACTIONS.Pickup = function(plr, payload)
	local id, n = payload and payload.ItemId, tonumber(payload and payload.Amount) or 1
	if not id or n <= 0 then return end
	InventoryService:Give(plr, id, n)
end

-- Helper to get feedback remote
local _feedbackRemote = nil
local function getFeedbackRemote()
	if _feedbackRemote then return _feedbackRemote end
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
	_feedbackRemote = Util.GetRemote(remotesFolder, Config.RemoteNames.HarvestFeedback)
	return _feedbackRemote
end

-- Helper to get node position for feedback
local function getNodePosition(node)
	if node:IsA("BasePart") then return node.Position end
	if node:IsA("Model") then
		if node.PrimaryPart then return node.PrimaryPart.Position end
		for _, d in ipairs(node:GetDescendants()) do
			if d:IsA("BasePart") then return d.Position end
		end
	end
	return nil
end

-- Helper to get attribute from node or its PrimaryPart
local function getNodeAttr(node, name)
	local v = node:GetAttribute(name)
	if v ~= nil then return v end
	if node:IsA("Model") and node.PrimaryPart then
		v = node.PrimaryPart:GetAttribute(name)
		if v ~= nil then return v end
	end
	-- Check for value objects
	local obj = node:FindFirstChild(name, true)
	if obj and obj:IsA("ValueBase") then return obj.Value end
	return nil
end

ACTIONS.Harvest = function(plr, payload)
	-- payload can be: Instance (node) OR table with {Node, Damage, Yields, Cooldown}
	local node, damage
	if typeof(payload) == "Instance" then
		node = payload
		damage = nil -- will get from tool
	elseif type(payload) == "table" then
		node = payload.Node
		damage = payload.Damage
	else
		return
	end
	
	if typeof(node) ~= "Instance" then return end
	if not node.Parent then return end -- already destroyed
	if (node:GetAttribute("Enabled") == false) then return end
	
	-- Cooldown check
	local cd = tonumber(node:GetAttribute("CooldownUntil")) or 0
	if os.clock() < cd then return end
	
	-- Distance guard
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local nodePos = getNodePosition(node)
	if not root or not nodePos then return end
	if (root.Position - nodePos).Magnitude > 25 then return end
	
	-- Get tool damage if not provided
	if not damage then
		local tool = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
		if tool then
			damage = tool:GetAttribute("HarvestDamage") or tool:GetAttribute("Damage") or 10
		else
			damage = 10
		end
	end
	
	-- Apply gather multiplier
	local roleMult = tonumber(plr:GetAttribute("Role_Gather")) or 1.0
	damage = math.floor(damage * roleMult)
	
	-- Get or initialize health
	local maxHealth = tonumber(getNodeAttr(node, "MaxHealth")) or tonumber(getNodeAttr(node, "Health")) or 100
	local currentHealth = tonumber(node:GetAttribute("CurrentHealth"))
	if not currentHealth then
		-- Initialize from Health attribute or default
		currentHealth = tonumber(getNodeAttr(node, "Health")) or maxHealth
		node:SetAttribute("CurrentHealth", currentHealth)
		node:SetAttribute("MaxHealth", maxHealth)
	end
	
	-- Apply damage
	currentHealth = math.max(0, currentHealth - damage)
	node:SetAttribute("CurrentHealth", currentHealth)
	
	-- Send feedback to client
	local feedbackRemote = getFeedbackRemote()
	if feedbackRemote then
		feedbackRemote:FireClient(plr, {
			Node = node,
			Position = nodePos,
			Damage = damage,
			CurrentHealth = currentHealth,
			MaxHealth = maxHealth,
			Destroyed = currentHealth <= 0,
		})
	end
	
	-- Check if destroyed
	if currentHealth <= 0 then
		-- Get drop info
		local itemId = getNodeAttr(node, "DropItemId") or getNodeAttr(node, "DropItemID") or getNodeAttr(node, "ItemId") or node.Name
		local dropCount = tonumber(getNodeAttr(node, "DropCount")) or tonumber(getNodeAttr(node, "LootCount")) or 1
		
		-- Apply resource multiplier
		local mult = (_G.Ecoshift and _G.Ecoshift.Mods and _G.Ecoshift.Mods.ResourceMultiplier) or 1.0
		mult *= roleMult
		dropCount = math.max(1, math.floor(dropCount * mult))
		
		-- Give items
		local added = InventoryService:Give(plr, itemId, dropCount, true)
		
		if added > 0 then
			-- Destroy the node
			node:Destroy()
		else
			-- Inventory full - reset health so they can try again
			node:SetAttribute("CurrentHealth", maxHealth)
		end
	else
		-- Set short cooldown between hits
		node:SetAttribute("CooldownUntil", os.clock() + 0.1)
	end
end

ACTIONS.Repair = function(plr, payload)
	local t = payload and payload.Target; local amt = tonumber(payload and payload.Amount) or 0
	if not t or amt <= 0 then return end
	local dur = t:FindFirstChild("Durability")
	if dur and dur:IsA("NumberValue") then
		dur.Value = math.clamp(dur.Value + amt, 0, (t:GetAttribute("DurabilityMax") or 100))
	end
end

ACTIONS.Revive = function(plr, payload)
	-- payload = {TargetCharacter = Model}
	local targetChar = payload and payload.TargetCharacter
	if typeof(targetChar) ~= "Instance" or not targetChar:FindFirstChildWhichIsA("Humanoid") then return end
	local hum = targetChar:FindFirstChildWhichIsA("Humanoid")
	if hum.Health > 0 then return end -- already alive or not downed (you can adapt to your downed logic)
	-- if you use a "Downed" Attribute instead of death, update here. For now, simple respawn:
	local targetPlr = Players:GetPlayerFromCharacter(targetChar)
	if targetPlr then targetPlr:LoadCharacterAsync() end
end

function InteractService:Bind()
	self._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Interact)
	if not self._remote then return end
	self._remote.OnServerEvent:Connect(function(plr, action, payload)
		if typeof(plr) ~= "Instance" or tooSoon(plr, 0.03) then return end
		local fn = ACTIONS[action]; if not fn then return end
		local ok = pcall(fn, plr, payload); if not ok then end
	end)
end

return InteractService
