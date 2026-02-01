-- EnemySpawner.server.lua
-- Uses the orchestrator's callback to request actual spawns.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local BiomeService = require(script.Parent.BiomeService)

local function farFromPlayers(point, minDist)
	minDist = minDist or 60
	local p = point:IsA("Attachment") and point.WorldPosition or point.Position
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - p).Magnitude < minDist then
			return false
		end
	end
	return true
end

local function choosePoints(points, n)
	-- shuffle
	local shuffled = table.clone(points)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local out = {}
	for _, pt in ipairs(shuffled) do
		if farFromPlayers(pt) then
			table.insert(out, pt)
		end
		if #out >= n then
			break
		end
	end
	-- if not enough far points, allow closer
	local i = 1
	while #out < n and i <= #points do
		table.insert(out, points[i])
		i += 1
	end
	return out
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

local function spawnEnemyById(id, anchor, playerCount)
	local prefab = resolvePrefab(getEnemyPrefab(id), id)
	if not prefab then
		warn("[EnemySpawner] Missing prefab for", id)
		return
	end

	local anchorPos = anchor:IsA("Attachment") and anchor.WorldPosition or anchor.Position
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
		print("[EnemySpawner] Spawning wave with enemies:", table.concat(ids, ", "))
		local pick = choosePoints(points, math.min(#ids, #points))
		local k = 1
		local playerCount = math.max(1, #Players:GetPlayers())
		for _, id in ipairs(ids) do
			local pt = pick[k] or pick[#pick]
			k = (k % #pick) + 1
			local ok, err = pcall(spawnEnemyById, id, pt, playerCount)
			if not ok then
				warn("[EnemySpawner] Spawn failed for", id, "-", err)
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
