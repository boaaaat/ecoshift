-- A manifest is the commit marker for a reservation spanning several player keys.
-- Partial commits stay hidden and are completed by retry, never rolled back.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.WorldSaveConfig)
local Util = require(RS.Shared.Util)
local archives = DataStoreService:GetDataStore(Config.ArchiveStore)
local manifests = DataStoreService:GetDataStore(Config.ManifestStore)
local Service = {}
local fresh = Instance.new("DataStoreGetOptions")
fresh.UseCache = false

local function validId(id)
	return type(id) == "string" and #id > 0 and #id <= 40 and id:match("^[%w_:%-]+$") ~= nil
end
local function validUserId(id)
	return type(id) == "number" and id % 1 == 0 and id > 0 and id <= 9007199254740991
end
local function nonnegativeInteger(value)
	return type(value) == "number" and value % 1 == 0 and value >= 0 and value < 9007199254740991
end
local function rosterIds(roster)
	if type(roster) ~= "table" then return nil end
	local ids, seen = {}, {}
	for index, id in pairs(roster) do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not validUserId(id) or seen[id] then return nil end
		seen[id] = true
		table.insert(ids, id)
	end
	if #ids < 1 or #ids > Config.MaxRosterSize then return nil end
	table.sort(ids)
	return ids
end
local function sameRoster(a, b)
	if #a ~= #b then return false end
	for i, id in ipairs(a) do if b[i] ~= id then return false end end
	return true
end
local function call(callback)
	local ok, value
	for attempt = 1, Config.DataStoreAttempts do
		ok, value = pcall(callback)
		if ok then return true, value end
		if attempt < Config.DataStoreAttempts then task.wait(attempt) end
	end
	warn("[WorldSaveService] Archive operation unavailable: " .. tostring(value))
	return false, "ArchiveUnavailable"
end
local function archiveData(raw)
	if raw == nil then return { SchemaVersion = Config.SchemaVersion, Revision = 0, Slots = {} } end
	if type(raw) ~= "table" or raw.SchemaVersion ~= Config.SchemaVersion or type(raw.Slots) ~= "table"
		or not nonnegativeInteger(raw.Revision) then return nil end
	local count = 0
	for slotId, slot in pairs(raw.Slots) do
		count += 1
		if count > Config.MaxSlots or not validId(slotId) or type(slot) ~= "table" or slot.Id ~= slotId
			or not validId(slot.WorldId) or not validId(slot.Token) or type(slot.Name) ~= "string"
			or (slot.State ~= "Pending" and slot.State ~= "Committed") or not nonnegativeInteger(slot.CreatedAt)
			or not nonnegativeInteger(slot.UpdatedAt) or not nonnegativeInteger(slot.SnapshotRevision) then return nil end
	end
	return Util.DeepCopy(raw)
end
local function manifestData(raw)
	if type(raw) ~= "table" or raw.SchemaVersion ~= Config.SchemaVersion or not validId(raw.WorldId)
		or not validId(raw.Token) or type(raw.OwnerIds) ~= "table" or type(raw.SlotIds) ~= "table"
		or not nonnegativeInteger(raw.Revision) or not nonnegativeInteger(raw.SnapshotRevision)
		or not nonnegativeInteger(raw.CreatedAt) then return nil end
	if raw.State ~= "Reserving" and raw.State ~= "Reserved" and raw.State ~= "Committing"
		and raw.State ~= "Committed" and raw.State ~= "Aborting" and raw.State ~= "Aborted" then return nil end
	local owners = rosterIds(raw.OwnerIds)
	if not owners or not sameRoster(owners, raw.OwnerIds) then return nil end
	for _, id in ipairs(owners) do if not validId(raw.SlotIds[tostring(id)]) then return nil end end
	return Util.DeepCopy(raw)
end
local function slotCount(slots)
	local count = 0
	for _ in pairs(slots) do count += 1 end
	return count
end

-- transform may return nil to cancel. The reason is captured from the final callback.
local function updateArchive(userId, transform)
	local reason
	local ok, result = call(function()
		return archives:UpdateAsync(tostring(userId), function(raw)
			reason = nil
			local data = archiveData(raw)
			if not data then reason = "InvalidArchive" return nil end
			local accepted, message = transform(data)
			if not accepted then reason = message return nil end
			data.Revision += 1
			return data
		end)
	end)
	if not ok then return false, result end
	return reason == nil, reason, result
