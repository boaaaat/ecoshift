-- SpawnService.lua
-- Resolves what enemies/resources SHOULD spawn; you do the actual prefab placement separately.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local BiomeService = require(script.Parent.BiomeService)
local ThreatService = require(script.Parent.ThreatService)

local SpawnService = {}
SpawnService._enemySpawns = Util.WaitForDescendant(Config.Paths.EnemySpawnsFolder, 5)
SpawnService._resourceFolder = Util.WaitForDescendant(Config.Paths.ResourceNodesFolder, 5)

-- Public: returns a table of "what" to spawn at a given moment
function SpawnService:ComputeEnemyWave()
	local biome = BiomeService:GetCurrent()
	local data = Config.BIOMES[biome]
	if not data then return {} end

	-- choose table(s)
	local tables = {}
	for _,tName in ipairs(data.enemyTables or {}) do
		local t = EntityConfig.EnemyWaves and EntityConfig.EnemyWaves.Tables and EntityConfig.EnemyWaves.Tables[tName]
		if t then table.insert(tables, t) end
	end

	if #tables == 0 then return {} end
	-- build a bag
	local bag = {}
	for _,t in ipairs(tables) do
		for _,entry in ipairs(t) do table.insert(bag, entry) end
	end

	local threat = ThreatService:Get() -- 0..10
	local plrCount = #Players:GetPlayers()
	local waves = EntityConfig.EnemyWaves or {}
	local baseCount = math.clamp(
		math.floor((waves.BaseCount or 2) + threat + (plrCount * (waves.PlayerScale or 1))),
		waves.BaseCount or 2,
		waves.MaxCount or 24
	)
	local mods = (_G.Ecoshift and _G.Ecoshift.Mods) or {}
	local mult = mods.EnemyMultiplier or 1.0
	baseCount = math.clamp(math.floor(baseCount * mult), waves.BaseCount or 2, waves.MaxCount or 24)

	local result = {}
	for i=1, baseCount do
		local pick = Util.ChooseWeighted(bag, "Weight")
		table.insert(result, pick and pick.Id or "Wolf")
	end
	
	print("[SpawnService] Computed wave for biome '"..biome.."' with enemies:", table.concat(result, ", "))

	return result
end

-- Public: returns candidate resource tags to enable/boost
function SpawnService:GetActiveResourceTags()
	local biomeData = BiomeService:GetData()
	return (biomeData and biomeData.resourceTags) or {}
end

-- Helper for external AI spawner to pick spawnpoints (you place them)
function SpawnService:GetSpawnPoints()
	local folder = self._enemySpawns
	if not folder then return {} end
	local points = {}
	for _,child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Attachment") then
			table.insert(points, child)
		end
	end
	return points
end

return SpawnService
