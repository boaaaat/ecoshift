-- Util.lua
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Util = {}

function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local n = {}
	for k,v in pairs(t) do n[k] = Util.DeepCopy(v) end
	return n
end

function Util.ChooseWeighted(entries, weightKey)
	local total = 0
	for _,e in ipairs(entries) do total += (e[weightKey] or e.Weight or 1) end
	if total <= 0 then return entries[1] end
	local r = math.random() * total
	for _,e in ipairs(entries) do
		r -= (e[weightKey] or e.Weight or 1)
		if r <= 0 then return e end
	end
	return entries[#entries]
end

function Util.Clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

function Util.GetDescendant(folderPath)
	local node = game
	for seg in string.gmatch(folderPath, "[^/]+") do
		node = node:FindFirstChild(seg)
		if not node then return nil end
	end
	return node
end

-- OPTIMIZED: Try immediate lookup first, then fall back to waiting
function Util.WaitForDescendant(folderPath, timeout)
	-- Fast path: check if it exists immediately
	local immediate = Util.GetDescendant(folderPath)
	if immediate then return immediate end
	
	-- Slow path: wait for it
	local t0 = os.clock()
	timeout = timeout or 10
	while os.clock() - t0 < timeout do
		local n = Util.GetDescendant(folderPath)
		if n then return n end
		task.wait(0.03) -- OPTIMIZED: Less aggressive polling (was Heartbeat:Wait)
	end
	return Util.GetDescendant(folderPath)
end

function Util.GetRemote(remotesFolder, name)
	if not remotesFolder then return nil end
	return remotesFolder:FindFirstChild(name)
end

function Util.Tagged(tag)
	local ok, list = pcall(CollectionService.GetTagged, CollectionService, tag)
	return ok and list or {}
end

function Util.ForEachPlayer(callback)
	for _,plr in ipairs(Players:GetPlayers()) do
		local ok = pcall(callback, plr)
		if not ok then end
	end
end

function Util.DeepMerge(base, override)
	if type(override) ~= "table" then return override end
	if type(base) ~= "table" then return Util.DeepCopy(override) end
	if override[1] ~= nil then return Util.DeepCopy(override) end
	local result = Util.DeepCopy(base)
	for k, v in pairs(override) do
		if type(v) == "table" and type(result[k]) == "table" and v[1] == nil then
			result[k] = Util.DeepMerge(result[k], v)
		else
			result[k] = type(v) == "table" and Util.DeepCopy(v) or v
		end
	end
	return result
end

return Util
