-- Structural validation shared by save publication and resume fallback.
-- This deliberately avoids requiring gameplay services so it is safe in the
-- lobby and before the expedition service graph has initialized.
local Validator = {}

local function arrayShape(value, minimum, maximum)
	assert(type(value) == "table", "Saved array missing")
	local length = #value
	assert(length >= minimum and length <= maximum, "Saved array length changed")
	local count = 0
	for index in pairs(value) do
		assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= length, "Saved array is sparse")
		count += 1
	end
	assert(count == length, "Saved array is sparse")
	return length
end

local function inventory(state)
	assert(type(state) == "table", "Player inventory missing")
	arrayShape(state.Hotbar, 6, 6)
	local capacity = arrayShape(state.Storage, 18, 36)
	assert(state.StorageCapacity == nil or state.StorageCapacity == capacity, "Saved storage capacity changed")
	arrayShape(state.Equipment, 4, 4)
	arrayShape(state.Accessory, 4, 4)
	for _, kind in ipairs({"Hotbar", "Storage", "Equipment", "Accessory"}) do
		for _, entry in ipairs(state[kind]) do
			if entry ~= false then
				assert(type(entry) == "table" and type(entry.Id) == "string" and #entry.Id > 0, "Saved item is invalid")
				assert(type(entry.N) == "number" and entry.N == entry.N and entry.N % 1 == 0 and entry.N > 0, "Saved item count is invalid")
			end
		end
	end
end

local function playerState(state)
	assert(type(state) == "table", "Player snapshot missing")
	assert(state.TransformIsRoot == nil or type(state.TransformIsRoot) == "boolean", "Player transform mode invalid")
	inventory(state.Inventory)
	assert(type(state.Stats) == "table" and type(state.Stats.Base) == "table", "Player stats missing")
	assert(type(state.Death) == "table" and type(state.Death.Downed) == "boolean", "Player death state missing")
	if state.Death.Downed then
		arrayShape(state.Death.Transform, 12, 12)
		assert(state.Death.DeathId == nil or (type(state.Death.DeathId) == "string" and #state.Death.DeathId > 0
			and #state.Death.DeathId <= 80), "Saved death id is invalid")
		assert(state.Death.DownedFor == nil or (type(state.Death.DownedFor) == "number" and state.Death.DownedFor == state.Death.DownedFor
			and state.Death.DownedFor >= 0 and state.Death.DownedFor <= 1e9), "Saved downed duration is invalid")
	else
		-- A living player is always loaded before a snapshot may publish. Missing
		-- these fields means cleanup won the departure race and produced defaults.
		arrayShape(state.Transform, 12, 12)
		assert(type(state.Stats.Health) == "number" and state.Stats.Health == state.Stats.Health, "Living player health missing")
	end
end

function Validator.Validate(snapshot, expectedRoster)
	local ok, reason = pcall(function()
		assert(type(snapshot) == "table" and snapshot.Version == 2 and snapshot.GeneratorVersion == 2, "World snapshot version changed")
		assert(snapshot.GameplayRulesVersion == 2 and snapshot.ContentRelease == 2, "World rules changed")
		assert(snapshot.WorldType == "Survival" or snapshot.WorldType == "Creative", "World type missing")
		for _, key in ipairs({"Campaign", "Interiors", "Enchanting", "LandmarkCaches", "Instruments", "Elites",
			"Biome", "Round", "DayNight", "Match", "Generated", "Structures", "Drops", "Controls",
			"RunStats", "Enemies", "Auxiliary", "Exploration", "Players"}) do
			assert(type(snapshot[key]) == "table", "World section missing: " .. key)
		end
		arrayShape(snapshot.Drops, 0, 3000)
		for _, drop in ipairs(snapshot.Drops) do
			assert(type(drop) == "table" and type(drop.Id) == "string" and #drop.Id > 0, "Saved ground item is invalid")
			assert(type(drop.N) == "number" and drop.N == drop.N and drop.N % 1 == 0 and drop.N > 0, "Saved ground item count is invalid")
			arrayShape(drop.Transform, 12, 12)
			assert(drop.LifetimeRemaining == nil or (type(drop.LifetimeRemaining) == "number" and drop.LifetimeRemaining == drop.LifetimeRemaining
				and drop.LifetimeRemaining >= 0 and drop.LifetimeRemaining <= 600), "Saved ground item lifetime is invalid")
		end
		local count = 0
		for userId, state in pairs(snapshot.Players) do
			assert(type(userId) == "string" and tonumber(userId), "Saved player id is invalid")
			playerState(state)
			count += 1
		end
		if type(expectedRoster) == "number" then
			assert(count == expectedRoster, "Saved crew is incomplete")
		elseif type(expectedRoster) == "table" then
			assert(count == #expectedRoster, "Saved crew is incomplete")
			for _, userId in ipairs(expectedRoster) do
				assert(snapshot.Players[tostring(userId)] ~= nil, "Saved crew member is missing")
			end
		end
	end)
	return ok, ok and nil or tostring(reason)
end

return Validator
