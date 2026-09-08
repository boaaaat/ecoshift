-- ServerMain.server.lua
-- Boots core services in tiers and exposes global gameplay helpers.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Services = script.Parent.Services
-- Expeditions admit/load characters only after their reservation, saved world
-- and gameplay services are ready. The lobby keeps normal Roblox autoload.
ReplicatedStorage:SetAttribute("ServerBootState", "Preparing")
local failed = false
local function failBoot(err)
	if failed then return end
	failed = true
	Players.CharacterAutoLoads = false
	ReplicatedStorage:SetAttribute("WorldRestoring", true)
	ReplicatedStorage:SetAttribute("ServerBootState", "Failed")
	ReplicatedStorage:SetAttribute("ServerBootError", string.sub(tostring(err), 1, 1000))
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then player.Character:Destroy() end end
	warn("[ServerMain] Expedition initialization stopped: " .. tostring(err))
end

local _services = {}
local function getService(name)
	if not _services[name] then
		local module = Services:FindFirstChild(name)
		assert(module, "Missing service module: " .. name)
		_services[name] = require(module)
	end
	return _services[name]
end

-- TIER 1: Critical services needed immediately (parallel load)
local tier1Services = {
	"BiomeService",
	"GameStateService",
	"RoleService",
	"ProfileService",
}

-- TIER 2: Services needed for gameplay but can load after tier 1
local tier2Services = {
	{ name = "PartyService", method = "Init" },
	{ name = "LobbyService", method = "Init" },
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
	{ name = "InventoryService", method = "Init" },
	{ name = "InventoryActionService", method = "Init" },
	{ name = "ToolService", method = "Init" },
	{ name = "ArmorService", method = "Init" },
	{ name = "DayNightService", method = "Init" },
	{ name = "CraftingService", method = "Init" },
	{ name = "WorldControlService", method = "Init" },
	{ name = "LootService", method = "Init" },
	{ name = "RewardsObserver", method = "Init" },
	{ name = "EntityAIService", method = "Init" },
}

-- TIER 3: Deferred/heavy services (world gen, etc.)
local tier3Services = {
	{ name = "ChunkStreamingService", method = "Init" },
	{ name = "WorldGenController", method = "Init" },
	{ name = "WorldBuilder", method = "Init" },
	{ name = "ObjectiveBootstrap", method = "Init" },
	{ name = "EnemySpawner", method = "Init" },
	{ name = "SpawnerOrchestrator", method = "Bind" },
	{ name = "GameLoopService", method = "Init" },
	{ name = "ObjectiveRuntimeService", method = "Init" },
}

