-- Weapon-special cooldowns are scoped to the item definition that owns them.
-- The server stores remaining time in its timer table and replicates an absolute
-- ready timestamp so clients can render each inventory slot independently.
local Workspace = game:GetService("Workspace")

local WeaponSpecialCooldown = {}
local TIMER_PREFIX = "WeaponSpecial:"
local ATTRIBUTE_PREFIX = "WeaponSpecialReadyAt_"

function WeaponSpecialCooldown.TimerKey(itemId)
	if type(itemId) ~= "string" or itemId == "" then return nil end
	return TIMER_PREFIX .. itemId
end

function WeaponSpecialCooldown.ItemId(timerKey)
	if type(timerKey) ~= "string" or string.sub(timerKey, 1, #TIMER_PREFIX) ~= TIMER_PREFIX then return nil end
	local itemId = string.sub(timerKey, #TIMER_PREFIX + 1)
	return itemId ~= "" and itemId or nil
end

function WeaponSpecialCooldown.Attribute(itemId)
	if type(itemId) ~= "string" or itemId == "" then return nil end
	return ATTRIBUTE_PREFIX .. itemId
end

function WeaponSpecialCooldown.Remaining(player, itemId)
	local attribute = WeaponSpecialCooldown.Attribute(itemId)
	if not player or not attribute then return 0 end
	return math.max(0, (tonumber(player:GetAttribute(attribute)) or 0) - Workspace:GetServerTimeNow())
end

return WeaponSpecialCooldown
