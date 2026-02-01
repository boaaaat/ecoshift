local WeaponBase = require(script.Parent.WeaponBase)

local Sword = {}
Sword.__index = Sword
setmetatable(Sword, WeaponBase)

function Sword.new(tool, owner)
	local self = WeaponBase.new(tool, owner)
	setmetatable(self, Sword)
	return self
end

function Sword:GetDamage()
	return self:GetNumber("Damage", 10)
end

function Sword:GetRange()
	return self:GetNumber("Range", 8)
end

function Sword:GetAttackSpeed()
	return self:GetNumber("AttackSpeed", 1.0)
end

function Sword:GetCooldown()
	local spd = math.max(self:GetAttackSpeed(), 0.1)
	return 1 / spd
end

return Sword
