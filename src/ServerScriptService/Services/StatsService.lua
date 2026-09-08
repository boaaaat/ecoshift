-- StatsService.lua
-- Centralized player stats with base values and additive/multiplicative modifiers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StatsService = {}

StatsService.DEFAULTS = {
	Speed = 16,
	JumpHeight = 7.2,
	Health = 100,
	MaxHealth = 100,
	HealthRegen = 0,
	Stamina = 100,
	MaxStamina = 100,
	Hunger = 100,
	MaxHunger = 100,
	Armor = 0, -- percent (0-100)
	Temperature = 0,
	TemperatureResistance = 0,
	Illness = 0,
}

local STAT_ALIASES = {
	speed = "Speed",
	jumpheight = "JumpHeight",
	jump_height = "JumpHeight",
	jump = "JumpHeight",
	health = "Health",
	maxhealth = "MaxHealth",
	max_health = "MaxHealth",
	healthregen = "HealthRegen",
	health_regen = "HealthRegen",
	regen = "HealthRegen",
	stamina = "Stamina",
	maxstamina = "MaxStamina",
	max_stamina = "MaxStamina",
	hunger = "Hunger",
	maxhunger = "MaxHunger",
	max_hunger = "MaxHunger",
	armor = "Armor",
	armour = "Armor",
	temperature = "Temperature",
	temp = "Temperature",
	temperatureresistance = "TemperatureResistance",
	temperature_resistance = "TemperatureResistance",
	tempres = "TemperatureResistance",
	temp_res = "TemperatureResistance",
	illness = "Illness",
}

local function normalizeStat(stat)
	if type(stat) ~= "string" then return nil end
	return STAT_ALIASES[string.lower(stat)]
end

local function normalizeMode(mode)
	if type(mode) ~= "string" then return "Add" end
	local m = string.lower(mode)
	if m == "add" or m == "linear" then
		return "Add"
	end
	if m == "mul" or m == "mult" or m == "multiply" or m == "percent" or m == "pct" then
		return "Mult"
	end
	return "Add"
end

local function clampNumber(v, lo, hi)
	local n = tonumber(v) or 0
	if lo ~= nil then n = math.max(lo, n) end
	if hi ~= nil then n = math.min(hi, n) end
	return n
end

local function newPlayerData()
	local base = {}
	local mods = {}
	for stat, value in pairs(StatsService.DEFAULTS) do
		base[stat] = value
		mods[stat] = {}
	end
	return {
		Base = base,
		Mods = mods,
		Cache = {},
	}
end

StatsService._data = setmetatable({}, { __mode = "k" })
StatsService._nextModId = 0
StatsService._regenLast = 0

local function getData(self, plr)
	if not self._data[plr] then
		self._data[plr] = newPlayerData()
	end
	return self._data[plr]
end

local function cleanupExpired(mods)
	if not mods or #mods == 0 then return end
	local now = os.clock()
	for i = #mods, 1, -1 do
		local mod = mods[i]
		if mod.ExpiresAt and mod.ExpiresAt <= now then
			table.remove(mods, i)
		end
	end
end

local function computeStat(data, stat)
	local base = tonumber(data.Base[stat]) or 0
	local mods = data.Mods[stat]
	if mods then
		cleanupExpired(mods)
	end
	local add = 0
	local mult = 0
	for _, mod in ipairs(mods or {}) do
		if mod.Mode == "Add" then
			add += (tonumber(mod.Value) or 0)
		elseif mod.Mode == "Mult" then
			mult += (tonumber(mod.Value) or 0)
		end
	end
	return base + add + (base * mult)
end

function StatsService:GetBase(plr, stat)
	local key = normalizeStat(stat)
	if not key then return nil end
	local data = getData(self, plr)
	return data.Base[key]
end

function StatsService:SetBase(plr, stat, value)
	local key = normalizeStat(stat)
	if not key then return false end
	local data = getData(self, plr)
	data.Base[key] = tonumber(value) or 0
	self:_recompute(plr, { Force = true, HealthChanged = (key == "Health") })
	return true
