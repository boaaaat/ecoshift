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

function Util.WaitForDescendant(folderPath, timeout)
	local t0 = os.clock()
	while os.clock()-t0 < (timeout or 10) do
		local n = Util.GetDescendant(folderPath)
		if n then return n end
		RunService.Heartbeat:Wait()
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

return Util
