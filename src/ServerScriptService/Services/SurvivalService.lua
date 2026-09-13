local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

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
SurvivalService._naturalRegenElapsed = setmetatable({}, { __mode = "k" })

local HUNGER_DRAIN = 0.05
local SPRINT_HUNGER_MULTIPLIER = 2
local HUNGER_DAMAGE = 10
local NATURAL_REGEN_THRESHOLD = 0.8
local NATURAL_REGEN_INTERVAL = 4
local NATURAL_REGEN_HEALTH = 1
local NATURAL_REGEN_FOOD_COST = 1
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
	local metadata=require(script.Parent.OverhaulWorldService):MetadataAt(position)
	local depth=metadata and metadata.Depth or 1
	local rate=({.6,.6,.9,1.2,1.5})[tonumber(depth) or 1] or .6
	local timing=BiomeService:GetTiming()
	local ramp=math.clamp(((timing.Duration or 300)-(timing.Remaining or 300))/60,0,1)
	local maturity=BiomeService:GetMaturity()
	return math.sign(ambient)*rate*math.min(1.25,math.abs(ambient)/24)*maturity*ramp
end

local function campfireRecovery(position)
	if ReplicatedStorage:GetAttribute("CookingEnabled") ~= true then return 0 end
	for _, station in ipairs(CollectionService:GetTagged("CraftingStation")) do
		if station:GetAttribute("StationType") == "Campfire" and station:GetAttribute("CookingBurning") == true
			and station:IsDescendantOf(workspace) and (station:IsA("Model") or station:IsA("BasePart"))
			and (station:GetPivot().Position - position).Magnitude <= 12 then return 1 end
	end
	return 0
end

local function applySprintModifier(plr, enabled)
		local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local center=workspace:GetAttribute("CampCenter") or ReplicatedStorage:GetAttribute("CampCenter") or Vector3.zero
		local camp=root and Vector2.new(root.Position.X-center.X,root.Position.Z-center.Z).Magnitude<=200
		local gear=require(script.Parent.GearService):GetModifiers(plr)
		StatsService:RemoveModifier(plr,"Speed","Sprint")
		local base=(enabled and 30 or 20)*(camp and 2 or 1)
		StatsService:SetBase(plr,"Speed",base)
		local movement=gear.WalkSpeedBonus or 0
		local hum=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum:GetState()==Enum.HumanoidStateType.Swimming then movement+=(gear.SwimSpeedBonus or 0)+(plr:GetAttribute("Food_SwimSpeedBonus") or 0) end
		StatsService:SetModifier(plr,"Speed",movement,"Mult","GearMovement")
		local penalty=hum and hum.FloorMaterial==Enum.Material.Mud and .2*(1-(gear.MudPenaltyReduction or 0)) or hum and hum.FloorMaterial==Enum.Material.Snow and .15*(1-(gear.SnowPenaltyReduction or 0)) or 0
		StatsService:SetModifier(plr,"Speed",-penalty,"Mult","GroundMovement")
		StatsService:SetModifier(plr,"Speed",plr:GetAttribute("GearLandingSlow") and -.25 or 0,"Mult","LandingRecovery")
		local now=workspace:GetServerTimeNow()
		local snaredUntil=tonumber(plr:GetAttribute("MonsterSnaredUntil")) or 0
		local snared=snaredUntil>now and snaredUntil<=now+5
		if not snared and plr:GetAttribute("MonsterSnaredUntil")~=nil then plr:SetAttribute("MonsterSnaredUntil",nil) end
		StatsService:SetModifier(plr,"Speed",snared and -.25 or 0,"Mult","MonsterSnare")
		plr:SetAttribute("InCamp",camp==true)
		SurvivalService._sprintApplied[plr]=enabled or nil
end

function SurvivalService:_stopSprint(plr)
	self._sprintWanted[plr] = nil
	applySprintModifier(plr, false)
end