end

function StatsService:SetBaseStats(plr, values)
	if type(values) ~= "table" then return false end
	local data = getData(self, plr)
	local healthChanged = false
	for stat, value in pairs(values) do
		local key = normalizeStat(stat)
		if key then
			data.Base[key] = tonumber(value) or 0
			if key == "Health" then
				healthChanged = true
			end
		end
	end
	self:_recompute(plr, { Force = true, HealthChanged = healthChanged })
	return true
end

function StatsService:GetStat(plr, stat)
	local key = normalizeStat(stat)
	if not key then return nil end
	local data = getData(self, plr)
	local cached = data.Cache[key]
	if cached == nil then
		cached = computeStat(data, key)
		data.Cache[key] = cached
	end
	return cached
end

function StatsService:GetAll(plr)
	local data = getData(self, plr)
	local out = {}
	for stat in pairs(StatsService.DEFAULTS) do
		out[stat] = computeStat(data, stat)
	end
	return out
end

function StatsService:AddModifier(plr, statOrMod, value, mode, duration, id)
	local stat = statOrMod
	local mod = {}
	if type(statOrMod) == "table" then
		mod = statOrMod
		stat = mod.Stat
		value = mod.Value
		mode = mod.Mode
		duration = mod.Duration
		id = mod.Id
	end

	local key = normalizeStat(stat)
	if not key then return nil end
	local data = getData(self, plr)
	local mods = data.Mods[key]
	StatsService._nextModId += 1
	local modId = id or tostring(StatsService._nextModId)
	local entry = {
		Id = modId,
		Mode = normalizeMode(mode),
		Value = tonumber(value) or 0,
		ExpiresAt = (tonumber(duration) and duration > 0) and (os.clock() + duration) or nil,
	}
	table.insert(mods, entry)

	if entry.ExpiresAt then
		task.delay(duration, function()
			if self._data[plr] then
				self:RemoveModifier(plr, key, modId)
			end
		end)
	end

	self:_recompute(plr, { Force = true, HealthChanged = (key == "Health") })
	return modId
end

function StatsService:RemoveModifier(plr, stat, id)
	local key = normalizeStat(stat) or stat
	if not key then return false end
	local data = self._data[plr]
	if not data or not data.Mods[key] then return false end
	local mods = data.Mods[key]
	local removed = false
	for i = #mods, 1, -1 do
		if mods[i].Id == id then
			table.remove(mods, i)
			removed = true
		end
	end
	if removed then
		self:_recompute(plr, { Force = true, HealthChanged = (key == "Health") })
	end
	return removed
end

function StatsService:ClearModifiers(plr, stat)
	if stat == nil then
		local data = self._data[plr]
		if not data then return end
		for key in pairs(data.Mods) do
			data.Mods[key] = {}
		end
		self:_recompute(plr, { Force = true, HealthChanged = true })
		return
	end
	local key = normalizeStat(stat)
	if not key then return end
	local data = self._data[plr]
	if not data then return end
	data.Mods[key] = {}
	self:_recompute(plr, { Force = true, HealthChanged = (key == "Health") })
end

function StatsService:_applyAttributes(plr, stats)
	for stat, value in pairs(stats) do
		plr:SetAttribute("Stat_" .. stat, value)
	end
end

function StatsService:_applyHumanoid(plr, stats, changed, opts)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local speed = clampNumber(stats.Speed, 0, 200)
	if changed.Speed or (opts and opts.Force) then
		hum.WalkSpeed = speed
	end

	local jumpHeight = clampNumber(stats.JumpHeight, 0, 200)
	if changed.JumpHeight or (opts and opts.Force) then
		hum.UseJumpPower = false
		hum.JumpHeight = jumpHeight
	end

	local maxHealth = math.max(1, clampNumber(stats.MaxHealth, 1, 1e6))
	if changed.MaxHealth or (opts and opts.Force) then
		hum.MaxHealth = maxHealth
		if hum.Health > maxHealth then
			hum.Health = maxHealth
		end
	end

	if (changed.Health or (opts and opts.HealthChanged)) then
		local targetHealth = clampNumber(stats.Health, 0, maxHealth)
		hum.Health = targetHealth
	end
