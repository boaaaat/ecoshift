local WeaponBase = require(script.Parent.WeaponBase)

local Shield = {}
Shield.__index = Shield
setmetatable(Shield, WeaponBase)

function Shield.new(tool, owner)
	local self = WeaponBase.new(tool, owner)
	setmetatable(self, Shield)
	return self
end

function Shield:GetDurability()
	return self:GetNumber("Durability", 100)
end

function Shield:GetBlockPercent()
	return self:GetNumber("BlockPercent", 0.4)
end

return Shield
