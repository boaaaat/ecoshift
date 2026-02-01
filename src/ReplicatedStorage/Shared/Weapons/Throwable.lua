local WeaponBase = require(script.Parent.WeaponBase)

local Throwable = {}
Throwable.__index = Throwable
setmetatable(Throwable, WeaponBase)

function Throwable.new(tool, owner)
	local self = WeaponBase.new(tool, owner)
	setmetatable(self, Throwable)
	return self
end

function Throwable:GetDamage()
	return self:GetNumber("Damage", 18)
end

function Throwable:GetThrowSpeed()
	return self:GetNumber("ThrowSpeed", 80)
end

function Throwable:GetThrowTime()
	return self:GetNumber("ThrowTime", 0.4)
end

function Throwable:GetRange()
	return self:GetNumber("Range", 120)
end

return Throwable
