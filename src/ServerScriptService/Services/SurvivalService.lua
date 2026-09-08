local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local BiomeService = require(script.Parent.BiomeService)
local ChunkStreamingService = require(script.Parent.ChunkStreamingService)
local StatsService = require(script.Parent.StatsService)

local SurvivalService = {}
SurvivalService._initialized = false
SurvivalService._tickInterval = 1

SurvivalService._sprintWanted = setmetatable({}, { __mode = "k" })
SurvivalService._sprintApplied = setmetatable({}, { __mode = "k" })
SurvivalService._sprintExhausted = setmetatable({}, { __mode = "k" })
SurvivalService._lastSprintRequest = setmetatable({}, { __mode = "k" })

local HUNGER_DRAIN = 0.05
local HUNGER_DAMAGE = 10
local STAMINA_DRAIN = 12
local STAMINA_REGEN = 8
local TEMP_MIN = -100
local TEMP_MAX = 100

local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function getAmbientTemp(position)
	local biomeEnv = (BiomeService:GetData() and BiomeService:GetData().env) or {}
	local ambient = tonumber(biomeEnv.Temp) or 0
	local regionTemp = ChunkStreamingService.GetRegionTempAtPosition and ChunkStreamingService:GetRegionTempAtPosition(position)
	if regionTemp ~= nil then
		ambient = tonumber(regionTemp) or 0
	end
	local mods = (_G.Ecoshift and _G.Ecoshift.Mods) or {}
	ambient += tonumber(mods.Temp) or 0
	ambient += tonumber((BiomeService:GetWeather() or {}).Temp) or 0
	return ambient
end

local function applySprintModifier(plr, enabled)
	if enabled then
		if not SurvivalService._sprintApplied[plr] then
			StatsService:AddModifier(plr, "Speed", 0.2, "Mult", nil, "Sprint")
			SurvivalService._sprintApplied[plr] = true
		end
	else
		if SurvivalService._sprintApplied[plr] then
			StatsService:RemoveModifier(plr, "Speed", "Sprint")
			SurvivalService._sprintApplied[plr] = nil
		end
	end
end

function SurvivalService:_stopSprint(plr)
	self._sprintWanted[plr] = nil
	applySprintModifier(plr, false)
end

function SurvivalService:_tickSprint(plr, dt)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring")
		or plr:GetAttribute("IsDead") or not hum or not hrp or hum.Health <= 0 then
		self:_stopSprint(plr)
		return
	end
	if hum.Sit or hum.PlatformStand then self:_stopSprint(plr) end
	local maxStamina = math.max(0, StatsService:GetStat(plr, "MaxStamina") or 100)
	local stamina = clamp(StatsService:GetBase(plr, "Stamina") or maxStamina, 0, maxStamina)
	-- MoveDirection is not replicated reliably to the server for client-owned
	-- characters. Horizontal assembly velocity also detects actual movement.
	local velocity = hrp.AssemblyLinearVelocity
	local moving = hum.MoveDirection.Magnitude > 0.1 or Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.75
	local sprinting = self._sprintWanted[plr] == true and not self._sprintExhausted[plr] and moving and stamina > 0
	local nextStamina = clamp(stamina + (sprinting and -STAMINA_DRAIN or STAMINA_REGEN) * dt, 0, maxStamina)
	if nextStamina <= 0 and self._sprintWanted[plr] then
		self._sprintExhausted[plr] = true
		self._sprintWanted[plr] = nil
		sprinting = false
	end
	applySprintModifier(plr, sprinting)
	if nextStamina ~= stamina then StatsService:SetBaseStats(plr, {Stamina = nextStamina}) end
end

function SurvivalService:_setSprint(plr, enabled)
	if type(enabled) ~= "boolean" then return end
	if not enabled then
		self._sprintExhausted[plr] = nil
		self:_stopSprint(plr)
		return
	end
	local now = os.clock()
	if self._sprintWanted[plr] or self._sprintExhausted[plr] then return end
	self._sprintWanted[plr] = true
	-- A fast release/repress still records intent; the regular tick applies it
	-- if the immediate update is throttled.
	if now - (self._lastSprintRequest[plr] or -math.huge) < 0.1 then return end
	self._lastSprintRequest[plr] = now
	self:_tickSprint(plr, 0)
end

function SurvivalService:_tickPlayer(plr, dt)
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("IsDead") then return end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end

	local temp = StatsService:GetBase(plr, "Temperature") or StatsService:GetStat(plr, "Temperature") or 0
	local tempRes = StatsService:GetStat(plr, "TemperatureResistance") or 0

	local ambient = getAmbientTemp(hrp.Position)
	local kind = ambient >= 0 and "Heat" or "Cold"
	local gear = math.clamp(tonumber(char:GetAttribute("GearRes_" .. kind)) or 0, 0, 0.95)
	local tonic = math.clamp(tonumber(char:GetAttribute("Res_" .. kind)) or 0, 0, 0.95)
	ambient *= (1 - gear) * (1 - tonic)
	if ambient < 0 then ambient *= 1 + (tonumber(char:GetAttribute("WetStacks")) or 0) * 0.1 end
	if ambient ~= 0 then
		temp += ambient * dt
	end
	-- Safe conditions and suitable gear allow body temperature to recover.
	tempRes = math.max(0, tempRes) + 0.3
	if tempRes > 0 then
		if temp > 0 then
			temp = math.max(0, temp - (tempRes * dt))
		elseif temp < 0 then
			temp = math.min(0, temp + (tempRes * dt))
		end
	end
	temp = clamp(temp, TEMP_MIN, TEMP_MAX)

	local over = math.max(0, (math.abs(temp) - 50) / 10)
	if over > 0 then
		hum:TakeDamage(over * dt)
	end

	local maxHunger = StatsService:GetStat(plr, "MaxHunger") or 100
	local hunger = StatsService:GetBase(plr, "Hunger") or StatsService:GetStat(plr, "Hunger") or maxHunger
	hunger = math.max(0, hunger - (HUNGER_DRAIN * dt))
	if hunger <= 0 then
		hum:TakeDamage(HUNGER_DAMAGE * dt)
	end

	StatsService:SetBaseStats(plr, {
		Temperature = temp,
		Hunger = hunger,
	})
end

function SurvivalService:Init()
	if self._initialized then return end
	self._initialized = true

	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local rSprint = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.SprintToggle)
	if rSprint then
		rSprint.OnServerEvent:Connect(function(plr, enabled)
			self:_setSprint(plr, enabled)
		end)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		local step = math.min(elapsed, 0.5); elapsed = 0
		for _, plr in ipairs(Players:GetPlayers()) do self:_tickSprint(plr, step) end
	end)
	local function bindPlayer(plr)
		plr.CharacterRemoving:Connect(function()
			self:_stopSprint(plr); self._sprintExhausted[plr] = nil
		end)
		plr:GetAttributeChangedSignal("IsDead"):Connect(function() if plr:GetAttribute("IsDead") then self:_stopSprint(plr) end end)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do bindPlayer(plr) end

	task.spawn(function()
		local last = os.clock()
		while self._initialized do
			task.wait(self._tickInterval)
			local now = os.clock()
			local dt = math.max(0, now - last)
			last = now
			for _, plr in ipairs(Players:GetPlayers()) do
				pcall(function()
					self:_tickPlayer(plr, dt)
				end)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		self._sprintWanted[plr] = nil
		self._sprintApplied[plr] = nil
		self._sprintExhausted[plr] = nil
		self._lastSprintRequest[plr] = nil
	end)
end

return SurvivalService
