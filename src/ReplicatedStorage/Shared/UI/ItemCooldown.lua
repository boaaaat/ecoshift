-- Client-owned cooldown registry shared by item input and inventory rendering.
-- Server-owned cooldowns (weapon specials and medical items) are layered in by
-- InventoryUI from replicated player attributes.
local ItemCooldown = {}
local records = {}

local function key(uid, itemId)
	if type(uid) == "string" and uid ~= "" then return "uid:" .. uid end
	if type(itemId) == "string" and itemId ~= "" then return "item:" .. itemId end
	return nil
end

local function setRecord(recordKey, duration)
	duration = tonumber(duration)
	if not recordKey or not duration or duration <= 0 then return end
	local now = os.clock()
	local current = records[recordKey]
	local expiresAt = now + duration
	if not current or expiresAt >= current.ExpiresAt then
		records[recordKey] = { StartedAt = now, ExpiresAt = expiresAt, Duration = duration }
	end
end

function ItemCooldown.StartTool(tool, duration)
	if not tool then return end
	local itemId = tool:GetAttribute("InventoryItemId") or tool.Name
	local uid = tool:GetAttribute("GearUid")
	setRecord(key(uid, itemId), duration)
end

function ItemCooldown.StartEntry(entry, duration)
	if type(entry) ~= "table" then return end
	setRecord(key(entry.Uid, entry.Id), duration)
end

function ItemCooldown.Get(entry)
	if type(entry) ~= "table" then return 0, 0 end
	local recordKey = key(entry.Uid, entry.Id)
	local record = recordKey and records[recordKey]
	if not record then return 0, 0 end
	local remaining = record.ExpiresAt - os.clock()
	if remaining <= 0 then
		records[recordKey] = nil
		return 0, 0
	end
	return remaining, record.Duration
end

return ItemCooldown
