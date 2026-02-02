-- EnemySpawner.server.lua
-- Uses the orchestrator's callback to request actual spawns.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local BiomeService = require(script.Parent.BiomeService)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)

local function withinPlayerDistance(point, minDist, maxDist)
	local p = point:IsA("Attachment") and point.WorldPosition or point.Position
	local nearest = math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local dist = (root.Position - p).Magnitude
			if minDist and dist < minDist then
				return false
			end
			if dist < nearest then
				nearest = dist
			end
		end
	end
	if maxDist and nearest ~= math.huge and nearest > maxDist then
		return false
	end
	return true
end

local function pickPoint(points, minDist, maxDist)
	if #points == 0 then return nil end
	local shuffled = table.clone(points)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for _, pt in ipairs(shuffled) do
		if withinPlayerDistance(pt, minDist, maxDist) then
			return pt
		end
	end
	return shuffled[1]
end

local function findPrefabInFolder(root, biomeName, id)
	if not root then return nil end
	if biomeName then
		local biomeFolder = root:FindFirstChild(biomeName)
		local prefab = biomeFolder and biomeFolder:FindFirstChild(id)
		if prefab then return prefab end
	end
	for _, biomeFolder in ipairs(root:GetChildren()) do
		if biomeFolder:IsA("Folder") then
			local prefab = biomeFolder:FindFirstChild(id)
			if prefab then return prefab end
		end
	end
	return root:FindFirstChild(id)
end

local function resolvePrefab(prefab, id)
	if not prefab then return nil end
	if prefab:IsA("Folder") then
		local direct = id and prefab:FindFirstChild(id)
		if direct then return direct end
		local model = prefab:FindFirstChildWhichIsA("Model", true)
		if model then return model end
		return prefab:FindFirstChildWhichIsA("BasePart", true)
	end
	return prefab
end

local function getEnemyPrefab(id)
	local biomeName = BiomeService:GetCurrent()
	local biomeRoot = ServerStorage:FindFirstChild("EnemyPrefabs")
	local fallbackRoot = ServerStorage:FindFirstChild("Enemies")
	local prefab = findPrefabInFolder(biomeRoot, biomeName, id)
	if prefab then return prefab end
	return findPrefabInFolder(fallbackRoot, biomeName, id)
end

local function getSafeSpawnPosition(originPosition)
	local rayOrigin = originPosition + Vector3.new(0, 200, 0)
	local rayDirection = Vector3.new(0, -300, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		ServerStorage:FindFirstChild("Enemies"),
		ServerStorage:FindFirstChild("EnemyPrefabs"),
	}
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local groundPosition = result and result.Position or originPosition
	return CFrame.new(groundPosition + Vector3.new(0, 10, 0))
end

local function getSpawnConfig(id)
	local def = EntityConfig.Entities and EntityConfig.Entities[id]
	return def and def.Spawn or nil
end

local function randomOffset(radius)
	if not radius or radius <= 0 then
		return Vector3.new()
	end
	local angle = math.random() * math.pi * 2
	local dist = math.sqrt(math.random()) * radius
	return Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function normalizeSpawnRequest(entry)
	local id = nil
	local count = 1
	local groupRadius = 0
	local minPlayerDist = nil
	local maxPlayerDist = nil

	if type(entry) == "table" then
		id = entry.Id or entry.id
		count = tonumber(entry.Count or entry.N or 1) or 1
		groupRadius = tonumber(entry.GroupRadius or entry.groupRadius) or 0
		minPlayerDist = entry.MinPlayerDistance or entry.minPlayerDistance
		maxPlayerDist = entry.MaxPlayerDistance or entry.maxPlayerDistance
	elseif type(entry) == "string" then
		id = entry
	end

	if not id then return nil end

	local spawn = getSpawnConfig(id)
	if spawn then
		if groupRadius == 0 then
			groupRadius = tonumber(spawn.GroupRadius or spawn.groupRadius) or 0
		end
		if not minPlayerDist then
			minPlayerDist = spawn.MinPlayerDistance or spawn.minPlayerDistance
		end
		if not maxPlayerDist then
			maxPlayerDist = spawn.MaxPlayerDistance or spawn.maxPlayerDistance
		end
	end

	local waves = EntityConfig.EnemyWaves or {}
	if not minPlayerDist then
		minPlayerDist = waves.SpawnPointMinDistance or 60
	end
	if not maxPlayerDist then
		maxPlayerDist = waves.SpawnPointMaxDistance
	end

	return {
		Id = id,
		Count = math.max(1, math.floor(count)),
		GroupRadius = groupRadius,
		MinPlayerDistance = minPlayerDist,
		MaxPlayerDistance = maxPlayerDist,
	}
end

local function spawnGroup(id, anchor, count, radius, playerCount)
	local basePos = getAnchorPosition(anchor)
	if not basePos then
		return
	end
	for _ = 1, count do
		local offset = randomOffset(radius)
		spawnEnemyById(id, basePos + offset, playerCount)
	end
end