end
local function updateManifest(worldId, token, transform)
	local reason
	local ok, result = call(function()
		return manifests:UpdateAsync(worldId, function(raw)
			reason = nil
			local data = manifestData(raw)
			if not data then reason = "ManifestMissing" return nil end
			if data.WorldId ~= worldId or data.Token ~= token then reason = "ReservationChanged" return nil end
			local accepted, message = transform(data)
			if not accepted then reason = message return nil end
			data.Revision += 1
			return data
		end)
	end)
	if not ok then return false, result end
	return reason == nil, reason, result
end

-- Server-only: this includes the reservation token and exact original roster.
function Service:GetManifest(worldId)
	if not validId(worldId) then return nil, "InvalidWorldId" end
	local ok, raw = call(function() return manifests:GetAsync(worldId, fresh) end)
	if not ok then return nil, raw end
	if raw == nil then return nil, "ManifestMissing" end
	local data = manifestData(raw)
	if not data or data.WorldId ~= worldId then return nil, "InvalidManifest" end
	return data
end

function Service:ReserveRoster(worldId, roster)
	local owners = rosterIds(roster)
	if not validId(worldId) or not owners then return false, "InvalidRoster" end
	local proposed = {
		SchemaVersion = Config.SchemaVersion, WorldId = worldId, Token = HttpService:GenerateGUID(false),
		OwnerIds = owners, SlotIds = {}, State = "Reserving", Revision = 1,
		CreatedAt = os.time(), SnapshotRevision = 0,
	}
	for _, id in ipairs(owners) do proposed.SlotIds[tostring(id)] = HttpService:GenerateGUID(false) end
	local reason
	local ok, manifest = call(function()
		return manifests:UpdateAsync(worldId, function(raw)
			reason = nil
			if raw == nil then return proposed end
			local current = manifestData(raw)
			if not current then reason = "InvalidManifest" return nil end
			if current.WorldId ~= worldId or not sameRoster(current.OwnerIds, owners) then reason = "RosterMismatch" return nil end
			return current
		end)
	end)
	if not ok or reason then return false, reason or manifest end
	local token = manifest.Token
	if manifest.State == "Aborting" or manifest.State == "Aborted" then
		self:AbortRoster(worldId, token)
		return false, "ReservationAborted", token
	end
	if manifest.State == "Reserved" or manifest.State == "Committing" or manifest.State == "Committed" then return true, token end
	if manifest.State ~= "Reserving" then return false, "InvalidReservationState", token end
	for _, id in ipairs(owners) do
		local slotId = manifest.SlotIds[tostring(id)]
		local reserved, failure = updateArchive(id, function(data)
			local existing = data.Slots[slotId]
			if existing then
				if existing.WorldId == worldId and existing.Token == token then return true end
				return false, "SlotConflict"
			end
			if slotCount(data.Slots) >= Config.MaxSlots then return false, "ArchiveFull" end
			data.Slots[slotId] = {
				Id = slotId, WorldId = worldId, Token = token, State = "Pending", Name = Config.DefaultName,
				CreatedAt = manifest.CreatedAt, UpdatedAt = manifest.CreatedAt, SnapshotRevision = 0,
			}
			return true
		end)
		if not reserved then
			-- An unavailable response is not evidence that a slot write failed.
			-- Retry the same manifest instead of compensating an uncertain write.
			if failure == "ArchiveUnavailable" then return false, failure, token, id end
			local cleaned = self:AbortRoster(worldId, token)
			return false, cleaned and failure or "ReservationCleanupPending", token, id
		end
	end
	local reserved, failure = updateManifest(worldId, token, function(data)
		if data.State == "Reserved" or data.State == "Committing" or data.State == "Committed" then return true end
		if data.State ~= "Reserving" then return false, "ReservationAborted" end
		data.State, data.ReservedAt = "Reserved", os.time()
		return true
	end)
	if not reserved then
		-- A transport failure may have committed this transition; re-read/retry the same ID.
		return false, failure, token
	end
	return true, token
