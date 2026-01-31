-- EnemySpawner.server.lua
-- Uses the orchestrator's callback to request actual spawns. You provide SpawnEnemyById(id, point)
local SpawnerOrchestrator = require(script.Parent.SpawnerOrchestrator)
local SpawnService = require(script.Parent.SpawnService)
local Players = game:GetService("Players")

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

-- register spawn callback (called by orchestrator every few seconds)
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.SetEnemySpawnCallback(function(ids, points)
	if type(_G.Ecoshift.SpawnEnemyById) ~= "function" then return end
	if #ids == 0 or #points == 0 then return end
	local pick = choosePoints(points, math.min(#ids, #points))
	local k = 1
	for i,id in ipairs(ids) do
		local pt = pick[k] or pick[#pick]
		k = (k % #pick) + 1
		-- You implement this factory. Do *not* create here.
		-- Signature suggestion: SpawnEnemyById(id: string, anchor: BasePart|Attachment)
		pcall(_G.Ecoshift.SpawnEnemyById, id, pt)
	end
end)

-- (Orchestrator is already :Bind()'d in ServerMain)
return {}
