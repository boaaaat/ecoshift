-- StatusService.lua
-- Applies environmental hazard ticks to players based on current biome and active event modifiers.
-- Uses Attributes on Character/Humanoid; does not create instances.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeService = require(script.Parent.BiomeService)

local StatusService = {}
StatusService._tickInterval = 1.0
StatusService._next = 0

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
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end

	local biomeEnv = BiomeService:GetData() and BiomeService:GetData().env or {}
	local mods = getEventMods()

	-- aggregate intensities
	local toxin = (biomeEnv.Toxin or 0) + (mods.Toxin or 0)
	local wet = (biomeEnv.Wet or 0) + (mods.Wet or 0)

	-- resistances via Attributes on Character (set by your gear scripts)
	local rToxin = resist(char:GetAttribute("Res_Toxin"))
	local rWet   = resist(char:GetAttribute("Res_Wet"))

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
		cur = math.clamp(cur + wet, 0, 5)
		char:SetAttribute("WetStacks", cur)
	else
		char:SetAttribute("WetStacks", math.max(0, (char:GetAttribute("WetStacks") or 0) - 1))
	end
end

function StatusService:Bind()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t < self._next then return end
		self._next = t + self._tickInterval
		for _,plr in ipairs(Players:GetPlayers()) do
			local ok = pcall(function() self:_tickPlayer(plr) end)
			if not ok then end
		end
	end)
end

return StatusService