end

function Service:CommitRoster(worldId, token)
	if not validId(worldId) or not validId(token) then return false, "InvalidReservation" end
	local started, failure, manifest = updateManifest(worldId, token, function(data)
		if data.State == "Committing" or data.State == "Committed" then return true end
		if data.State ~= "Reserved" then return false, "ReservationNotReady" end
		data.State = "Committing"
		return true
	end)
	if not started then return false, failure end
	if manifest.State == "Committed" then return true, "AlreadyCommitted" end
	for _, id in ipairs(manifest.OwnerIds) do
		local committed = updateArchive(id, function(data)
			local slot = data.Slots[manifest.SlotIds[tostring(id)]]
			if not slot or slot.WorldId ~= worldId or slot.Token ~= token then return false, "ReservationMissing" end
			if slot.State ~= "Pending" and slot.State ~= "Committed" then return false, "InvalidSlotState" end
			slot.State, slot.UpdatedAt = "Committed", os.time()
			return true
		end)
		if not committed then return false, "CommitPending" end
	end
	local committed, commitReason = updateManifest(worldId, token, function(data)
		if data.State == "Committed" then return true end
		if data.State ~= "Committing" then return false, "ReservationChanged" end
		data.State, data.CommittedAt = "Committed", os.time()
		return true
	end)
	return committed, committed and "Committed" or commitReason
end

function Service:AbortRoster(worldId, token)
	if not validId(worldId) or not validId(token) then return false, "InvalidReservation" end
	local started, failure, manifest = updateManifest(worldId, token, function(data)
		if data.State == "Committing" or data.State == "Committed" then return false, "CommitInProgress" end
		if data.State == "Aborted" then return true end
		if data.State ~= "Reserving" and data.State ~= "Reserved" and data.State ~= "Aborting" and data.State ~= "Aborted" then return false, "InvalidReservationState" end
		data.State = "Aborting"
		return true
	end)
	if not started then return false, failure end
	if manifest.State == "Aborted" then return true, "AlreadyAborted" end
	local complete = true
	for _, id in ipairs(manifest.OwnerIds) do
		local removed = updateArchive(id, function(data)
			local slotId = manifest.SlotIds[tostring(id)]
			local slot = data.Slots[slotId]
			-- Compensation cannot remove a committed save or another transaction's slot.
			if slot and slot.WorldId == worldId and slot.Token == token and slot.State == "Pending" then data.Slots[slotId] = nil end
			return true
		end)
		if not removed then complete = false end
	end
	if not complete then return false, "ReservationCleanupPending" end
	local aborted, abortReason = updateManifest(worldId, token, function(data)
		if data.State == "Aborted" then return true end
		if data.State ~= "Aborting" then return false, "ReservationChanged" end
		data.State, data.AbortedAt = "Aborted", os.time()
		return true
	end)
	return aborted, aborted and "Aborted" or abortReason
end

-- Retain the terminal manifest as a fence against stale resume/save workers,
-- but remove every owner's playable copy and free their archive capacity.
function Service:CleanupEndedWorld(worldId)
	local manifest, reason = self:GetManifest(worldId)
	if not manifest then return false, reason end
	if manifest.WorldStatus ~= "Ended" then return false, "WorldNotEnded" end
	local complete = true
	for _, userId in ipairs(manifest.OwnerIds) do
		local removed = updateArchive(userId, function(data)
			local slotId = manifest.SlotIds[tostring(userId)]
			local slot = data.Slots[slotId]
			if slot and (slot.WorldId ~= worldId or slot.Token ~= manifest.Token) then return false, "SlotConflict" end
			data.Slots[slotId] = nil
			if data.ResumeLocks then data.ResumeLocks[worldId] = nil end
			return true
		end)
		if not removed then complete = false end
	end
	if not complete then return false, "WorldCleanupPending" end
	return updateManifest(worldId, manifest.Token, function(data)
		if data.WorldStatus ~= "Ended" then return false, "WorldNotEnded" end
		data.CopiesRemovedAt = data.CopiesRemovedAt or os.time()
		return true
	end)
end

