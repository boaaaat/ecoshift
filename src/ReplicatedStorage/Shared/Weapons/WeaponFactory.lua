local WeaponUtil = require(script.Parent.WeaponUtil)
local Sword = require(script.Parent.Sword)
local Bow = require(script.Parent.Bow)
local Gun = require(script.Parent.Gun)
local Shield = require(script.Parent.Shield)
local Throwable = require(script.Parent.Throwable)

local WeaponFactory = {}

local TYPE_MAP = {
	sword = Sword,
	swords = Sword,
	bow = Bow,
	bows = Bow,
	gun = Gun,
	guns = Gun,
	shield = Shield,
	shields = Shield,
	throwable = Throwable,
	throwables = Throwable,
}

local function isHarvestTool(tool)
	local weaponType = WeaponUtil.GetType(tool)
	if weaponType and weaponType ~= "" then
		return false
	end
	local toolType = WeaponUtil.GetString(tool, "ToolType", "")
	return toolType ~= ""
end

function WeaponFactory.GetType(tool)
	local t = WeaponUtil.GetType(tool)
	return (t and t:lower()) or ""
end

function WeaponFactory.Create(tool, owner)
	if not tool then return nil end
	if isHarvestTool(tool) then return nil end
	local t = WeaponFactory.GetType(tool)
	local cls = TYPE_MAP[t]
	if not cls then return nil end
	return cls.new(tool, owner)
end

return WeaponFactory