-- Initialize services in parallel batches
local function initTier(services, initMethod)
	local remaining, errors = 0, {}
	for _, entry in ipairs(services) do
		local name = type(entry) == "string" and entry or entry.name
		local method = type(entry) == "table" and entry.method or initMethod
		remaining += 1
		task.spawn(function()
			local ok, err = pcall(function()
				local svc = getService(name)
				assert(svc and method and type(svc[method]) == "function", name .. " has no startup method " .. tostring(method))
				local success, reason = svc[method](svc)
				assert(success ~= false, name .. " startup rejected: " .. tostring(reason))
			end)
			if not ok then
				table.insert(errors, name .. ": " .. tostring(err))
			end
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 60
	while remaining > 0 do
		assert(os.clock() < deadline, "Service startup timed out")
		task.wait()
	end
	table.sort(errors)
	assert(#errors == 0, "Service startup failed: " .. table.concat(errors, " | "))
end

local function boot()
	local SessionConfig = require(ReplicatedStorage.Shared.SessionConfig)
	local mode = SessionConfig.GetMode()
	if mode ~= "Lobby" then Players.CharacterAutoLoads = false end
	ReplicatedStorage:SetAttribute("PlaceMode", mode)
	require(script.Parent:WaitForChild("RuntimeBootstrap")):Init()
	if mode == "Lobby" then
		Players.CharacterAutoLoads = true
		require(script.Parent.LobbyBootstrap):Init()
		ReplicatedStorage:SetAttribute("ServerBootState", "Ready")
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then player.Character:Destroy() end end
	-- Must precede every gameplay require, including WorldSession dependencies:
	-- departure capture needs to observe inventories before their cleanup handlers.
	local snapshots = getService("WorldSnapshotService")
	local sessionModule = Services:FindFirstChild("WorldSessionService")
	local session, saved
	if sessionModule then
		session = getService("WorldSessionService")
		assert(type(session.PrepareExpedition) == "function" and type(session.StartExpedition) == "function", "WorldSessionService lifecycle API is incomplete")
		local prepared, snapshotOrReason = session:PrepareExpedition()
		assert(prepared == true, "Expedition admission failed: " .. tostring(snapshotOrReason))
		saved = snapshotOrReason
	else
		assert(RunService:IsStudio(), "Published expeditions require WorldSessionService admission and persistence")
	end
	snapshots:StageWorld(saved)
	-- Supply art before tools/streaming initialize their prefab caches.
	getService("PrototypePrefabService"):Init()
	StarterPlayer.EnableMouseLockOption = false
	ReplicatedStorage:SetAttribute("ServerBootState", "LoadingServices")
	if Services:FindFirstChild("ExpeditionRewardsService") then
		table.insert(tier2Services, { name = "ExpeditionRewardsService", method = "Init" })
	end
	initTier(tier1Services, "Init")
	initTier(tier2Services)
	snapshots:RestoreWorld()
	ReplicatedStorage:SetAttribute("ServerBootState", "GeneratingWorld")
	initTier(tier3Services)
	local generator, deadline = getService("WorldGenController"), os.clock() + 90
	while true do
		local generated = workspace:FindFirstChild("GeneratedWorld")
		if generated and generated:GetAttribute("Generated") == true and not generator._busy then break end
		assert(os.clock() < deadline, "World terrain generation did not complete")
		task.wait(0.1)
	end
	snapshots:CompleteWorldRestore()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.ComputeEnemyWave = function() return getService("SpawnService"):ComputeEnemyWave() end
	_G.Ecoshift.GetActiveResourceTags = function() return getService("SpawnService"):GetActiveResourceTags() end
	_G.Ecoshift.AIService = setmetatable({}, { __index = function(_, k) return getService("AIService")[k] end })
	if type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
		_G.Ecoshift.OnBiomeChangedAdd(function(cur)
			local builds = getService("BuildService")
			if builds.OnBiomeChanged then builds:OnBiomeChanged(cur) end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		task.defer(function() if player.Parent == Players then getService("BiomeService"):SendToPlayer(player) end end)
	end)
	ReplicatedStorage:SetAttribute("ServerBootState", "LoadingCrew")
	if session then
		local started, reason = session:StartExpedition(snapshots)
		assert(started == true, "World session activation failed: " .. tostring(reason))
	else
		-- Standalone Studio authoring fallback. Production always uses the session
		-- admission handler, which owns rejoin, private roster and save lifecycle.
		local loading = {}
		local function spawnStudioPlayer(player)
			if loading[player] or player.Parent ~= Players or failed then return end
			loading[player] = true
			local ok, err = xpcall(function()
				local profiles, expires = getService("ProfileService"), os.clock() + 60
				while player.Parent == Players and not profiles:IsLoaded(player) do
					assert(os.clock() < expires, "Studio player profile did not load")
					task.wait(0.1)
				end
				if player.Parent ~= Players or failed then return end
				player:LoadCharacterAsync()
				if player.Parent ~= Players then return end
				local char = assert(player.Character, "Studio character failed to load")
				assert(char:WaitForChild("Humanoid", 10), "Studio character has no Humanoid")
				snapshots:RestorePlayer(player)
			end, debug.traceback)
			loading[player] = nil
			if not ok then failBoot(err) end
		end
		Players.PlayerAdded:Connect(function(player) task.spawn(spawnStudioPlayer, player) end)
		for _, player in ipairs(Players:GetPlayers()) do spawnStudioPlayer(player) end
	end
	if not failed then ReplicatedStorage:SetAttribute("ServerBootState", "Ready") end
end

local ok, err = xpcall(boot, debug.traceback)
if not ok then failBoot(err) end
