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
	if GameStateService:IsGameOver() or ReplicatedStorage:GetAttribute("WorldRestoring") == true then
		return self._threat
	end
	if type(delta) ~= "number" or delta ~= delta or math.abs(delta) == math.huge then return self._threat end
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
	if GameStateService:IsGameOver() or ReplicatedStorage:GetAttribute("WorldRestoring") == true then
		return
	end
	local minutes = dt / 60
	self:Add(Config.THREAT.BasePerMinute * minutes)
end

function ThreatService:CaptureState()
	if self._pendingRestore then return table.clone(self._pendingRestore) end
	-- Settle the partial heartbeat interval before freezing the saved value.
	self:Heartbeat()
	return { SchemaVersion = 1, Threat = self._threat }
end

function ThreatService:RestoreState(state)
	if type(state) ~= "table" or state.SchemaVersion ~= 1 or type(state.Threat) ~= "number"
		or state.Threat ~= state.Threat or math.abs(state.Threat) == math.huge
		or state.Threat < Config.THREAT.Clamp[1] or state.Threat > Config.THREAT.Clamp[2] then
		return false, "InvalidThreatSnapshot"
	end
	self._pendingRestore = { SchemaVersion = 1, Threat = state.Threat }
	if ReplicatedStorage:GetAttribute("WorldRestoring") ~= true then return self:CompleteWorldRestore() end
	return true
end

function ThreatService:CompleteWorldRestore()
	if not self._pendingRestore then return true end
	self._threat = self._pendingRestore.Threat
	self._pendingRestore = nil
	self._lastTick = os.clock()
	return true
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
