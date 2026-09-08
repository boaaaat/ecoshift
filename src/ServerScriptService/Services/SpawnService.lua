-- SpawnService.lua
-- Resolves what enemies/resources SHOULD spawn; you do the actual prefab placement separately.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local BiomeService = require(script.Parent.BiomeService)
local ThreatService = require(script.Parent.ThreatService)

local SpawnService = {}
SpawnService._enemySpawns = Util.WaitForDescendant(Config.Paths.EnemySpawnsFolder, 5)

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

local function distanceWeightFactor(weight, t)
	if t == nil then
		return 1
	end
	if type(weight) == "table" then
		local min = tonumber(weight.Min or weight.min) or 1
		local max = tonumber(weight.Max or weight.max) or 1
		return math.max(0, lerp(min, max, t))
	end
	if weight == nil then
		return 1
	end
	local w = tonumber(weight) or 1
	return math.max(0, lerp(1, w, t))
end

local function resolveGroupSize(groupSize)
	if type(groupSize) == "table" then
		local min = tonumber(groupSize.min or groupSize.Min) or 1
		local max = tonumber(groupSize.max or groupSize.Max) or min
		if max < min then max = min end
		return math.random(min, max)
	end
	if type(groupSize) == "number" then
		return math.max(1, math.floor(groupSize))
	end
	return 1
end

local function mergeSpawnEntry(base, extra)
	if not extra then return base end
	for _, key in ipairs({
		"DistanceWeight", "distanceWeight", "DistanceWeightMult", "distanceWeightMult",
		"MinDistance", "minDistance",
		"MaxDistance", "maxDistance",
		"MinPlayerDistance", "minPlayerDistance",
		"MaxPlayerDistance", "maxPlayerDistance",
		"GroupSize", "groupSize",
		"GroupRadius", "groupRadius",
		"MaxPerWave", "MaxCountPerWave", "maxPerWave", "maxCountPerWave",
	}) do
		if extra[key] ~= nil then
			base[key] = extra[key]
		end
	end
	if extra.Weight ~= nil or extra.weight ~= nil then
		local w = tonumber(extra.Weight or extra.weight) or 1
		if base.BaseWeight ~= nil then
			base.BaseWeight = base.BaseWeight * w
		else
			base.BaseWeight = w
		end
	end
	if extra.TimeScaledWeight ~= nil or extra.timeScaledWeight ~= nil then
		local ts = tonumber(extra.TimeScaledWeight or extra.timeScaledWeight) or 0
		base.TimeScaledWeight = (base.TimeScaledWeight or 0) + ts
	end
	return base
end

local function ensureSpawnPoints(folder)
	if not folder then return end
	if #folder:GetChildren() > 0 then return end

	local cfg = EntityConfig.SpawnPoints or {}
	local world = BiomeConfig.WORLD or {}
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

