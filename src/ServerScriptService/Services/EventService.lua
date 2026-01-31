-- EventService.lua (updated with _G hooks)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ThreatService = require(script.Parent.ThreatService)
local BiomeService = require(script.Parent.BiomeService)

local EventService = {}
EventService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
EventService._remote = Util.GetRemote(EventService._remotesFolder, Config.RemoteNames.EventBroadcast)

EventService._nextMinor = 0
EventService._nextMajor = 0
EventService._active = {Minor=nil, Major=nil}

local function scheduleWindow(range) return os.clock() + math.random(range[1], range[2]) end
local function safeFire(remote, evType, id, payload)
	if remote and remote.FireAllClients then remote:FireAllClients(evType, id, payload or {}) end
end
local function hook(kind, ...)
	local list = _G.Ecoshift and _G.Ecoshift.EventCallbacks and _G.Ecoshift.EventCallbacks[kind]
	if type(list) == "table" then
		for _, cb in ipairs(list) do
			if type(cb) == "function" then
				pcall(cb, ...)
			end
		end
	end
end

function EventService:_begin(eventId, evType)
	local payload = {
		Biome = BiomeService:GetCurrent(),
		Threat = ThreatService:Get(),
		Duration = (evType=="Minor") and math.random(45,75) or math.random(90,140),
		StartedAt = os.clock(),
		Type = evType,
	}
	self._active[evType] = {Id=eventId, Data=payload}
	safeFire(self._remote, evType.."_Start", eventId, payload)
	hook("Start", evType, eventId, payload)
end

function EventService:_end(evType)
	local active = self._active[evType]
	if not active then return end
	safeFire(self._remote, evType.."_End", active.Id, active.Data)
	hook("End", evType, active.Id, active.Data)
	self._active[evType] = nil
end

function EventService:_tick()
	for k,active in pairs(self._active) do
		if active then
			if os.clock() - active.Data.StartedAt >= active.Data.Duration
				or (active.Data.Biome ~= BiomeService:GetCurrent()) then
				self:_end(k)
			end
		end
	end
	if os.clock() >= (self._nextMinor or 0) and not self._active.Minor then
		local id = (Config.EVENTS.PoolMinor[math.random(1,#Config.EVENTS.PoolMinor)])
		self:_begin(id, "Minor"); self._nextMinor = scheduleWindow(Config.EVENTS.MinorCadence)
	end
	if os.clock() >= (self._nextMajor or 0) and not self._active.Major then
		local id = (Config.EVENTS.PoolMajor[math.random(1,#Config.EVENTS.PoolMajor)])
		self:_begin(id, "Major"); self._nextMajor = scheduleWindow(Config.EVENTS.MajorCadence)
	end
end

RunService.Heartbeat:Connect(function() local ok=pcall(function() EventService:_tick() end) if not ok then end end)
EventService._nextMinor = scheduleWindow(Config.EVENTS.MinorCadence)
EventService._nextMajor = scheduleWindow(Config.EVENTS.MajorCadence)
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.EventCallbacks = _G.Ecoshift.EventCallbacks or { Start = {}, End = {} }
_G.Ecoshift.OnEventStartAdd = function(cb) if type(cb) == "function" then table.insert(_G.Ecoshift.EventCallbacks.Start, cb) end end
_G.Ecoshift.OnEventEndAdd = function(cb) if type(cb) == "function" then table.insert(_G.Ecoshift.EventCallbacks.End, cb) end end
return EventService
