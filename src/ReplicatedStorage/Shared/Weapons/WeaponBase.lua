local WeaponUtil = require(script.Parent.WeaponUtil)

local WeaponBase = {}
WeaponBase.__index = WeaponBase

function WeaponBase.new(tool, owner)
	local self = setmetatable({}, WeaponBase)
	self.Tool = tool
	self.Owner = owner
	return self
end

function WeaponBase:GetNumber(name, default)
	return WeaponUtil.GetNumber(self.Tool, name, default)
end

function WeaponBase:GetString(name, default)
	return WeaponUtil.GetString(self.Tool, name, default)
end

function WeaponBase:GetType()
	return WeaponUtil.GetType(self.Tool)
end

return WeaponBase
