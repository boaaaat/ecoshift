-- Location: ServerScriptService/EnemySpawner.server.lua
-- (UPDATED WITH MODERN RAYCAST SYNTAX)

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config) 
local BiomeService = require(script.Parent.Services.BiomeService)
local EnemyPrefabs = ServerStorage:FindFirstChild("Enemies")
local BiomeEnemyPrefabs = ServerStorage:FindFirstChild("EnemyPrefabs")

local function getEnemyFolder()
	if EnemyPrefabs and EnemyPrefabs.Parent then
		return EnemyPrefabs
	end
	EnemyPrefabs = ServerStorage:FindFirstChild("Enemies")
	return EnemyPrefabs
end

local function findPrefabInFolder(root, biomeName, id)
	if not root then return nil end
	if biomeName then
		local biomeFolder = root:FindFirstChild(biomeName)
		local prefab = biomeFolder and biomeFolder:FindFirstChild(id)
		if prefab then return prefab end
	end
	-- Search all biome folders
	for _, biomeFolder in ipairs(root:GetChildren()) do
		if biomeFolder:IsA("Folder") then
			local prefab = biomeFolder:FindFirstChild(id)
			if prefab then return prefab end
		end
	end
	-- Fallback to direct child
	return root:FindFirstChild(id)
end

local function getEnemyPrefab(id)
	local biomeName = BiomeService:GetCurrent()
	local prefab = findPrefabInFolder(BiomeEnemyPrefabs, biomeName, id)
	if prefab then return prefab end
	prefab = findPrefabInFolder(EnemyPrefabs, biomeName, id)
	return prefab
end

-- This function finds a safe spawn position above the ground
local function getSafeSpawnPosition(originPosition)
	local rayOrigin = originPosition + Vector3.new(0, 200, 0)
	local rayDirection = Vector3.new(0, -300, 0)

	-- ==================================================================
	-- THE FIX IS HERE: This is the modern way to create RaycastParams.
	-- ==================================================================
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude -- "Exclude" is the new "Blacklist"
	-- Ignore any existing characters or items so we only hit the map
	raycastParams.FilterDescendantsInstances = {ServerStorage.Enemies} 
	-- ==================================================================

	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local groundPosition = result and result.Position or originPosition

	return CFrame.new(groundPosition + Vector3.new(0, 10, 0))
end


local function spawnWave(enemyIds, spawnPoints)
	if #enemyIds == 0 or #spawnPoints == 0 then return end

	local prefabFolder = getEnemyFolder()
	if not prefabFolder and not BiomeEnemyPrefabs then
		warn("[EnemySpawner] Missing ServerStorage/Enemies or EnemyPrefabs; skipping wave spawn.")
		return
	end

	print("[EnemySpawner] Spawning wave with enemies:", table.concat(enemyIds, ", "))

	local playerCount = math.max(1, #Players:GetPlayers())

	for _, id in ipairs(enemyIds) do
		local prefab = getEnemyPrefab(id)
		if not prefab then 
			warn("[EnemySpawner] SKIPPED: Cannot find enemy prefab named '", id, "'")
			continue 
		end

		local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
		local newEnemy = prefab:Clone() :: Model
		newEnemy.Name = id .. "_" .. math.random(1000, 9999)
		newEnemy:SetAttribute("EntityId", id)
		local entityType = newEnemy:GetAttribute("EntityType") or prefab:GetAttribute("EntityType") or "Monster"
		newEnemy:SetAttribute("EntityType", entityType)
		if entityType == "Animal" then
			CollectionService:AddTag(newEnemy, "Animal")
		else
			CollectionService:AddTag(newEnemy, "Monster")
		end

		for _, part in ipairs(newEnemy:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end
		end

		local safeCFrame = getSafeSpawnPosition(spawnPoint.Position)
		newEnemy:PivotTo(safeCFrame)

		local enemiesFolder = Workspace:FindFirstChild("Enemies") or Instance.new("Folder")
		enemiesFolder.Name = "Enemies"
		enemiesFolder.Parent = Workspace
		newEnemy.Parent = enemiesFolder
		if entityType == "Animal" then
			CollectionService:AddTag(newEnemy, "Animal")
		else
			CollectionService:AddTag(newEnemy, "Monster")
		end

		local rootPart = newEnemy.PrimaryPart
		if rootPart then
			rootPart:SetNetworkOwner(nil) 
		end

		local healthValue = newEnemy:FindFirstChild("Health")
		local humanoid = newEnemy:FindFirstChildOfClass("Humanoid")
		if healthValue and humanoid then
			local baseHp = humanoid.MaxHealth 
			local scaledHp = baseHp * (1 + (playerCount - 1) * 0.25)
			-- Apply night multiplier if available
			local nightMult = (_G.Ecoshift and _G.Ecoshift.GetEnemyMultiplier) and _G.Ecoshift.GetEnemyMultiplier() or 1
			scaledHp = scaledHp * nightMult
			healthValue.Value = scaledHp
			humanoid.Health = scaledHp
		end
	end
end

_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.SpawnEnemyById = function(id, anchor)
	local prefab = getEnemyPrefab(id)
	if not prefab then return end
	local anchorPos = anchor:IsA("Attachment") and anchor.WorldPosition or anchor.Position
	local newEnemy = prefab:Clone()
	newEnemy.Name = id .. "_" .. math.random(1000, 9999)
	newEnemy:SetAttribute("EntityId", id)
	local entityType = newEnemy:GetAttribute("EntityType") or prefab:GetAttribute("EntityType") or "Monster"
	newEnemy:SetAttribute("EntityType", entityType)
	if entityType == "Animal" then
		CollectionService:AddTag(newEnemy, "Animal")
	else
		CollectionService:AddTag(newEnemy, "Monster")
	end
	local safeCFrame = getSafeSpawnPosition(anchorPos)
	newEnemy:PivotTo(safeCFrame)
	local enemiesFolder = Workspace:FindFirstChild("Enemies") or Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = Workspace
	newEnemy.Parent = enemiesFolder
	if entityType == "Animal" then
		CollectionService:AddTag(newEnemy, "Animal")
	else
		CollectionService:AddTag(newEnemy, "Monster")
	end
	local rootPart = newEnemy.PrimaryPart
	if rootPart then rootPart:SetNetworkOwner(nil) end
end

while not (_G.Ecoshift and _G.Ecoshift.SetEnemySpawnCallback) do
	task.wait(0.1)
end

_G.Ecoshift.SetEnemySpawnCallback(spawnWave)

print("[EnemySpawner] Successfully connected to Orchestrator. Ready for wave requests.")
