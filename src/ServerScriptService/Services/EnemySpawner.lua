-- EnemySpawner.server.lua
-- Uses the orchestrator's callback to request actual spawns.
local SpawnService = require(script.Parent.SpawnService)
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local BiomeService = require(script.Parent.BiomeService)

local function farFromPlayers(point, minDist)
	minDist = minDist or 60
	local p = point:IsA("Attachment") and point.WorldPosition or point.Position
	for _,plr in ipairs(Players:GetPlayers()) do
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
	for i=#shuffled,2,-1 do local j = math.random(1,i); shuffled[i],shuffled[j] = shuffled[j],shuffled[i] end
	local out = {}
	for _,pt in ipairs(shuffled) do
		if farFromPlayers(pt) then table.insert(out, pt) end
		if #out >= n then break end
	end
	-- if not enough far points, allow closer
	local i=1
	while #out < n and i <= #points do table.insert(out, points[i]); i+=1 end
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
	raycastParams.FilterDescendantsInstances = { ServerStorage:FindFirstChild("Enemies"), ServerStorage:FindFirstChild("EnemyPrefabs") }
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local groundPosition = result and result.Position or originPosition
	return CFrame.new(groundPosition + Vector3.new(0, 10, 0))
end

local function spawnEnemyById(id, anchor)
	local prefab = getEnemyPrefab(id)
	if not prefab then
		warn("[EnemySpawner] Missing prefab for", id)
		return
	end
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
	for _, part in ipairs(newEnemy:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
		end
	end
	local safeCFrame = getSafeSpawnPosition(anchorPos)
	newEnemy:PivotTo(safeCFrame)
	local enemiesFolder = Workspace:FindFirstChild("Enemies") or Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = Workspace
	newEnemy.Parent = enemiesFolder
	local rootPart = newEnemy.PrimaryPart
	if rootPart then rootPart:SetNetworkOwner(nil) end
end

-- register spawn callback (called by orchestrator every few seconds)
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.SetEnemySpawnCallback(function(ids, points)
	if #ids == 0 or #points == 0 then return end
	local pick = choosePoints(points, math.min(#ids, #points))
	local k = 1
	for i,id in ipairs(ids) do
		local pt = pick[k] or pick[#pick]
		k = (k % #pick) + 1
		pcall(spawnEnemyById, id, pt)
	end
end)

-- (Orchestrator is already :Bind()'d in ServerMain)
return {}
