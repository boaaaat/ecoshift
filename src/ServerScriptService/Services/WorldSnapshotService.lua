-- Server-owned world state. Require before gameplay services so departure capture
-- runs before their PlayerRemoving cleanup; no snapshot data comes from clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Codec = require(script.Parent.WorldSnapshotCodec)
local Snapshot = { Version = 1, GeneratorVersion = 1, MaxBytes = 3500000, _players = {}, _ready = {}, _errors = {} }
local function service(name) return require(script.Parent[name]) end
local AUXILIARY = { "EventService", "ObjectiveService", "ThreatService", "ExpeditionRewardsService" }

function Snapshot:CapturePlayer(player)
	local key = tostring(player.UserId)
	if not self._ready[player] or player:GetAttribute("WorldPlayerRestoring") then return self._players[key] end
	local char = player.Character
	local state = {
		Role = player:GetAttribute("Role"),
		Inventory = service("InventoryService"):CaptureWorldState(player),
		Stats = service("StatsService"):CaptureWorldState(player),
		Death = service("DeathService"):CaptureWorldState(player),
	}
	if char and char.Parent then
		state.Transform = Codec.CFrame(char:GetPivot())
		state.WetStacks = char:GetAttribute("WetStacks") or 0
		state.ResistEffects = service("InventoryActionService"):CaptureCharacterState(char)
	end
	self._players[key], self._errors[key] = state, nil
	return state
end

Players.PlayerRemoving:Connect(function(player)
	local ok, err = pcall(Snapshot.CapturePlayer, Snapshot, player)
	if not ok then Snapshot._errors[tostring(player.UserId)] = tostring(err); warn("[WorldSnapshot] Departure capture failed:", err) end
	Snapshot._ready[player] = nil
end)

local function markJoiningPlayer(player)
	player:SetAttribute("WorldPlayerLoading", true)
	local state = Snapshot._players[tostring(player.UserId)]
	if state then
		player:SetAttribute("WorldPlayerRestoring", true)
		-- A fresh character is needed to reconstruct a saved downed body.
		player:SetAttribute("IsDead", false)
		service("RoleService"):ApplyRunRole(player, state.Role)
	end
end
Players.PlayerAdded:Connect(markJoiningPlayer)

