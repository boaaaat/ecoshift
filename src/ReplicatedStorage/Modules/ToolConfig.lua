local ToolConfig = {}


local function getNumber(obj, name, default)
	local v = obj:GetAttribute(name)
	if typeof(v) == "number" then return v end
	local child = obj:FindFirstChild(name)
	if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
		return child.Value
	end
	return default
end


local function getString(obj, name, default)
	local v = obj:GetAttribute(name)
	if typeof(v) == "string" then return v end
	return default
end


function ToolConfig.Read(tool: Tool)
	assert(tool and tool:IsA("Tool"), "ToolConfig.Read expects a Tool instance")
	local damage = getNumber(tool, "Damage", 0)
	local harvest = getNumber(tool, "HarvestDamage", damage)
	local range = getNumber(tool, "Range", 8)
	return {
		ToolType = getString(tool, "ToolType", ""),
		Damage = math.floor(tonumber(damage) or 0),
		HarvestDamage = math.floor(tonumber(harvest) or 0),
		Range = math.floor(tonumber(range) or 0),
		Cooldown = tonumber(getNumber(tool, "Cooldown", 0.6)) or 0.6,
	}
end


return ToolConfig
