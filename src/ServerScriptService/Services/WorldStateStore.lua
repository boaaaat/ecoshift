-- Durable session authority. Immutable snapshot chunks become visible through one
-- fenced pointer update; a stale server can never publish over its successor.
local DSS = game:GetService("DataStoreService")
local Http = game:GetService("HttpService")
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)
local records = DSS:GetDataStore("EcoshiftWorldSessions_v1")
local chunks = DSS:GetDataStore("EcoshiftWorldSnapshots_v1")
local reservations = DSS:GetDataStore("EcoshiftReservedWorlds_v1")
local assignments = DSS:GetDataStore("EcoshiftRunAssignments_v1")
local Service = { LeaseSeconds = 120 }
local fresh = Instance.new("DataStoreGetOptions")
fresh.UseCache = false

local function validId(id)
	return type(id) == "string" and #id > 0 and #id <= 40 and id:match("^[%w_:%-]+$") ~= nil
end
local function call(fn)
	local ok, value
	for attempt = 1, 3 do
		ok, value = pcall(fn)
		if ok then return true, value end
		if attempt < 3 then task.wait(attempt) end
	end
	warn("[WorldStateStore] Storage unavailable:", value)
	return false, "WorldStorageUnavailable"
end
function Service:Get(id)
	if not validId(id) then return nil, "InvalidWorldId" end
	local ok, record = call(function() return records:GetAsync(id, fresh) end)
	if not ok then return nil, record end
	if not record then return nil, "WorldNotFound" end
	if record.SchemaVersion ~= 1 or record.Id ~= id then return nil, "UnsupportedWorldVersion" end
	return record
end
function Service:Mutate(id, transform)
	if not validId(id) then return nil, "InvalidWorldId" end
	local reason
	local ok, result = call(function() return records:UpdateAsync(id, function(raw)
		reason = nil
		if raw and (raw.SchemaVersion ~= 1 or raw.Id ~= id) then reason = "UnsupportedWorldVersion"; return nil end
		local nextValue, failure = transform(raw and Util.DeepCopy(raw))
		if not nextValue then reason = failure or "WorldChanged"; return nil end
		nextValue.Revision = (raw and raw.Revision or 0) + 1
		nextValue.UpdatedAt = os.time()
		return nextValue
	end) end)
	if not ok or reason then return nil, reason or result end
	return result
end
function Service:Assign(userId, record)
	local value = { WorldId = record.Id, Generation = record.Generation, IssuedAt = record.LaunchedAt }
	local ok, result = call(function() return assignments:UpdateAsync(tostring(userId), function(old)
		if old and old.IssuedAt > value.IssuedAt then return nil end
		if old and old.WorldId==value.WorldId and old.Generation>value.Generation then return nil end
		if old and old.IssuedAt==value.IssuedAt and old.WorldId~=value.WorldId then return nil end
		return value
	end) end)
	return ok and result and result.WorldId == record.Id and result.Generation == record.Generation
end
function Service:GetAssignment(userId)
	local ok, value = call(function() return assignments:GetAsync(tostring(userId), fresh) end)
	if not ok then return nil,"WorldStorageUnavailable" end
	return value
end
function Service:RegisterReservation(record)
	local ok = call(function() return reservations:SetAsync(record.PrivateServerId, {
		WorldId = record.Id, Generation = record.Generation,
	}) end)
	return ok
end
function Service:ResolveReservation(privateServerId)
	if type(privateServerId) ~= "string" or #privateServerId == 0 then return nil, "ReservedExpeditionRequired" end
	local ok, link = call(function() return reservations:GetAsync(privateServerId, fresh) end)
	if not ok or not link then return nil, "ReservationUnavailable" end
	local record, reason = self:Get(link.WorldId)
	if not record then return nil, reason end
	if record.Generation ~= link.Generation or record.PrivateServerId ~= privateServerId then return nil, "ReservationExpired" end
	return record
