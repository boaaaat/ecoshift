-- Base equipment values shared by generated tools and player-facing descriptions.
local Survival = require(script.Parent.SurvivalConfig)
local Stats = {}
Stats.ToolPower = { Harvester=20, StoneHatchet=30, StonePickaxe=30, SanditePickaxe=45,
	MireSickle=45, CryoPickaxe=60, ObsidianAxe=75, PhaseMultitool=100 }
Stats.WeaponPower = { StoneSpear=18, BoneSpear=18, SanditeBlade=27, MireDagger=23,
	FrostLance=38, MagmaHammer=50, CrystalBow=44, VoidEdge=65, MeteorPike=82 }
Stats.MeleeRange = 9
Stats.HarvestRange = 10
Stats.BowRange = 180
Stats.ToolCooldown = .6

function Stats.Description(id)
	local armor = Survival.ARMOR[id]
	if armor then
		return string.format("ARMOR STATS\nDamage reduction: %g%%\nHeat: %.0f%% · Cold: %.0f%%\nToxin: %.0f%% · Wet: %.0f%%",
			armor.Armor or 0, (armor.HeatResistance or 0)*100, (armor.ColdResistance or 0)*100,
			(armor.ToxinResistance or 0)*100, (armor.WetResistance or 0)*100)
	end
	local damage = Stats.WeaponPower[id]
	if damage then
		if id == "CrystalBow" then
			return string.format("BASE WEAPON STATS\nDamage: %g–%g (draw strength)\nRange: %g studs\nFull draw: 0.8s",damage*.25,damage,Stats.BowRange)
		end
		return string.format("BASE WEAPON STATS\nDamage: %g per hit\nAttack rate: 1 hit/s\nReach: %g studs (mobile %g)",damage,Stats.MeleeRange+3.5,Stats.MeleeRange+4.25)
	end
	local power = Stats.ToolPower[id]
	if power then
		local combat = id == "Harvester" and "\nCombat: 6 damage · 0.6s cooldown\nReach: 9.5 studs (mobile 10.25)" or ""
		return string.format("BASE TOOL STATS\nBreaking power: %g\nHarvest range: %g studs\nHarvest cooldown: %gs%s",power,Stats.HarvestRange,Stats.ToolCooldown,combat)
	end
	return nil
end

return Stats
