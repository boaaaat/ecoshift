local WeaponBase = require(script.Parent.WeaponBase)

local Gun = {}
Gun.__index = Gun
setmetatable(Gun, WeaponBase)

function Gun.new(tool, owner)
	local self = WeaponBase.new(tool, owner)
	setmetatable(self, Gun)
	return self
end

function Gun:GetDamage()
	return self:GetNumber("Damage", 8)
end

function Gun:GetFireRate()
	return self:GetNumber("FireRate", 6)
end

function Gun:GetCooldown()
	local rate = math.max(self:GetFireRate(), 0.1)
	return 1 / rate
end

function Gun:GetAmmo()
	return self:GetNumber("Ammo", 0)
end

function Gun:GetMaxAmmo()
	return self:GetNumber("MaxAmmo", self:GetAmmo())
end

return Gun
