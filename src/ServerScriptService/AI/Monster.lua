-- Monster.lua
-- Default monster AI (chase + attack).
local EntityBase = require(script.Parent.EntityBase)

local Monster = {}
Monster.__index = Monster
setmetatable(Monster, EntityBase)

function Monster.new(model, config)
	local self = EntityBase.new(model, config)
	setmetatable(self, Monster)
	return self
end

function Monster:Step(dt)
	EntityBase.Step(self, dt)
end

return Monster
