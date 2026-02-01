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

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function distFactor(dist, cfg)
	local minR = tonumber(cfg.MinRadius) or 0
	local maxR = tonumber(cfg.MaxRadius) or 0
	if maxR <= minR then return 0 end
	local t = math.clamp((dist - minR) / (maxR - minR), 0, 1)
	local exp = tonumber(cfg.Exponent) or 1
	if exp ~= 1 then
		t = t ^ exp
	end
	return t
end

local function ensureSpawnPoints(folder)
	if not folder then return end
	if #folder:GetChildren() > 0 then return end

	local cfg = EntityConfig.SpawnPoints or {}
	local world = Config.WORLD or {}
	local count = math.max(1, tonumber(cfg.Count) or 24)
	local minPad = tonumber(cfg.MinRadiusPadding) or 40
	local maxPad = tonumber(cfg.MaxRadiusPadding) or 40
	local minR = tonumber(cfg.MinRadius) or ((world.CenterExclusionRadius or 0) + minPad)
	local maxR = tonumber(cfg.MaxRadius) or ((world.WorldRadius or 2000) - maxPad)
	if maxR <= minR then
		maxR = minR + 10
	end
	local baseY = tonumber(world.BaseY) or 0
	local rng = Random.new()

	for i = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minR, maxR)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local part = Instance.new("Part")
		part.Name = "SpawnPoint_" .. tostring(i)
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(x, baseY + 2, z)
		part.Parent = folder
	end
end

-- Public: returns a table of "what" to spawn at a given moment
function SpawnService:ComputeEnemyWave()
	local biome = BiomeService:GetCurrent()
	local data = Config.BIOMES[biome]
	if not data then return {} end

	local waves = EntityConfig.EnemyWaves or {}
	local distanceCfg = waves.Distance or {}
	local world = Config.WORLD or {}
	local sample = tostring(waves.DistanceSample or "Max"):lower()
	local distValues = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = Vector3.new(hrp.Position.X, 0, hrp.Position.Z).Magnitude
			distValues[#distValues + 1] = d
		end
	end
	local dist = 0
	if #distValues > 0 then
		if sample == "average" then
			local sum = 0
			for _, v in ipairs(distValues) do sum += v end
			dist = sum / #distValues
		elseif sample == "min" then
			dist = math.huge
			for _, v in ipairs(distValues) do if v < dist then dist = v end end
			if dist == math.huge then dist = 0 end
		else
			dist = 0
			for _, v in ipairs(distValues) do if v > dist then dist = v end end
		end
	end
	if not distanceCfg.MinRadius then
		distanceCfg.MinRadius = tonumber(world.CenterExclusionRadius) or 0
	end
	if not distanceCfg.MaxRadius then
		distanceCfg.MaxRadius = tonumber(world.WorldRadius) or 2000
	end
	local distT = distFactor(dist, distanceCfg)
	local globalWeightMult = lerp(tonumber(distanceCfg.WeightMultMin) or 1, tonumber(distanceCfg.WeightMultMax) or 1, distT)

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
		for _,entry in ipairs(t) do
			local weight = tonumber(entry.Weight or entry.weight) or 1
			weight = weight * globalWeightMult
			local minD = tonumber(entry.MinDistance)
			local maxD = tonumber(entry.MaxDistance)
			if minD and dist < minD then
				continue
			end
			if maxD and dist > maxD then
				continue
			end
			local dW = entry.DistanceWeight or entry.DistanceWeightMult
			if type(dW) == "table" then
				local dwMin = tonumber(dW.Min) or tonumber(dW.min) or 1
				local dwMax = tonumber(dW.Max) or tonumber(dW.max) or 1
				weight = weight * lerp(dwMin, dwMax, distT)
			elseif type(dW) == "number" then
				weight = weight * dW
			end
			if weight > 0 then
				local copy = {}
				for k, v in pairs(entry) do copy[k] = v end
				copy.Weight = weight
				table.insert(bag, copy)
			end
		end
	end

	local threat = ThreatService:Get() -- 0..10
	local plrCount = #Players:GetPlayers()
	local baseCount = math.clamp(
		math.floor((waves.BaseCount or 2) + threat + (plrCount * (waves.PlayerScale or 1))),
		waves.MinCount or (waves.BaseCount or 2),
		waves.MaxCount or 24
	)
	local mods = (_G.Ecoshift and _G.Ecoshift.Mods) or {}
	local mult = mods.EnemyMultiplier or 1.0
	local countMult = lerp(tonumber(distanceCfg.CountMultMin) or 1, tonumber(distanceCfg.CountMultMax) or 1, distT)
	baseCount = math.clamp(math.floor(baseCount * mult * countMult), waves.MinCount or (waves.BaseCount or 2), waves.MaxCount or 24)

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
	ensureSpawnPoints(folder)
	local points = {}
	for _,child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Attachment") then
			table.insert(points, child)
		end
	end
	return points
end

return SpawnService
