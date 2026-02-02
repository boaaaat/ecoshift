-- SpawnerOrchestrator.lua
-- Computes *what* to spawn and *where*, on an interval. It does NOT create instances.
-- Instead, you supply a callback via _G.Ecoshift.SetEnemySpawnCallback(function(list, spawnPoints) end)
-- list can be ids or tables { Id, Count, GroupRadius, MinPlayerDistance, MaxPlayerDistance }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local SpawnService = require(script.Parent.SpawnService)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)

local SpawnerOrchestrator = {}
SpawnerOrchestrator._nextTime = 0
SpawnerOrchestrator._period = 24 -- seconds between spawn evaluations (tune as desired)

local function getCallback()
	return (_G.Ecoshift and _G.Ecoshift._SpawnCB) or nil
end

function SpawnerOrchestrator:SetPeriod(seconds)
	self._period = math.max(4, tonumber(seconds) or self._period)
end

function SpawnerOrchestrator:Bind()
	local waves = EntityConfig.EnemyWaves or {}
	if tonumber(waves.PeriodSeconds) then
		self._period = math.max(4, tonumber(waves.PeriodSeconds))
	end
	self._nextTime = os.clock() + self._period
	-- OPTIMIZED: Use task.spawn with sleep instead of Heartbeat
	task.spawn(function()
		while true do
			local now = os.clock()
			if now >= self._nextTime then
				self._nextTime = now + self._period

				local cb = getCallback()
				if cb then
					local wave = SpawnService:ComputeEnemyWave()
					if #wave > 0 then
						local points = SpawnService:GetSpawnPoints()
						if #points > 0 then
							-- fire user callback (safe pcall)
							pcall(function() cb(wave, points) end)
						end
					end
				end
			end
			task.wait(1) -- Check once per second instead of every frame
		end
	end)
end

-- Public API to register a callback without touching this module
_G.Ecoshift = _G.Ecoshift or {}
function _G.Ecoshift.SetEnemySpawnCallback(fn)
	if type(fn) == "function" then
		_G.Ecoshift._SpawnCB = fn
	end
end

return SpawnerOrchestrator