end

function StatsService:_recompute(plr, opts)
	local data = getData(self, plr)
	local stats = {}
	local changed = {}
	for stat in pairs(StatsService.DEFAULTS) do
		local value = computeStat(data, stat)
		stats[stat] = value
		if data.Cache[stat] ~= value then
			changed[stat] = true
			data.Cache[stat] = value
		end
	end
	self:_applyAttributes(plr, stats)
	self:_applyHumanoid(plr, stats, changed, opts)
end

function StatsService:_bindPlayer(plr)
	getData(self, plr)
	self:_recompute(plr, { Force = true, HealthChanged = true })
	plr.CharacterAdded:Connect(function(char)
		task.defer(function()
			if plr:GetAttribute("WorldPlayerRestoring") or char:GetAttribute("WorldStateRestored") then return end
			self:_recompute(plr, { Force = true, HealthChanged = true })
		end)
	end)
end

function StatsService:Init()
	for _, plr in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(plr)
	end
	Players.PlayerAdded:Connect(function(plr)
		self:_bindPlayer(plr)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		self._data[plr] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local last = self._regenLast > 0 and self._regenLast or now
		local elapsed = now - last
		self._regenLast = now
		if ReplicatedStorage:GetAttribute("WorldRestoring") then return end
		for _, plr in ipairs(Players:GetPlayers()) do
			local data = self._data[plr]
			if data and plr.Character and not plr:GetAttribute("WorldPlayerRestoring") then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
					local regen = data.Cache.HealthRegen or computeStat(data, "HealthRegen")
					if regen > 0 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + (regen * elapsed))
					end
				end
			end
		end
	end)

	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.StatsService = self
end

function StatsService:CaptureWorldState(plr)
	local data = getData(self, plr)
	local state = { Base = table.clone(data.Base), Modifiers = {} }
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then state.Health = hum.Health end
	for stat, modifiers in pairs(data.Mods) do
		cleanupExpired(modifiers)
		for _, mod in ipairs(modifiers) do
			-- Gear is rebuilt from inventory. Held sprint input is never persisted.
			if mod.Id ~= "Sprint" and mod.Id ~= "ArmorEquip" and mod.Id ~= "TempResEquip" then
				table.insert(state.Modifiers, { Stat = stat, Id = tostring(mod.Id), Value = mod.Value, Mode = mod.Mode,
					Remaining = mod.ExpiresAt and math.max(0, mod.ExpiresAt - os.clock()) or false })
			end
		end
	end
	return state
end

function StatsService:RestoreWorldState(plr, state)
	local Codec = require(script.Parent.WorldSnapshotCodec)
	assert(type(state) == "table" and type(state.Base) == "table", "Missing saved stats")
	Codec.BoundedCount(state.Modifiers or {}, 128)
	local data = newPlayerData()
	for stat in pairs(self.DEFAULTS) do data.Base[stat] = Codec.Number(state.Base[stat], -1e6, 1e6) end
	for _, mod in ipairs(state.Modifiers or {}) do
		assert(data.Mods[mod.Stat] and (mod.Mode == "Add" or mod.Mode == "Mult"), "Invalid saved stat modifier")
		local remaining = mod.Remaining ~= false and Codec.Number(mod.Remaining, 0, 86400 * 30) or nil
		table.insert(data.Mods[mod.Stat], { Id = Codec.Text(mod.Id), Value = Codec.Number(mod.Value, -1e6, 1e6), Mode = mod.Mode,
			ExpiresAt = remaining and os.clock() + remaining or nil })
	end
	self._data[plr] = data
	self:_recompute(plr, { Force = true, HealthChanged = true })
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum and state.Health then hum.Health = Codec.Number(state.Health, 0, hum.MaxHealth) end
end

return StatsService
