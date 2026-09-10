-- EntityAIService.lua
-- Binds AI controllers to monsters/animals and runs update loop.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AIFolder = script.Parent.Parent:WaitForChild("AI")
local MonsterClass = require(AIFolder:WaitForChild("Monster"))
local AnimalClass = require(AIFolder:WaitForChild("Animal"))
local EntityConfig = require(AIFolder:WaitForChild("EntityConfig"))
local Progression = require(ReplicatedStorage.Shared.ProgressionConfig)
local RoundService = require(script.Parent.RoundService)

local EntityAIService = {}
EntityAIService._entities = {} -- [Model] = controller
EntityAIService._stepping = {} -- [Model] = true while its pathfinding step yields
EntityAIService._stepInterval = 0.2

local NUM_KEYS = {
	"DetectionAngle",
	"DetectionDistance",
	"AutoDetectRadius",
	"Damage",
	"Speed",
	"AttackRange",
	"AttackCooldown",
	"RepathInterval",
	"RepathDistance",
	"AgentRadius",
	"AgentHeight",
	"WanderRadius",
	"WanderInterval",
	"FleeDistance",
	"FleeSpeed",
	"StuckMinMove",
	"StuckJumpTime",
}
local BOOL_KEYS = {
	"UsePathfinding",
	"AgentCanJump",
}
local STRING_KEYS = {
	"PlayerPriority",
	"TargetRole",
	"AIClass",
}

local function shallowMerge(dst, src)
	local out = {}
	for k, v in pairs(dst or {}) do out[k] = v end
	for k, v in pairs(src or {}) do out[k] = v end
	return out
end

local function readNumber(model, key)
	local attr = model:GetAttribute(key)
	if attr == nil and key == "AutoDetectRadius" then
		attr = model:GetAttribute("AutoDetectionRadius")
	end
	if typeof(attr) == "number" then return attr end
	if typeof(attr) == "string" then
		local n = tonumber(attr)
		if n then return n end
	end
	local val = model:FindFirstChild(key)
	if not val and key == "AutoDetectRadius" then
		val = model:FindFirstChild("AutoDetectionRadius")
	end
	if val and val:IsA("ValueBase") then
		local n = tonumber(val.Value)
		if n then return n end
	end
	return nil
end

local function readBool(model, key)
	local attr = model:GetAttribute(key)
	if typeof(attr) == "boolean" then return attr end
	if typeof(attr) == "string" then
		if attr == "true" then return true end
		if attr == "false" then return false end
	end
	local val = model:FindFirstChild(key)
	if val and val:IsA("BoolValue") then
		return val.Value
	end
	return nil
end

local function readString(model, key)
	local attr = model:GetAttribute(key)
	if typeof(attr) == "string" and attr ~= "" then return attr end
	local val = model:FindFirstChild(key)
	if val and val:IsA("StringValue") and val.Value ~= "" then
		return val.Value
	end
	return nil
end

local function getEntityId(model)
	local idAttr = readString(model, "EntityId") or readString(model, "ConfigId")
	if idAttr and idAttr ~= "" then return idAttr end
	local base = model.Name
	local trimmed = base:match("^(.-)_%d+$")
	return trimmed or base
end

local function getEntityType(model)
	local attr = readString(model, "EntityType")
	if attr then return attr end
	if CollectionService:HasTag(model, "Animal") then return "Animal" end
	if CollectionService:HasTag(model, "Monster") then return "Monster" end
	local parent = model.Parent
	if parent and parent.Name == "Animals" then return "Animal" end
	return "Monster"
end

local function loadConfigModule(model)
	local mod = model:FindFirstChild("AIConfig")
	if mod and mod:IsA("ModuleScript") then
		local ok, data = pcall(require, mod)
		if ok and type(data) == "table" then
			return data
		end
	end
	return nil
end

