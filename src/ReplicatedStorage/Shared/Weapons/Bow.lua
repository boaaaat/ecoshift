local WeaponBase = require(script.Parent.WeaponBase)

local Bow = {}
Bow.__index = Bow
setmetatable(Bow, WeaponBase)

function Bow.new(tool, owner)
	local self = WeaponBase.new(tool, owner)
	setmetatable(self, Bow)
	return self
end

function Bow:GetDamage()
	return self:GetNumber("Damage", 12)
end

function Bow:GetProjectileSpeed()
	return self:GetNumber("ProjectileSpeed", 120)
end

function Bow:GetChargeTime()
	return self:GetNumber("ChargeTime", 0.8)
end

function Bow:GetRange()
	return self:GetNumber("Range", 160)
end

function Bow:ComputeDamage(chargeRatio)
	local ratio = math.clamp(tonumber(chargeRatio) or 0, 0, 1)
	return self:GetDamage() * (0.25 + 0.75 * ratio)
end

return Bow