function Service:List(player)
	local ok, raw = call(function() return archives:GetAsync(tostring(player.UserId), fresh) end)
	if not ok then return {}, raw end
	local archive = archiveData(raw)
	if not archive then return {}, "InvalidArchive" end
	local result, pending = {}, 0
	for slotId, slot in pairs(archive.Slots) do
		if type(slot) ~= "table" or slot.Id ~= slotId then return {}, "InvalidArchive" end
		local manifest, failure = self:GetManifest(slot.WorldId)
		if not manifest then return {}, failure end
		if manifest.SlotIds[tostring(player.UserId)] ~= slotId or manifest.Token ~= slot.Token then return {}, "SlotConflict" end
		if manifest.WorldStatus == "Ended" then
			local removed = self:CleanupEndedWorld(slot.WorldId)
			if not removed then pending += 1 end
		elseif slot.State == "Committed" and manifest.State == "Committed" then
			-- Explicit whitelist: no reservation tokens, payloads, currency or travel codes.
			table.insert(result, {
				Id = slot.Id, WorldId = slot.WorldId, Name = slot.Name, CreatedAt = slot.CreatedAt,
				UpdatedAt = math.max(slot.UpdatedAt, manifest.SavedAt or 0), SnapshotRevision = manifest.SnapshotRevision,
				OwnerCount = #manifest.OwnerIds, WorldType = manifest.WorldType or "Survival", Status = manifest.WorldStatus or (manifest.SnapshotRevision > 0 and "Saved" or "AwaitingSnapshot"),
			})
		elseif slot.State == "Pending" and (manifest.State == "Aborting" or manifest.State == "Aborted") then
			-- Recover compensation interrupted by a crash or a late in-flight reservation.
			local removed = updateArchive(player.UserId, function(current)
				local pendingSlot = current.Slots[slotId]
				if pendingSlot and pendingSlot.WorldId == slot.WorldId and pendingSlot.Token == slot.Token and pendingSlot.State == "Pending" then current.Slots[slotId] = nil end
				return true
			end)
			if not removed then pending += 1 end
		else pending += 1 end
	end
	table.sort(result, function(a, b) if a.UpdatedAt == b.UpdatedAt then return a.Id < b.Id end return a.UpdatedAt > b.UpdatedAt end)
	return result, nil, { PendingCount = pending, Capacity = Config.MaxSlots }
end

function Service:Rename(player, slotId, name)
	if not validId(slotId) or type(name) ~= "string" or #name > Config.MaxNameBytes then return false, "InvalidSaveName" end
	name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
	local characters = utf8.len(name)
	if not characters or characters < 1 or characters > Config.MaxNameCharacters or name:find("[%z\1-\31\127]") then return false, "InvalidSaveName" end
	local requestedAt = DateTime.now().UnixTimestampMillis
	local loaded, raw = call(function() return archives:GetAsync(tostring(player.UserId)) end)
	if not loaded then return false, raw end
	local data = archiveData(raw)
	local slot = data and data.Slots[slotId]
	if not slot or slot.State ~= "Committed" then return false, "SaveNotFound" end
	local manifest, failure = self:GetManifest(slot.WorldId)
	if not manifest or manifest.State ~= "Committed" then return false, failure or "CommitPending" end
	if manifest.SlotIds[tostring(player.UserId)] ~= slotId or manifest.Token ~= slot.Token then return false, "SaveNotFound" end
	local filtered, safeName = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not filtered or type(safeName) ~= "string" or #safeName == 0 then return false, "NameFilterUnavailable" end
	local renamed, reason = updateArchive(player.UserId, function(current)
		local currentSlot = current.Slots[slotId]
		if not currentSlot or currentSlot.State ~= "Committed" or currentSlot.Token ~= slot.Token then return false, "SaveNotFound" end
		if (currentSlot.NameUpdatedAt or 0) > requestedAt then return false, "Superseded" end
		currentSlot.Name, currentSlot.NameUpdatedAt, currentSlot.UpdatedAt = safeName, requestedAt, os.time()
		return true
	end)
	return renamed, renamed and "World renamed." or reason
end