local function findHumanoid(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then return hum end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") then
			return d
		end
	end
	return nil
end

function EntityAIService:_buildConfig(model, entityType)
	local defaults = (EntityConfig.Defaults and EntityConfig.Defaults[entityType]) or {}
	local entityId = getEntityId(model)
	local def = (EntityConfig.Entities and EntityConfig.Entities[entityId]) or nil
	local cfg = shallowMerge(defaults, def and def.AI or nil)
	cfg = shallowMerge(cfg, loadConfigModule(model))
	cfg.EntityId = entityId
	cfg.EntityType = entityType
	if def and def.AIClass then
		cfg.AIClass = def.AIClass
	end

	for _, key in ipairs(NUM_KEYS) do
		local n = readNumber(model, key)
		if n ~= nil then cfg[key] = n end
	end
	for _, key in ipairs(BOOL_KEYS) do
		local b = readBool(model, key)
		if b ~= nil then cfg[key] = b end
	end
	for _, key in ipairs(STRING_KEYS) do
		local s = readString(model, key)
		if s ~= nil then cfg[key] = s end
	end

	return cfg
end

function EntityAIService:_getClass(model, entityType, cfg)
	local className = cfg and cfg.AIClass or readString(model, "AIClass")
	if className then
		local mod = AIFolder:FindFirstChild(className)
		if mod and mod:IsA("ModuleScript") then
			local ok, class = pcall(require, mod)
			if ok and type(class) == "table" and class.new then
				return class
			end
		end
	end
	return (entityType == "Animal") and AnimalClass or MonsterClass
end

function EntityAIService:BindEntity(model, forcedType)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then return end
	if self._entities[model] then return end
	if model:GetAttribute("NoAI") then return end
	if Players:GetPlayerFromCharacter(model) then return end
	local hum = findHumanoid(model)
	if not hum then
		warn("[EntityAIService] No Humanoid found for model:", model:GetFullName())
		return
	end

	local entityType = forcedType or getEntityType(model)
	local entityId = getEntityId(model)
	local def = (EntityConfig.Entities and EntityConfig.Entities[entityId]) or nil
	if def and def.Type then
		entityType = def.Type
	end
	model:SetAttribute("EntityType", entityType)
	local cfg = self:_buildConfig(model, entityType)
	if entityType == "Monster" then
		-- Prefab JumpPower values used to launch creatures far above the terrain.
		hum.UseJumpPower = false
		hum.JumpHeight = 7
		local balance = def and def.StarterBalance
		if balance then
			cfg.Damage = (cfg.Damage or 8) * balance.Damage
			cfg.AttackRange = (cfg.AttackRange or 4) * balance.AttackRange
		end
		local level = tonumber(model:GetAttribute("Level"))
		if not level or level ~= level then
			level = 1 + math.floor(RoundService:GetElapsed() / Progression.SecondsPerMonsterLevel)
		end
		level = math.clamp(math.floor(level), 1, 100)
		model:SetAttribute("Level", level)
		cfg.Damage = (cfg.Damage or 8) * (1 + Progression.DamagePerLevel * (level - 1))
		if not model:GetAttribute("LevelHealthApplied") then
			local fraction = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
			hum.MaxHealth *= 1 + Progression.HealthPerLevel * (level - 1)
			if balance then hum.MaxHealth *= balance.Health end
			hum.Health = hum.MaxHealth * fraction
			model:SetAttribute("LevelHealthApplied", true)
		end
	end
	local class = self:_getClass(model, entityType, cfg)
	local controller = class.new(model, cfg)
	self._entities[model] = controller

	local function cleanup()
		self._entities[model] = nil
	end
	hum.Died:Connect(cleanup)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then cleanup() end
	end)
end

function EntityAIService:_bindFolder(folder, entityType)
	if not folder then return end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			self:BindEntity(child, entityType)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			self:BindEntity(child, entityType)
		end
	end)
end

function EntityAIService:_watchFolder(folderName, entityType)
	local existing = Workspace:FindFirstChild(folderName)
	if existing then
		self:_bindFolder(existing, entityType)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == folderName then
			self:_bindFolder(child, entityType)
		end
	end)
end

function EntityAIService:Init()
	if self._initialized then return end
	self._initialized = true
	self._stepInterval = tonumber(EntityConfig.StepInterval) or self._stepInterval

	-- CollectionService tags
	CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(inst)
		if inst:IsA("Model") then
			self:BindEntity(inst, "Monster")
		end
	end)
	CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(inst)
		if inst:IsA("Model") then
			self:BindEntity(inst, "Animal")
		end
	end)
	for _, inst in ipairs(CollectionService:GetTagged("Monster")) do
		if inst:IsA("Model") then self:BindEntity(inst, "Monster") end
	end
	for _, inst in ipairs(CollectionService:GetTagged("Animal")) do
		if inst:IsA("Model") then self:BindEntity(inst, "Animal") end
	end

	-- Folders
	self:_watchFolder("Enemies", "Monster")
	self:_watchFolder("Animals", "Animal")

	-- Main update loop
	task.spawn(function()
		local last = os.clock()
		while true do
			local now = os.clock()
			local dt = now - last
			last = now
			for model, controller in pairs(self._entities) do
				if controller and controller.IsAlive and controller:IsAlive() then
					if not self._stepping[model] then
						self._stepping[model] = true
						task.spawn(function()
							local ok, err = pcall(function() controller:Step(dt) end)
							self._stepping[model] = nil
							if not ok then
								warn("[EntityAIService] Update failed for " .. model.Name .. ": " .. tostring(err))
							end
						end)
					end
				else
					self._entities[model] = nil
				end
			end
			task.wait(self._stepInterval)
		end
	end)
end

return EntityAIService
