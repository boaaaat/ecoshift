local WeaponUtil = {}

local function readValue(tool, name)
	local attr = tool and tool:GetAttribute(name)
	if attr ~= nil then
		return attr
	end
	local child = tool and tool:FindFirstChild(name)
	if child and child:IsA("ValueBase") then
		return child.Value
	end
	return nil
end

function WeaponUtil.GetNumber(tool, name, default)
	local v = readValue(tool, name)
	if typeof(v) == "number" then
		return v
	end
	if typeof(v) == "string" then
		local n = tonumber(v)
		if n then return n end
	end
	return default
end

function WeaponUtil.GetString(tool, name, default)
	local v = readValue(tool, name)
	if typeof(v) == "string" then
		return v
	end
	if v ~= nil then
		return tostring(v)
	end
	return default
end

function WeaponUtil.GetType(tool)
	return WeaponUtil.GetString(tool, "WeaponType") or WeaponUtil.GetString(tool, "Type") or ""
end

return WeaponUtil