-- Server-only ownership check. The returned manifest contains private commit tokens.
function Service:GetOwnedSlot(player, slotId)
	if not validId(slotId) then return nil, "SaveNotFound" end
	local ok, raw = call(function() return archives:GetAsync(tostring(player.UserId), fresh) end)
	if not ok then return nil, raw end
	local archive = archiveData(raw)
	local slot = archive and archive.Slots[slotId]
	if not slot or slot.State ~= "Committed" then return nil, "SaveNotFound" end
	local manifest, reason = self:GetManifest(slot.WorldId)
	if not manifest or manifest.State ~= "Committed" then return nil, reason or "CommitPending" end
	if manifest.WorldStatus == "Ended" then return nil, "ExpeditionEnded" end
	if manifest.Token ~= slot.Token or manifest.SlotIds[tostring(player.UserId)] ~= slotId then return nil, "SaveNotFound" end
	return Util.DeepCopy(slot), nil, manifest
end

-- Durable discovery lets lobby workers recover interrupted launches after the
-- short-lived MemoryStore queue has expired. Never expose this result directly.
function Service:GetRecoveryWorldIds(player)
	local ok, raw = call(function() return archives:GetAsync(tostring(player.UserId), fresh) end)
	if not ok then return nil, raw end
	local archive = archiveData(raw)
	if not archive then return nil, "InvalidArchive" end
	local ids, seen = {}, {}
	for _, slot in pairs(archive.Slots) do
		if not seen[slot.WorldId] then seen[slot.WorldId] = true; table.insert(ids, slot.WorldId) end
	end
	table.sort(ids)
	return ids
end

function Service:HasFreeSlot(userId)
	if not validUserId(userId) then return false, "InvalidPlayer" end
	local ok, raw = call(function() return archives:GetAsync(tostring(userId), fresh) end)
	if not ok then return nil, raw end
	local archive = archiveData(raw)
	if not archive then return nil, "InvalidArchive" end
	if slotCount(archive.Slots) >= Config.MaxSlots then
		-- Recover terminal copies even when the player starts from the crew menu
		-- without first opening the archive after a failed or interrupted cleanup.
		local _, cleanupReason = self:List({ UserId = userId })
		if cleanupReason then return nil, cleanupReason end
		local refreshed, latest = call(function() return archives:GetAsync(tostring(userId), fresh) end)
		if not refreshed then return nil, latest end
		archive = archiveData(latest)
		if not archive then return nil, "InvalidArchive" end
	end
	local available = math.max(0, Config.MaxSlots - slotCount(archive.Slots))
	return available > 0, available == 0 and "Every crew member needs a free save slot before starting a new world." or nil, available
end

function Service:RemoveCopy(player, slotId)
	local slot, reason = self:GetOwnedSlot(player, slotId)
	if not slot then return false, reason end
	local removed, failure = updateArchive(player.UserId, function(data)
		local current = data.Slots[slotId]
		if not current then return true end -- Same removal may have committed already.
		if current.WorldId ~= slot.WorldId or current.Token ~= slot.Token or current.State ~= "Committed" or current.CopyRevision ~= slot.CopyRevision then return false, "SaveChanged" end
		local lock = data.ResumeLocks and data.ResumeLocks[slot.WorldId]
		if lock and (lock.Until or 0) > os.time() then return false, "WorldResumeInProgress" end
		data.Slots[slotId] = nil
		return true
	end)
	return removed, removed and "Your named copy was removed. Your crew's copies and shared world remain." or failure
end