function SurvivalService:_tickSprint(plr, dt)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if (ReplicatedStorage:GetAttribute("WorldShifting") and not plr:GetAttribute("InteriorId")) or ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading")
		or plr:GetAttribute("IsDead") or not hum or not hrp or hum.Health <= 0 then
		self:_stopSprint(plr)
		return
	end
	if hum.Sit or hum.PlatformStand then self:_stopSprint(plr) end
	local maxStamina = math.max(0, StatsService:GetStat(plr, "MaxStamina") or 100)
	local protected = workspace:GetAttribute("WorldType") == "Creative" and plr:GetAttribute("CreativeMode") and plr:GetAttribute("CreativeInvincible")
	local stamina = clamp(StatsService:GetBase(plr, "Stamina") or maxStamina, 0, maxStamina)
	local previousStamina = stamina
	if protected then stamina = maxStamina; self._sprintExhausted[plr] = nil end
	if self._sprintExhausted[plr] and stamina >= maxStamina * 0.2 then
		self._sprintExhausted[plr] = nil
	end
	-- MoveDirection is not replicated reliably to the server for client-owned
	-- characters. Horizontal assembly velocity also detects actual movement.
	local velocity = hrp.AssemblyLinearVelocity
	local moving = hum.MoveDirection.Magnitude > 0.1 or Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.75
	local sprinting = hum:GetState()~=Enum.HumanoidStateType.Swimming and not plr:GetAttribute("GearTraversalStaminaActive") and self._sprintWanted[plr] == true and not self._sprintExhausted[plr] and moving and stamina > 0
	local drain = STAMINA_DRAIN * (1-(plr:GetAttribute("Gear_SprintDrainReduction") or 0)) * (1 - (plr:GetAttribute("Class_SprintReduction") or 0)) * (1 - (plr:GetAttribute("Food_SprintDrainReduction") or 0))
	local nextStamina = clamp(stamina + (sprinting and -drain or (plr:GetAttribute("GearTraversalStaminaActive") and 0 or STAMINA_REGEN)*(1+(plr:GetAttribute("Food_StaminaRecoveryBonus") or 0))) * dt, 0, maxStamina)
	if protected then nextStamina = maxStamina end
	if nextStamina <= 0 and self._sprintWanted[plr] then
		self._sprintExhausted[plr] = true
		sprinting = false
	end
	applySprintModifier(plr, sprinting)
	if nextStamina ~= previousStamina then StatsService:SetBaseStats(plr, {Stamina = nextStamina}) end
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
	if (ReplicatedStorage:GetAttribute("WorldShifting") and not plr:GetAttribute("InteriorId")) or ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") or plr:GetAttribute("IsDead") then return end
	if workspace:GetAttribute("WorldType") == "Creative" and plr:GetAttribute("CreativeMode") and plr:GetAttribute("CreativeInvincible") then return end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end

	local temp = StatsService:GetBase(plr, "Temperature") or StatsService:GetStat(plr, "Temperature") or 0
	local tempRes = StatsService:GetStat(plr, "TemperatureResistance") or 0

	local ambient = plr:GetAttribute("InteriorId") and 0 or getAmbientTemp(hrp.Position)+(plr:GetAttribute("EventExposureRate") or 0)
	if ambient>0 and plr:GetAttribute("GearRoofShelter") then ambient*=.8 end
	local kind = ambient >= 0 and "Heat" or "Cold"
	local equipment = require(script.Parent.GearService)
	local modifiers=equipment:GetModifiers(plr)
	local gear = math.clamp(tonumber(char:GetAttribute("GearRes_" .. kind)) or 0, 0, 0.95)
	local tonic = math.clamp(math.max(tonumber(char:GetAttribute("Res_" .. kind)) or 0, plr:GetAttribute("Gear_"..kind.."Tonic") or 0), 0, 0.95)
	local foodProtection = math.max(plr:GetAttribute("FoodThermal_" .. kind) or 0, plr:GetAttribute("Food_" .. kind .. "Reduction") or 0)
	local fieldReduction, fieldRecovery = require(script.Parent.ClassAbilityService):GetShelterEffect(plr)
	ambient *= (1-(plr:GetAttribute("Gear_SharedCover") or 0)) * (1 - gear) * (1 - math.max(tonic, foodProtection)) * (1 - (plr:GetAttribute("Class_ExposureReduction") or 0)) * (1 - fieldReduction)
	if ambient < 0 then ambient *= 1 + (tonumber(char:GetAttribute("WetStacks")) or 0) * 0.1 end
	if ambient ~= 0 then
		temp += equipment:AdjustExposure(plr,ambient * dt)
	end
	-- Safe conditions and suitable gear allow body temperature to recover.
	tempRes = (math.max(0, tempRes) + 0.3) * (1 + (plr:GetAttribute("Class_ExposureRecovery") or 0)) * (1 + (plr:GetAttribute("Food_ExposureRecoveryBonus") or 0)) + fieldRecovery + (plr:GetAttribute("Gear_TonicRecovery") or 0)
	tempRes *= 1+(modifiers.ExposureRecovery or 0)+(kind=="Heat" and (modifiers.HeatRecoveryBonus or 0) or (modifiers.ColdRecoveryBonus or 0))
	if temp < 0 then tempRes += campfireRecovery(hrp.Position)*(1+(modifiers.HeatSourceRecoveryBonus or 0)) end
	if tempRes > 0 then
		if temp > 0 then
			temp = math.max(0, temp - (tempRes * dt))
		elseif temp < 0 then
			temp = math.min(0, temp + (tempRes * dt))
		end
	end
	temp = clamp(temp, TEMP_MIN, TEMP_MAX)

	local over = math.max(0, (math.abs(temp) - 75) / 10)
	if over > 0 then
		hum:TakeDamage(over * dt)
	end

	local maxHunger = StatsService:GetStat(plr, "MaxHunger") or 100
	local hunger = StatsService:GetBase(plr, "Hunger") or StatsService:GetStat(plr, "Hunger") or maxHunger
	local exertion = self._sprintApplied[plr] and SPRINT_HUNGER_MULTIPLIER or 1
	local drain = HUNGER_DRAIN * exertion * (1-(modifiers.HungerDrainReduction or 0)) * (1-(plr:GetAttribute("Class_HungerReduction") or 0)) * (1-(plr:GetAttribute("Food_HungerDrainReduction") or 0))
	hunger = math.max(0, hunger - drain * dt)

	-- Natural healing is deliberately slow and spends food. Roblox's default
	-- Health script is disabled in StarterCharacterScripts so this is the sole
	-- passive regeneration path.
	if hunger > maxHunger * NATURAL_REGEN_THRESHOLD and hum.Health < hum.MaxHealth then
		local elapsed = (self._naturalRegenElapsed[plr] or 0) + dt
		while elapsed >= NATURAL_REGEN_INTERVAL and hunger > maxHunger * NATURAL_REGEN_THRESHOLD and hum.Health < hum.MaxHealth do
			elapsed -= NATURAL_REGEN_INTERVAL
			hum.Health = math.min(hum.MaxHealth, hum.Health + NATURAL_REGEN_HEALTH)
			hunger = math.max(0, hunger - NATURAL_REGEN_FOOD_COST)
		end
		self._naturalRegenElapsed[plr] = elapsed
	else
		self._naturalRegenElapsed[plr] = nil
	end
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
			self:_stopSprint(plr); self._sprintExhausted[plr] = nil; plr:SetAttribute("MonsterSnaredUntil",nil)
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
		plr:SetAttribute("MonsterSnaredUntil",nil)
		self._sprintWanted[plr] = nil
		self._sprintApplied[plr] = nil
		self._sprintExhausted[plr] = nil
		self._lastSprintRequest[plr] = nil
		self._naturalRegenElapsed[plr] = nil
	end)
end

return SurvivalService