-- Public: returns spawn requests { Id, Count, GroupRadius, MinPlayerDistance, MaxPlayerDistance }
function SpawnService:ComputeEnemyWave()
	local biome = BiomeService:GetCurrent()
	local data = BiomeConfig.BIOMES[biome]
	if not data then return {} end

	local waves = EntityConfig.EnemyWaves or {}
	local distanceCfg = waves.Distance or {}
	local world = BiomeConfig.WORLD or {}
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

	local entriesById = {}
	local useEntitySpawn = waves.UseEntitySpawnConfig ~= false
	if useEntitySpawn then
		local entities = EntityConfig.Entities or {}
		local typeWeights = EntityConfig.TypeWeights or {}
		for id, def in pairs(entities) do
			local spawn = def.Spawn
			local biomeDef = spawn and spawn.Biomes and spawn.Biomes[biome]
			if spawn and biomeDef then
				local entry = {
					Id = id,
					BaseWeight = tonumber(spawn.Weight or spawn.weight) or 1,
					TimeScaledWeight = tonumber(spawn.TimeScaledWeight or spawn.timeScaledWeight) or 0,
					DistanceWeight = spawn.DistanceWeight or spawn.distanceWeight,
					MinDistance = spawn.MinDistance or spawn.minDistance,
					MaxDistance = spawn.MaxDistance or spawn.maxDistance,
					MinPlayerDistance = spawn.MinPlayerDistance or spawn.minPlayerDistance,
					MaxPlayerDistance = spawn.MaxPlayerDistance or spawn.maxPlayerDistance,
					GroupSize = spawn.GroupSize or spawn.groupSize,
					GroupRadius = spawn.GroupRadius or spawn.groupRadius,
					MaxPerWave = spawn.MaxPerWave or spawn.maxPerWave or spawn.MaxCountPerWave or spawn.maxCountPerWave,
				}
				local biomeWeight = tonumber(biomeDef.Weight or biomeDef.weight) or 1
				entry.BaseWeight = entry.BaseWeight * biomeWeight
				if biomeDef.DistanceWeight or biomeDef.distanceWeight then
					entry.DistanceWeight = biomeDef.DistanceWeight or biomeDef.distanceWeight
				end
				if biomeDef.MinDistance or biomeDef.minDistance then
					entry.MinDistance = biomeDef.MinDistance or biomeDef.minDistance
				end
				if biomeDef.MaxDistance or biomeDef.maxDistance then
					entry.MaxDistance = biomeDef.MaxDistance or biomeDef.maxDistance
				end
				local typeWeight = tonumber(typeWeights[def.Type or def.EntityType or "Monster"]) or 1
				entry.BaseWeight = entry.BaseWeight * typeWeight
				entriesById[id] = entry
			end
		end
	end

	for _,t in ipairs(tables) do
		for _,entry in ipairs(t) do
			local id = entry.Id or entry.id
			if id then
				local base = entriesById[id] or { Id = id }
				base = mergeSpawnEntry(base, entry)
				entriesById[id] = base
			end
		end
	end

	if next(entriesById) == nil then
		return {}
	end

	-- build a bag
	local bag = {}
	local elapsed = BiomeService:GetElapsed()
	local timeScale = tonumber(waves.TimeScaleSeconds) or tonumber(BiomeConfig.time_scale_seconds) or 900
	for _,entry in pairs(entriesById) do
		local baseWeight = tonumber(entry.BaseWeight) or 1
		local scaled = tonumber(entry.TimeScaledWeight) or 0
		local weight = baseWeight + (scaled * (elapsed / math.max(timeScale, 1)))
		weight = math.max(0, weight) * globalWeightMult
		local minD = tonumber(entry.MinDistance)
		local maxD = tonumber(entry.MaxDistance)
		if minD and dist < minD then
			continue
		end
		if maxD and dist > maxD then
			continue
		end
		weight = weight * distanceWeightFactor(entry.DistanceWeight, distT)
		if weight > 0 then
			local copy = {}
			for k, v in pairs(entry) do copy[k] = v end
			copy.Weight = weight
			table.insert(bag, copy)
		end
	end

	if #bag == 0 then
		return {}
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
	local perId = {}
	local remaining = baseCount
	local attempts = 0
	local maxAttempts = math.max(baseCount * 6, 12)
	while remaining > 0 and attempts < maxAttempts do
		local pick = Util.ChooseWeighted(bag, "Weight")
		if not pick then break end
		local id = pick.Id or pick.id
		if not id then break end
		local maxPerWave = tonumber(pick.MaxPerWave or pick.MaxCountPerWave or pick.maxPerWave or pick.maxCountPerWave)
		local current = perId[id] or 0
		if maxPerWave and current >= maxPerWave then
			attempts += 1
			continue
		end
		local groupSize = resolveGroupSize(pick.GroupSize or pick.groupSize)
		if maxPerWave then
			groupSize = math.min(groupSize, maxPerWave - current)
		end
		groupSize = math.min(groupSize, remaining)
		if groupSize <= 0 then
			attempts += 1
			continue
		end
		table.insert(result, {
			Id = id,
			Count = groupSize,
			GroupRadius = pick.GroupRadius or pick.groupRadius,
			MinPlayerDistance = pick.MinPlayerDistance or pick.minPlayerDistance,
			MaxPlayerDistance = pick.MaxPlayerDistance or pick.maxPlayerDistance,
		})
		perId[id] = current + groupSize
		remaining -= groupSize
		attempts += 1
	end

	local summary = {}
	for _, entry in ipairs(result) do
		summary[#summary + 1] = tostring(entry.Id) .. "x" .. tostring(entry.Count or 1)
	end
	print("[SpawnService] Computed wave for biome '"..biome.."' with enemies:", table.concat(summary, ", "))

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