-- Restore missing named copies into the same shared world, not a cloned run.
-- Every original crew member's capacity is reserved before any copy is visible.
function Service:ReconcileRosterForResume(worldId, roster)
	local owners = rosterIds(roster)
	local manifest, reason = self:GetManifest(worldId)
	if not owners or not manifest or manifest.State ~= "Committed" or not sameRoster(owners, manifest.OwnerIds) then return false, reason or "OriginalRosterRequired" end
	local proposed = HttpService:GenerateGUID(false)
	local started, failure, current = updateManifest(worldId, manifest.Token, function(data)
		if data.State ~= "Committed" then return false, "CommitPending" end
		if data.WorldStatus == "Ended" then return false, "ExpeditionEnded" end
		local operation = data.ResumeCopies
		if not operation or operation.State == "Complete" or operation.State == "Aborted" then
			operation = { Token = proposed, State = "Reserving", StartedAt = os.time() }
		elseif operation.WorkerToken and operation.WorkerToken ~= proposed and (operation.WorkerUntil or 0) > os.time() then
			return false, "WorldResumeInProgress"
		end
		operation.Until = os.time() + 180
		operation.WorkerToken, operation.WorkerUntil = proposed, operation.Until
		data.ResumeCopies = operation
		return true
	end)
	if not started then return false, failure end
	local operation, token = current.ResumeCopies, current.ResumeCopies.Token
	local function ownsWorker(claim)
		return claim and claim.Token == token and claim.WorkerToken == proposed and (claim.WorkerUntil or 0) > os.time()
	end
	local function finishAbort()
		local marked = updateManifest(worldId, manifest.Token, function(data)
			local claim = data.ResumeCopies
			if not claim or claim.Token ~= token or claim.State == "Committing" or claim.State == "Complete" then return false, "ResumeCommitPending" end
			if claim.State == "Aborted" then return true end
			if not ownsWorker(claim) then return false, "ResumeLeaseExpired" end
			claim.State = "Aborting"; return true
		end)
		if not marked then return false end
		for _, userId in ipairs(owners) do
			local cleaned = updateArchive(userId, function(data)
				if operation.Until <= os.time() then return false, "ResumeLeaseExpired" end
				local slotId = manifest.SlotIds[tostring(userId)]
				local slot = data.Slots[slotId]
				if slot and slot.WorldId == worldId and slot.State == "Pending" and slot.ResumeToken == token then data.Slots[slotId] = nil end
				if data.ResumeLocks and data.ResumeLocks[worldId] and data.ResumeLocks[worldId].Token == token then data.ResumeLocks[worldId] = nil end
				return true
			end)
			if not cleaned then return false end
		end
		return updateManifest(worldId, manifest.Token, function(data)
			if not data.ResumeCopies or data.ResumeCopies.Token ~= token then return false, "ResumeChanged" end
			if data.ResumeCopies.State == "Aborted" then return true end
			if not ownsWorker(data.ResumeCopies) then return false, "ResumeLeaseExpired" end
			if data.ResumeCopies.State ~= "Aborting" then return false, "ResumeChanged" end
			data.ResumeCopies.State = "Aborted"; return true
		end)
	end
	if operation.State == "Aborting" then finishAbort(); return false, "ResumeSlotCleanupPending" end
	for _, userId in ipairs(owners) do
		local slotId = manifest.SlotIds[tostring(userId)]
		local reserved, reserveError = updateArchive(userId, function(data)
			if operation.Until <= os.time() then return false, "ResumeLeaseExpired" end
			data.ResumeLocks = data.ResumeLocks or {}
			local lock = data.ResumeLocks[worldId]
			if lock and lock.Token ~= token and (lock.Until or 0) > os.time() then return false, "WorldResumeInProgress" end
			local slot = data.Slots[slotId]
			if slot and (slot.WorldId ~= worldId or slot.Token ~= manifest.Token) then return false, "SlotConflict" end
			if not slot then
				if slotCount(data.Slots) >= Config.MaxSlots then return false, "A crew member needs a free save slot to restore their removed copy." end
				data.Slots[slotId] = { Id = slotId, WorldId = worldId, Token = manifest.Token, State = "Pending", ResumeToken = token, CopyRevision = token,
					Name = Config.DefaultName, CreatedAt = os.time(), UpdatedAt = os.time(), SnapshotRevision = manifest.SnapshotRevision }
			elseif slot.State == "Pending" and slot.ResumeToken ~= token then return false, "ResumeCommitPending" end
			data.ResumeLocks[worldId] = { Token = token, WorkerToken = proposed, Until = operation.Until }
			return true
		end)
		if not reserved then
			if operation.State == "Reserving" and (reserveError == "SlotConflict" or reserveError == "A crew member needs a free save slot to restore their removed copy.") then finishAbort() end
			return false, reserveError or "ResumeSlotRecoveryPending"
		end
	end
	local committing, commitError = updateManifest(worldId, manifest.Token, function(data)
		if data.WorldStatus == "Ended" then return false, "ExpeditionEnded" end
		local claim = data.ResumeCopies
		if not claim or claim.Token ~= token or (claim.State ~= "Reserving" and claim.State ~= "Committing") then return false, "ResumeChanged" end
		if not ownsWorker(claim) then return false, "ResumeLeaseExpired" end
		claim.State = "Committing"; return true
	end)
	if not committing then
		if commitError == "ExpeditionEnded" then self:CleanupEndedWorld(worldId) end
		return false, commitError
	end
	for _, userId in ipairs(owners) do
		local committed = updateArchive(userId, function(data)
			if operation.Until <= os.time() then return false, "ResumeLeaseExpired" end
			local slot = data.Slots[manifest.SlotIds[tostring(userId)]]
			local lock = data.ResumeLocks and data.ResumeLocks[worldId]
			if not slot or slot.WorldId ~= worldId or slot.Token ~= manifest.Token or not lock or lock.Token ~= token or lock.WorkerToken ~= proposed or lock.Until <= os.time() then return false, "ResumeSlotRecoveryPending" end
			slot.State, slot.ResumeToken = "Committed", nil
			return true
		end)
		if not committed then return false, "ResumeSlotRecoveryPending" end
	end
	local complete, completeError = updateManifest(worldId, manifest.Token, function(data)
		if data.WorldStatus == "Ended" then return false, "ExpeditionEnded" end
		if not data.ResumeCopies or data.ResumeCopies.Token ~= token then return false, "ResumeChanged" end
		if data.ResumeCopies.State == "Complete" then return true end
		if not ownsWorker(data.ResumeCopies) then return false, "ResumeLeaseExpired" end
		if data.ResumeCopies.State ~= "Committing" then return false, "ResumeChanged" end
		data.ResumeCopies.State = "Complete"; return true
	end)
	if not complete then
		if completeError == "ExpeditionEnded" then self:CleanupEndedWorld(worldId) end
		return false, completeError
	end
	for _, userId in ipairs(owners) do
		updateArchive(userId, function(data)
			if data.ResumeLocks and data.ResumeLocks[worldId] and data.ResumeLocks[worldId].Token == token and data.ResumeLocks[worldId].WorkerToken == proposed then data.ResumeLocks[worldId] = nil end
			return true
		end)
	end
	return true
