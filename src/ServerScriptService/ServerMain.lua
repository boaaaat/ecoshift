-- ServerMain.server.lua
-- Boots core services in tiers and exposes global gameplay helpers.
local Players = game:GetService("Players")

local Services = script.Parent.Services

local _services = {}
local function getService(name)
	if not _services[name] then
		local module = Services:FindFirstChild(name)
		if not module then
			warn("[ServerMain] Missing service module:", name)
			return nil
		end
		_services[name] = require(module)
	end
	return _services[name]
end

-- TIER 1: Critical services needed immediately (parallel load)
local tier1Services = {
	"BiomeService",
	"GameStateService",
	"RoleService",
}

-- TIER 2: Services needed for gameplay but can load after tier 1
local tier2Services = {
	{ name = "ObjectiveService", method = "Init" },
	{ name = "EventService", method = "Init" },
	{ name = "EventEffectsService", method = "Init" },
	{ name = "StatsService", method = "Init" },
	{ name = "CombatService", method = "Bind" },
	{ name = "DeathService", method = "Init" },
	{ name = "BuildService", method = "Bind" },
	{ name = "InteractService", method = "Bind" },
	{ name = "StatusService", method = "Bind" },
	{ name = "SurvivalService", method = "Init" },
	{ name = "RoundService", method = "Bind" },
	{ name = "DropItemService", method = "Init" },
	{ name = "InventoryActionService", method = "Init" },
	{ name = "ToolService", method = "Init" },
	{ name = "ArmorService", method = "Init" },
	{ name = "DayNightService", method = "Init" },
	{ name = "CraftingService", method = "Init" },
	{ name = "LootService", method = "Init" },
	{ name = "RewardsObserver", method = "Init" },
	{ name = "EntityAIService", method = "Init" },
}

-- TIER 3: Deferred/heavy services (world gen, etc.)
local tier3Services = {
	{ name = "WorldGenController", method = "Init" },
	{ name = "SpawnerOrchestrator", method = "Bind" },
	{ name = "GameLoopService", method = "Init" },
	{ name = "ObjectiveRuntimeService", method = "Init" },
}

-- Initialize services in parallel batches
local function initTier(services, initMethod)
	local remaining = 0
	for _, entry in ipairs(services) do
		local name = type(entry) == "string" and entry or entry.name
		local method = type(entry) == "table" and entry.method or initMethod
		remaining += 1
		task.spawn(function()
			local ok, err = pcall(function()
				print("[ServerMain] Loading service:", name)
				local svc = getService(name)
				if svc and method and svc[method] then
					print("[ServerMain] Calling", name .. ":" .. method .. "()")
					svc[method](svc)
				else
					warn("[ServerMain] Service", name, "missing or no method", method)
				end
			end)
			if not ok then
				warn("[ServerMain] Failed to init " .. name .. ": " .. tostring(err))
			end
			remaining -= 1
		end)
	end
	while remaining > 0 do
		task.wait()
	end
end

-- TIER 1: Critical (parallel)
initTier(tier1Services, "Init")

-- TIER 2: Gameplay services (parallel, after tier 1)
task.defer(function()
	initTier(tier2Services)
end)

-- TIER 3: Heavy/deferred (run after a short delay to let client connect)
task.delay(0.1, function()
	initTier(tier3Services)
end)

-- Relay biome changes to BuildService for global Decay pass
Players.PlayerAdded:Connect(function(plr)
	task.defer(function()
		local BiomeService = getService("BiomeService")
		BiomeService:SendToPlayer(plr)
	end)
end)

-- Biome change hook for Decay (deferred setup)
task.defer(function()
	for _ = 1, 50 do
		if _G.Ecoshift and type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
			_G.Ecoshift.OnBiomeChangedAdd(function(cur)
				pcall(function()
					local BuildService = getService("BuildService")
					if BuildService and BuildService.OnBiomeChanged then
						BuildService:OnBiomeChanged(cur)
					end
				end)
			end)
			break
		end
		task.wait(0.1)
	end
end)

-- Expose global API (lazy)
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.ComputeEnemyWave = function() 
	return getService("SpawnService"):ComputeEnemyWave() 
end
_G.Ecoshift.GetActiveResourceTags = function() 
	return getService("SpawnService"):GetActiveResourceTags() 
end
_G.Ecoshift.AIService = setmetatable({}, {
	__index = function(_, k)
		return getService("AIService")[k]
	end
})