local function getModelRoot(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function applyEntityTags(model, entityType)
	if entityType == "Animal" then
		CollectionService:AddTag(model, "Animal")
	else
		CollectionService:AddTag(model, "Monster")
	end
end

local function copyTags(fromInst, toInst)
	if not fromInst or not toInst then return end
	for _, tag in ipairs(CollectionService:GetTags(fromInst)) do
		CollectionService:AddTag(toInst, tag)
	end
end

local function applyHealthScaling(model, playerCount)
	local healthValue = model:FindFirstChild("Health")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if healthValue and humanoid then
		local baseHp = humanoid.MaxHealth
		local scaledHp = baseHp * (1 + (playerCount - 1) * 0.25)
		local nightMult = (_G.Ecoshift and _G.Ecoshift.GetEnemyMultiplier) and _G.Ecoshift.GetEnemyMultiplier() or 1
		scaledHp = scaledHp * nightMult
		healthValue.Value = scaledHp
		humanoid.Health = scaledHp
	end
end

local function ensureEnemiesFolder()
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		enemiesFolder = Instance.new("Folder")
		enemiesFolder.Name = "Enemies"
		enemiesFolder.Parent = Workspace
	end
	return enemiesFolder
end

local function getAnchorPosition(anchor)
	if typeof(anchor) == "Vector3" then
		return anchor
	end
	if typeof(anchor) == "CFrame" then
		return anchor.Position
	end
	if anchor and anchor.IsA and anchor:IsA("Attachment") then
		return anchor.WorldPosition
	end
	if anchor and anchor.Position then
		return anchor.Position
	end
	return nil
end

local function spawnEnemyById(id, anchor, playerCount)
	local prefab = resolvePrefab(getEnemyPrefab(id), id)
	if not prefab then
		warn("[EnemySpawner] Missing prefab for", id)
		return
	end

	local anchorPos = getAnchorPosition(anchor)
	if not anchorPos then
		warn("[EnemySpawner] Spawn point has no position", anchor and anchor:GetFullName() or "nil")
		return
	end

	local newEnemy = prefab:Clone()
	if newEnemy:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		wrapper.Name = newEnemy.Name
		newEnemy.Parent = wrapper
		wrapper.PrimaryPart = newEnemy
		newEnemy = wrapper
	end
	if not newEnemy:IsA("Model") then
		warn("[EnemySpawner] Prefab is not a Model:", newEnemy.ClassName, id)
		return
	end

	newEnemy.Name = id .. "_" .. math.random(1000, 9999)
	newEnemy:SetAttribute("EntityId", id)
	local entityType = newEnemy:GetAttribute("EntityType") or prefab:GetAttribute("EntityType") or "Monster"
	newEnemy:SetAttribute("EntityType", entityType)

	copyTags(prefab, newEnemy)

	for _, part in ipairs(newEnemy:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
		end
	end

	local safeCFrame = getSafeSpawnPosition(anchorPos)
	local rootPart = getModelRoot(newEnemy)
	if not rootPart then
		warn("[EnemySpawner] Prefab has no BasePart:", id)
		return
	end
	if not newEnemy.PrimaryPart then
		newEnemy.PrimaryPart = rootPart
	end
	newEnemy:PivotTo(safeCFrame)

	newEnemy.Parent = ensureEnemiesFolder()
	applyEntityTags(newEnemy, entityType)
	if rootPart then
		rootPart:SetNetworkOwner(nil)
	end
	applyHealthScaling(newEnemy, playerCount or math.max(1, #Players:GetPlayers()))
end

local function bindSpawnerCallback()
	while not (_G.Ecoshift and _G.Ecoshift.SetEnemySpawnCallback) do
		task.wait(0.1)
	end

	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.SetEnemySpawnCallback(function(ids, points)
		if #ids == 0 or #points == 0 then return end
		local requests = {}
		for _, entry in ipairs(ids) do
			local req = normalizeSpawnRequest(entry)
			if req then
				table.insert(requests, req)
			end
		end
		if #requests == 0 then return end
		local summary = {}
		for _, req in ipairs(requests) do
			summary[#summary + 1] = tostring(req.Id) .. "x" .. tostring(req.Count or 1)
		end
		print("[EnemySpawner] Spawning wave with enemies:", table.concat(summary, ", "))
		local playerCount = math.max(1, #Players:GetPlayers())
		for _, req in ipairs(requests) do
			local pt = pickPoint(points, req.MinPlayerDistance, req.MaxPlayerDistance)
			local ok, err = pcall(spawnGroup, req.Id, pt, req.Count or 1, req.GroupRadius or 0, playerCount)
			if not ok then
				warn("[EnemySpawner] Spawn failed for", req.Id, "-", err)
			end
		end
	end)

	_G.Ecoshift.SpawnEnemyById = function(id, anchor)
		local ok, err = pcall(spawnEnemyById, id, anchor, math.max(1, #Players:GetPlayers()))
		if not ok then
			warn("[EnemySpawner] SpawnEnemyById failed for", id, "-", err)
		end
	end

	print("[EnemySpawner] Successfully connected to Orchestrator. Ready for wave requests.")
end

task.spawn(bindSpawnerCallback)

return {}