end

-- A shared manifest follows the durable world's published pointer. A stale
-- generation or older snapshot cannot roll back the archive's displayed state.
function Service:UpdateManifest(record)
	if type(record) ~= "table" or not validId(record.Id) or not validId(record.SlotToken) then return false, "InvalidWorldManifest" end
	local revision, generation = record.SnapshotRevision or 0, record.Generation or 0
	if not nonnegativeInteger(revision) or not nonnegativeInteger(generation) then return false, "InvalidWorldManifest" end
	local phases = { Preparing = true, CrewCommitted = true, Reserving = true, Launching = true, Active = true, Paused = true, Ended = true }
	if not phases[record.Phase] then return false, "InvalidWorldStatus" end
	local updated, reason, manifest = updateManifest(record.Id, record.SlotToken, function(data)
		if data.State ~= "Committed" then return false, "CommitPending" end
		if (data.WorldGeneration or 0) > generation or data.SnapshotRevision > revision then return true end
		if data.WorldStatus == "Ended" and record.Phase ~= "Ended" and not record.Ended then return false, "ExpeditionEnded" end
		data.SnapshotRevision, data.WorldGeneration = revision, generation
		data.WorldType = record.WorldType == "Creative" and "Creative" or "Survival"
		data.WorldStatus, data.SavedAt = record.Ended and "Ended" or record.Phase, record.SavedAt or data.SavedAt or data.CommittedAt
		return true
	end)
	if updated and manifest.WorldStatus == "Ended" and not manifest.CopiesRemovedAt then
		return self:CleanupEndedWorld(record.Id)
	end
	return updated, reason, manifest
end

function Service:Init()
	-- Call-driven storage foundation; gameplay serialization belongs to the run service.
end

return Service
