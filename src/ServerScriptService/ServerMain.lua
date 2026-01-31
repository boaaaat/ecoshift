-- ServerMain.server.lua
-- OPTIMIZED: Parallel initialization with priority tiers
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Lazy-load services to avoid blocking at require time
local Services = script.Parent.Services
local function lazyRequire(name)
	return function()
		return require(Services:FindFirstChild(name))
	end
end

-- Service references (loaded on-demand)
local _services = {}
local function getService(name)
	if not _services[name] then
		_services[name] = require(Services:FindFirstChild(name))
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
	{ name = "CombatService", method = "Bind" },
	{ name = "BuildService", method = "Bind" },
	{ name = "InteractService", method = "Bind" },
	{ name = "StatusService", method = "Bind" },
	{ name = "RoundService", method = "Bind" },
	{ name = "DropItemService", method = "Init" },
	{ name = "InventoryActionService", method = "Init" },
	{ name = "ToolService", method = "Init" },
	{ name = "ArmorService", method = "Init" },
	{ name = "DayNightService", method = "Init" },
	{ name = "CraftingService", method = "Init" },
	{ name = "LootService", method = "Init" },
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
	local threads = {}
	for _, entry in ipairs(services) do
		local name = type(entry) == "string" and entry or entry.name
		local method = type(entry) == "table" and entry.method or initMethod
		threads[#threads + 1] = task.spawn(function()
			local ok, err = pcall(function()
				local svc = getService(name)
				if svc and method and svc[method] then
					svc[method](svc)
				end
			end)
			if not ok then
				warn("[ServerMain] Failed to init " .. name .. ": " .. tostring(err))
			end
		end)
	end
	-- Wait for all tier threads
	for _, t in ipairs(threads) do
		if coroutine.status(t) ~= "dead" then
			task.wait()
		end
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
	if _G.Ecoshift and type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
		_G.Ecoshift.OnBiomeChangedAdd(function(cur)
			pcall(function() 
				local BuildService = getService("BuildService")
				BuildService:OnBiomeChanged(cur) 
			end)
		end)
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
