-- Small, style-neutral constructors shared by runtime-built interfaces.
local Factory = {}

function Factory.Create(className, parent, properties)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

return Factory
