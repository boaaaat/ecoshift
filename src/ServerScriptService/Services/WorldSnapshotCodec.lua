-- Explicit primitive serialization for trusted server snapshots; never dumps instances.
local Codec = { MaxStructures = 1500, MaxDrops = 3000, MaxGeneratedStates = 60000, MaxEnemies = 500 }
function Codec.Number(n, minimum, maximum)
	assert(type(n) == "number" and n == n and math.abs(n) < math.huge and (not minimum or n >= minimum) and (not maximum or n <= maximum), "Invalid snapshot number")
	return n
end
function Codec.Text(value, maximum)
	assert(type(value) == "string" and #value <= (maximum or 160), "Invalid snapshot text")
	return value
end
function Codec.CFrame(value) return { value:GetComponents() } end
function Codec.ReadCFrame(value)
	assert(type(value) == "table" and #value == 12, "Invalid snapshot transform")
	for i, n in ipairs(value) do Codec.Number(n, i <= 3 and -1e6 or -1.01, i <= 3 and 1e6 or 1.01) end
	return CFrame.new(table.unpack(value))
end
function Codec.Copy(value, depth)
	depth = depth or 0
	assert(depth < 24, "Snapshot nesting limit")
	if type(value) == "number" then return Codec.Number(value) end
	if type(value) == "string" then return Codec.Text(value, 2048) end
	if type(value) == "boolean" or value == nil then return value end
	assert(type(value) == "table", "Unsupported snapshot value")
	local result = {}
	for key, item in pairs(value) do
		assert(type(key) == "string" or type(key) == "number", "Unsupported snapshot key")
		result[key] = Codec.Copy(item, depth + 1)
	end
	return result
end
function Codec.BoundedCount(map, limit)
	assert(type(map) == "table", "Snapshot table required")
	local count = 0
	for _ in pairs(map) do count += 1; assert(count <= limit, "Snapshot capacity exceeded; refusing partial save") end
	return count
end
function Codec.Actor(model)
	local hum = model:FindFirstChildWhichIsA("Humanoid", true)
	if not hum or hum.Health <= 0 then return nil end
	return { Prefab = model:GetAttribute("SnapshotPrefab") or model:GetAttribute("EntityId") or model:GetAttribute("ConfigId") or model.Name,
		Transform = Codec.CFrame(model:GetPivot()), Health = hum.Health, MaxHealth = hum.MaxHealth,
		Level = model:GetAttribute("Level") or 1, EntityType = model:GetAttribute("EntityType") or "Monster" }
end
function Codec.ApplyActor(model, state)
	local hum = model:FindFirstChildWhichIsA("Humanoid", true)
	assert(hum, "Saved enemy prefab has no Humanoid")
	model:SetAttribute("Level", Codec.Number(state.Level, 1, 100))
	model:SetAttribute("LevelHealthApplied", true)
	model:SetAttribute("EntityType", state.EntityType)
	hum.MaxHealth = Codec.Number(state.MaxHealth, 1, 1e8)
	hum.Health = Codec.Number(state.Health, 0.001, hum.MaxHealth)
	model:PivotTo(Codec.ReadCFrame(state.Transform))
end
return Codec
