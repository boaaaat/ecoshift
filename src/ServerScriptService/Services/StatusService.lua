-- StatusService.lua
-- Applies environmental hazard ticks to players based on current biome and active event modifiers.
-- Uses Attributes on Character/Humanoid; does not create instances.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeService = require(script.Parent.BiomeService)

local StatusService = {}
StatusService._tickInterval = 1.0
StatusService._bound = false

local function getEventMods()
	-- EventEffectsService populates _G.Ecoshift.Mods (optional)
	local mods = (_G.Ecoshift and _G.Ecoshift.Mods) or {}
	return mods -- e.g., {Temp=+1, Toxin=+2, Wet=+1}
end

local function applyDamage(hum, dmg)
	if dmg <= 0 then return end
	-- minimal guard to avoid insta-killing
	hum:TakeDamage(math.min(dmg, 10))
end

local function resist(v) return math.clamp(tonumber(v) or 0, -0.9, 0.9) end

function StatusService:_tickPlayer(plr)
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerRestoring") or plr:GetAttribute("WorldPlayerLoading") or plr:GetAttribute("IsDead") then return end
	if workspace:GetAttribute("WorldType") == "Creative" and plr:GetAttribute("CreativeMode") and plr:GetAttribute("CreativeInvincible") then return end
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local biomeEnv = BiomeService:GetData() and BiomeService:GetData().env or {}
	local mods = getEventMods()
	local weather = BiomeService:GetWeather() or {}

	-- aggregate intensities
	local toxin = (biomeEnv.Toxin or 0) + (mods.Toxin or 0) + (weather.Toxin or 0)
	local wet = (biomeEnv.Wet or 0) + (mods.Wet or 0) + (weather.Wet or 0)

	-- resistances via Attributes on Character (set by your gear scripts)
	local rToxin = resist(char:GetAttribute("Res_Toxin"))
	local rWet   = resist(char:GetAttribute("Res_Wet"))
	rToxin = 1 - (1 - rToxin) * (1 - resist(char:GetAttribute("GearRes_Toxin")))
	rWet = 1 - (1 - rWet) * (1 - resist(char:GetAttribute("GearRes_Wet")))

	-- temperature damage handled by SurvivalService (region-aware)

	-- toxin
	if toxin > 0 then
		local base = 0.8 * toxin
		local dmg = base * (1 - rToxin)
		applyDamage(hum, dmg)
	end

	-- wet shock synergy is handled by your weapon scripts; here we can apply stamina penalty via Attribute
	if wet > 0 then
		local cur = char:GetAttribute("WetStacks") or 0
		local adjustedWet = wet * (1 - rWet)
		cur = math.clamp(cur + adjustedWet, 0, 5)
		char:SetAttribute("WetStacks", cur)
	else
		char:SetAttribute("WetStacks", math.max(0, (char:GetAttribute("WetStacks") or 0) - 1))
	end
end

function StatusService:Bind()
	if self._bound then return end
	self._bound = true
	task.spawn(function()
		while self._bound do
			for _, plr in ipairs(Players:GetPlayers()) do
				pcall(function()
					self:_tickPlayer(plr)
				end)
			end
			task.wait(self._tickInterval)
		end
	end)
end

return StatusService
