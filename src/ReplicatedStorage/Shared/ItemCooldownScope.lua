-- Shared names for server-owned cooldowns that belong to one item definition.
-- Absolute ready timestamps let clients render each inventory slot independently.
local Workspace = game:GetService("Workspace")

local ItemCooldownScope = {}
local PREFIXES = {
	WeaponSpecial = "WeaponSpecial",
	Medical = "MedicalItem",
}

function ItemCooldownScope.TimerKey(scope, itemId)
	local prefix = PREFIXES[scope]
	if not prefix or type(itemId) ~= "string" or itemId == "" then return nil end
	return prefix .. ":" .. itemId
end

function ItemCooldownScope.ReadTimerKey(timerKey)
	if type(timerKey) ~= "string" then return nil end
	for scope, prefix in pairs(PREFIXES) do
		local marker = prefix .. ":"
		if string.sub(timerKey, 1, #marker) == marker then
			local itemId = string.sub(timerKey, #marker + 1)
			if itemId ~= "" then return scope, itemId end
		end
	end
	return nil
end

function ItemCooldownScope.Attribute(scope, itemId)
	local prefix = PREFIXES[scope]
	if not prefix or type(itemId) ~= "string" or itemId == "" then return nil end
	return prefix .. "ReadyAt_" .. itemId
end

function ItemCooldownScope.SetReadyAt(player, scope, itemId, remaining)
	local attribute = ItemCooldownScope.Attribute(scope, itemId)
	if not player or not attribute then return end
	player:SetAttribute(attribute, Workspace:GetServerTimeNow() + math.max(0, tonumber(remaining) or 0))
end

function ItemCooldownScope.Remaining(player, scope, itemId)
	local attribute = ItemCooldownScope.Attribute(scope, itemId)
	if not player or not attribute then return 0 end
	return math.max(0, (tonumber(player:GetAttribute(attribute)) or 0) - Workspace:GetServerTimeNow())
end

return ItemCooldownScope
