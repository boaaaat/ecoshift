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
	-- Also check for child StringValue
	local child = obj:FindFirstChild(name)
	if child and child:IsA("StringValue") then
		return child.Value
	end
	return default
end


function ToolConfig.Read(tool: Tool)
	assert(tool and tool:IsA("Tool"), "ToolConfig.Read expects a Tool instance")
	local damage = getNumber(tool, "Damage", 0)
	local range = getNumber(tool, "Range", 8)
	local multiplier = getNumber(tool, "Multiplier", 1)
	local toolType = getString(tool, "ToolType", "")
	
	-- DEBUG: Log raw attribute values
	print(string.format("[ToolConfig] Reading %s: ToolType attr=%s, Damage=%s, Multiplier=%s", 
		tool.Name, 
		tostring(tool:GetAttribute("ToolType")),
		tostring(tool:GetAttribute("Damage")),
		tostring(tool:GetAttribute("Multiplier"))))
	
	return {
		ToolType = toolType,
		Damage = math.floor(tonumber(damage) or 0),
		Range = math.floor(tonumber(range) or 0),
		Cooldown = tonumber(getNumber(tool, "Cooldown", 0.6)) or 0.6,
		Multiplier = tonumber(multiplier) or 1,
	}
end


return ToolConfig
