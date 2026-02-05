local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local BiomeService = require(script.Parent.BiomeService)
local ChunkStreamingService = require(script.Parent.ChunkStreamingService)
local StatsService = require(script.Parent.StatsService)

local SurvivalService = {}

SurvivalService._sprintWanted = setmetatable({}, { __mode = "k" })
SurvivalService._sprintApplied = setmetatable({}, { __mode = "k" })

local HUNGER_DRAIN = 0.5
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

function SurvivalService:_tickPlayer(plr, dt)
	local char = plr.Character
	if not char then
		applySprintModifier(plr, false)
		self._sprintWanted[plr] = nil
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		applySprintModifier(plr, false)
		return
	end
	if hum.Health <= 0 then
		applySprintModifier(plr, false)
		return
	end

	local temp = StatsService:GetBase(plr, "Temperature") or StatsService:GetStat(plr, "Temperature") or 0
	local tempRes = StatsService:GetStat(plr, "TemperatureResistance") or 0

	local ambient = getAmbientTemp(hrp.Position)
	if ambient ~= 0 then
		temp += ambient * dt
	end
	if tempRes > 0 then
		if temp > 0 then
			temp = math.max(0, temp - (tempRes * dt))
		elseif temp < 0 then
			temp = math.min(0, temp + (tempRes * dt))
		end
	end
	temp = clamp(temp, TEMP_MIN, TEMP_MAX)

	local over = math.max(0, math.abs(temp) - 50)
	if over > 0 then
		hum:TakeDamage(over * dt)
	end

	local maxHunger = StatsService:GetStat(plr, "MaxHunger") or 100
	local hunger = StatsService:GetBase(plr, "Hunger") or StatsService:GetStat(plr, "Hunger") or maxHunger
	hunger = math.max(0, hunger - (HUNGER_DRAIN * dt))
	if hunger <= 0 then
		hum:TakeDamage(HUNGER_DAMAGE * dt)
	end

	local maxStamina = StatsService:GetStat(plr, "MaxStamina") or 100
	local stamina = StatsService:GetBase(plr, "Stamina") or StatsService:GetStat(plr, "Stamina") or maxStamina
	local moving = hum.MoveDirection.Magnitude > 0.1
	local wantsSprint = self._sprintWanted[plr] and true or false
	local sprinting = wantsSprint and moving and stamina > 0

	if sprinting then
		stamina = stamina - (STAMINA_DRAIN * dt)
	else
		stamina = stamina + (STAMINA_REGEN * dt)
	end
	stamina = clamp(stamina, 0, maxStamina)
	if stamina <= 0 and wantsSprint then
		self._sprintWanted[plr] = nil
		sprinting = false
	end

	applySprintModifier(plr, sprinting)

	StatsService:SetBaseStats(plr, {
		Temperature = temp,
		Hunger = hunger,
		Stamina = stamina,
	})
end

function SurvivalService:Init()
	local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	local rSprint = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.SprintToggle)
	if rSprint then
		rSprint.OnServerEvent:Connect(function(plr, enabled)
			self._sprintWanted[plr] = enabled and true or nil
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, plr in ipairs(Players:GetPlayers()) do
			local ok = pcall(function()
				self:_tickPlayer(plr, dt)
			end)
			if not ok then end
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		self._sprintWanted[plr] = nil
		self._sprintApplied[plr] = nil
	end)
end

return SurvivalService