function Snapshot:StageWorld(snapshot)
	assert(not self._staged, "World snapshot already staged")
	self._staged = true
	ReplicatedStorage:SetAttribute("WorldRestoring", true)
	if not snapshot then
		for _, player in ipairs(Players:GetPlayers()) do markJoiningPlayer(player) end
		return true
	end
	assert(type(snapshot) == "table" and snapshot.Version == self.Version and snapshot.GeneratorVersion == self.GeneratorVersion, "Unsupported world snapshot/generator version")
	assert(#HttpService:JSONEncode(snapshot) <= self.MaxBytes, "World snapshot exceeds supported size")
	Codec.BoundedCount(snapshot.Players, 100)
	self._snapshot, self._players = Codec.Copy(snapshot), Codec.Copy(snapshot.Players)
	for _, player in ipairs(Players:GetPlayers()) do markJoiningPlayer(player) end
	service("BiomeService"):RestoreWorldState(snapshot.Biome)
	service("RoundService"):RestoreWorldState(snapshot.Round)
	service("DayNightService"):RestoreWorldState(snapshot.DayNight)
	service("DeathService"):RestoreRunState(snapshot.RunStats)
	service("GameStateService"):RestoreWorldState(snapshot.Match)
	service("ChunkStreamingService"):RestoreWorldState(snapshot.Generated)
	return true
end

function Snapshot:RestoreWorld()
	assert(self._staged and not self._restored, "Stage world once before restoring world objects")
	local state = self._snapshot
	if state then
		service("BuildService"):RestoreWorldState(state.Structures)
		service("ItemDropService"):RestoreWorldState(state.Drops)
		service("WorldControlService"):RestoreWorldState(state.Controls)
		for _, name in ipairs(AUXILIARY) do
			local ok, reason = service(name):RestoreState(state.Auxiliary[name])
			assert(ok ~= false, name .. " restore failed: " .. tostring(reason))
		end
	end
	self._restored = true
	return true
end

local function restoreEnemies(states)
	Codec.BoundedCount(states, Codec.MaxEnemies)
	local root = ServerStorage:FindFirstChild("EnemyPrefabs")
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then folder = Instance.new("Folder"); folder.Name = "Enemies"; folder.Parent = workspace end
	local biome = root and root:FindFirstChild(service("BiomeService"):GetCurrent())
	for _, actor in ipairs(states) do
		local prefab = (biome and biome:FindFirstChild(actor.Prefab)) or (root and root:FindFirstChild(actor.Prefab, true))
		assert(prefab, "Saved enemy prefab unavailable: " .. tostring(actor.Prefab))
		if prefab:IsA("Folder") then prefab = prefab:FindFirstChildWhichIsA("Model", true) end
		assert(prefab and prefab:IsA("Model"), "Saved enemy prefab must be a model")
		local model = prefab:Clone()
		model:SetAttribute("EntityId", actor.Prefab)
		Codec.ApplyActor(model, actor)
		model.Parent = folder
		service("EntityAIService"):BindEntity(model, actor.EntityType)
		service("LootService"):_bindMonster(model)
	end
end

function Snapshot:CompleteWorldRestore()
	assert(self._restored and not self._complete, "Restore world objects before completing world restore")
	local generated = workspace:FindFirstChild("GeneratedWorld")
	assert(generated and generated:GetAttribute("Generated"), "Terrain must finish generating before activation")
	local state = self._snapshot
	if state then
		-- Rebase deadlines now: loading and offline time never consume survival time.
		service("BiomeService"):RestoreWorldState(state.Biome)
		service("RoundService"):RestoreWorldState(state.Round)
		service("WorldControlService"):RestoreWorldState(state.Controls)
		restoreEnemies(state.Enemies)
	else
		local freshBiome = service("BiomeService"):CaptureWorldState()
		freshBiome.Elapsed, freshBiome.SinceChange, freshBiome.Remaining = 0, 0, freshBiome.Duration
		if freshBiome.WeatherRemaining ~= false then freshBiome.WeatherRemaining = service("BiomeService"):GetData().WeatherCycleSeconds or 60 end
		service("BiomeService"):RestoreWorldState(freshBiome)
		service("RoundService"):RestoreWorldState({ Elapsed = 0, Ended = false })
	end
	service("RoundService"):CompleteWorldRestore()
	service("ItemDropService"):CompleteWorldRestore()
	ReplicatedStorage:SetAttribute("WorldRestoring", false)
	for _, name in ipairs(AUXILIARY) do
		local adapter = service(name)
		if adapter.CompleteWorldRestore then
			local ok, reason = adapter:CompleteWorldRestore()
			assert(ok ~= false, name .. " activation failed: " .. tostring(reason))
		end
	end
	if state and state.Match.MatchState == "GameOver" then service("BiomeService"):Pause() end
	self._complete = true
	return true
end

function Snapshot:RestorePlayer(player)
	assert(self._complete, "Activate generated world before restoring player")
	if self._ready[player] then return true end
	local char = assert(player.Character, "Character required for player restore")
	assert(char:FindFirstChildOfClass("Humanoid"), "Humanoid required for player restore")
	local state = self._players[tostring(player.UserId)]
	if state then
		player:SetAttribute("WorldPlayerRestoring", true)
		service("RoleService"):ApplyRunRole(player, state.Role)
		char:SetAttribute("WorldStateRestored", true)
		service("StatsService"):RestoreWorldState(player, state.Stats)
		service("InventoryService"):RestoreWorldState(player, state.Inventory)
		if state.Transform then char:PivotTo(Codec.ReadCFrame(state.Transform)) end
		char:SetAttribute("WetStacks", Codec.Number(state.WetStacks or 0, 0, 5))
		service("InventoryActionService"):RestoreCharacterState(char, state.ResistEffects or {})
		service("DeathService"):RestoreWorldState(player, state.Death)
	end
	player:SetAttribute("WorldPlayerRestoring", nil)
	player:SetAttribute("WorldPlayerLoading", nil)
	self._ready[player] = true
	self:CapturePlayer(player)
	service("GameStateService"):SendToPlayer(player)
	return true
end

function Snapshot:Capture()
	assert(self._complete and not ReplicatedStorage:GetAttribute("WorldRestoring"), "Cannot save incomplete world restore")
	for _, player in ipairs(Players:GetPlayers()) do
		assert(self._ready[player] or self._players[tostring(player.UserId)], "Player still loading; refusing incomplete save")
		self:CapturePlayer(player)
	end
	assert(next(self._errors) == nil, "Player departure capture failed; refusing stale save")
	local enemies, folder = {}, workspace:FindFirstChild("Enemies")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if model:IsA("Model") then
			local actor = Codec.Actor(model)
			if actor then assert(#enemies < Codec.MaxEnemies, "Enemy snapshot capacity exceeded"); table.insert(enemies, actor) end
		end
	end
	local auxiliary = {}
	for _, name in ipairs(AUXILIARY) do auxiliary[name] = service(name):CaptureState() end
	local state = {
		Version = self.Version, GeneratorVersion = self.GeneratorVersion,
		Biome = service("BiomeService"):CaptureWorldState(), Round = service("RoundService"):CaptureWorldState(),
		DayNight = service("DayNightService"):CaptureWorldState(), Match = service("GameStateService"):CaptureWorldState(),
		Generated = service("ChunkStreamingService"):CaptureWorldState(), Structures = service("BuildService"):CaptureWorldState(),
		Drops = service("ItemDropService"):CaptureWorldState(), Controls = service("WorldControlService"):CaptureWorldState(),
		RunStats = service("DeathService"):CaptureRunState(), Players = Codec.Copy(self._players), Enemies = enemies, Auxiliary = auxiliary,
	}
	Codec.BoundedCount(state.Players, 100)
	state = Codec.Copy(state)
	assert(#HttpService:JSONEncode(state) <= self.MaxBytes, "World snapshot capacity exceeded; refusing partial save")
	return state
end
Snapshot.CaptureWorld = Snapshot.Capture
return Snapshot
