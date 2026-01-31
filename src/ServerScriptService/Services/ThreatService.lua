-- ThreatService.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local ThreatService = {}
ThreatService._threat = 0
ThreatService._lastTick = os.clock()

function ThreatService:Get()
	return self._threat
end

function ThreatService:Add(delta)
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
	local minutes = dt / 60
	self:Add(Config.THREAT.BasePerMinute * minutes)
end

RunService.Heartbeat:Connect(function()
	local ok = pcall(function() ThreatService:Heartbeat() end)
	if not ok then end
end)

return ThreatService
