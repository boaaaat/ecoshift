-- ThreatService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local GameStateService = require(script.Parent.GameStateService)

local ThreatService = {}
ThreatService._threat = 0
ThreatService._lastTick = os.clock()

function ThreatService:Get()
	return self._threat
end

function ThreatService:Add(delta)
	if GameStateService:IsGameOver() then
		return self._threat
	end
	self._threat = Util.Clamp(self._threat + delta, Config.THREAT.Clamp[1], Config.THREAT.Clamp[2])
end

function ThreatService:OnBossKill()
	self:Add(Config.THREAT.BossKill)
end

function ThreatService:OnObjectiveFailed()
	self:Add(Config.THREAT.FailedObjective)
end

function ThreatService:Heartbeat()
	local now = os.clock()
	local dt = now - self._lastTick
	self._lastTick = now
	if GameStateService:IsGameOver() then
		return
	end
	local minutes = dt / 60
	self:Add(Config.THREAT.BasePerMinute * minutes)
end

-- OPTIMIZED: Use task.spawn with controlled loop - threat doesn't need per-frame updates
task.spawn(function()
	while true do
		local ok = pcall(function() ThreatService:Heartbeat() end)
		if not ok then end
		task.wait(1) -- Update once per second instead of every frame
	end
end)

return ThreatService