end
function Service:AcquireServer(record, jobId, nativeType)
	return self:Mutate(record.Id, function(current)
		if not current or current.Generation ~= record.Generation or current.PrivateServerId ~= game.PrivateServerId
			or current.MatchmakingType ~= nativeType then return nil, "ReservationChanged" end
		if current.Phase ~= "Launching" and current.Phase ~= "Active" then return nil, "CrewResumeRequired" end
		if current.Phase == "Launching" and (current.LaunchUntil or 0) <= os.time() then return nil, "CrewResumeRequired" end
		if current.ServerJobId and current.ServerJobId ~= jobId then
			-- A stopped generation must be resumed by the full crew with a new reservation.
			return nil, (current.ServerLeaseUntil or 0) > os.time() and "WorldAlreadyRunning" or "CrewResumeRequired"
		end
		current.ServerJobId, current.ServerLeaseUntil = jobId, os.time() + self.LeaseSeconds
		current.Phase = "Active"
		return current
	end)
end
function Service:Renew(record, jobId)
	return self:Mutate(record.Id, function(current)
		if not current or current.Generation ~= record.Generation or current.ServerJobId ~= jobId
			or current.Phase ~= "Active" or (current.ServerLeaseUntil or 0) <= os.time() then return nil, "WorldLeaseLost" end
		current.ServerLeaseUntil = os.time() + self.LeaseSeconds
		return current
	end)
end
local function split(text)
	local result, start = {}, 1
	while start <= #text do
		local last = math.min(start + 999999, #text)
		-- DataStore strings must be valid UTF-8, including chunk boundaries.
		if last < #text then
			while text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last -= 1 end
		end
		table.insert(result, text:sub(start, last)); start = last + 1
	end
	return result
end
function Service:WriteSnapshot(record, jobId, snapshot, finalPhase)
	local encodedOK, encoded = pcall(function() return Http:JSONEncode(snapshot) end)
	if not encodedOK or #encoded > 16000000 then return nil, "SnapshotTooLargeOrInvalid" end
	local pieces, nonce = split(encoded), Http:GenerateGUID(false)
	for index, piece in ipairs(pieces) do
		local ok = call(function() return chunks:SetAsync(nonce .. ":" .. index, piece) end)
		if not ok then return nil, "SnapshotWritePending" end
	end
	local reference = { Id = nonce, Count = #pieces, Bytes = #encoded }
	local obsolete
	local updated, reason = self:Mutate(record.Id, function(current)
		-- UpdateAsync can commit despite a transport error. Repeating this exact
		-- pointer publication must acknowledge it before checking a final phase.
		if current and current.Snapshot and current.Snapshot.Id==nonce then obsolete=nil; return current end
		if not current or current.Generation ~= record.Generation or current.ServerJobId ~= jobId
			or current.Phase ~= "Active" or (current.ServerLeaseUntil or 0) <= os.time() then return nil, "WorldLeaseLost" end
		obsolete = current.PreviousSnapshot
		current.PreviousSnapshot, current.Snapshot = current.Snapshot, reference
		current.SnapshotRevision = (current.SnapshotRevision or 0) + 1
		current.SavedAt = os.time()
		if finalPhase then
			current.Phase = finalPhase
			current.ServerLeaseUntil = 0
		end
		return current
	end)
	if updated and obsolete and obsolete.Id~=updated.Snapshot.Id
		and (not updated.PreviousSnapshot or obsolete.Id~=updated.PreviousSnapshot.Id) then
		task.spawn(function()
			for index = 1, obsolete.Count do call(function() chunks:RemoveAsync(obsolete.Id .. ":" .. index) end) end
		end)
	end
	return updated, reason
end
function Service:ReadSnapshot(record)
	local ref = record.Snapshot
	if not ref then return nil, nil end
	if not validId(ref.Id) or type(ref.Count) ~= "number" or ref.Count < 1 or ref.Count > 17 then return nil, "InvalidSnapshot" end
	local pieces = {}
	for index = 1, ref.Count do
		local ok, piece = call(function() return chunks:GetAsync(ref.Id .. ":" .. index) end)
		if not ok or type(piece) ~= "string" then return nil, "SnapshotUnavailable" end
		table.insert(pieces, piece)
	end
	local encoded = table.concat(pieces)
	if #encoded ~= ref.Bytes then return nil, "IncompleteSnapshot" end
	local ok, snapshot = pcall(function() return Http:JSONDecode(encoded) end)
	if not ok or type(snapshot) ~= "table" then return nil, "InvalidSnapshot" end
	return snapshot
end
return Service
