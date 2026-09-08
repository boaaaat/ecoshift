-- Item.lua
local Item = {}
Item.__index = Item

function Item.new(def)
	local self = setmetatable({}, Item)
	self.Id = def.Id
	self.Name = def.Name or def.Id
	self.Description = def.Description
	self.StackSize = def.StackSize or 99
	self.Tags = def.Tags or {}
	self.Icon = def.Icon
	self.IconColor = def.IconColor
	return self
end

function Item:HasTag(tag)
	for _, t in ipairs(self.Tags) do
		if t == tag then
			return true
		end
	end
	return false
end

return Item
