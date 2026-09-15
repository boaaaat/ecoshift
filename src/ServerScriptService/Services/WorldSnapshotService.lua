-- Server-owned world state. Require before gameplay services so departure capture
-- runs before their PlayerRemoving cleanup; no snapshot data comes from clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Codec = require(script.Parent.WorldSnapshotCodec)
local Validator = require(script.Parent.WorldSnapshotValidator)
local Rules = require(ReplicatedStorage.Shared.GameRules)
local Snapshot = { Version = 2, GeneratorVersion = 2, MaxBytes = 3500000, _players = {}, _ready = {}, _errors = {} }
local function service(name) return require(script.Parent[name]) end
local AUXILIARY = { "EventService", "ObjectiveService", "ExpeditionRewardsService" }

function Snapshot:CapturePlayer(player, departingCharacter)
	local key = tostring(player.UserId)
	if not self._ready[player] or player:GetAttribute("WorldPlayerRestoring") then return self._players[key] end
	local previous = self._players[key]
	local char = departingCharacter or player.Character
	local state = {
		Role = player:GetAttribute("Role"),
		ClassLevel = player:GetAttribute("ClassLevel") or 1,
		ClassAbility = service("ClassAbilityService"):CapturePlayer(player),
		Creative = service("CreativeService"):CapturePlayer(player),
		Food = service("FoodService"):CapturePlayer(player),
		Gear = service("GearService"):CapturePlayer(player),
		InteriorId = player:GetAttribute("InteriorId"),
		Inventory = service("InventoryService"):CaptureWorldState(player),
		Stats = service("StatsService"):CaptureWorldState(player),
		Death = service("DeathService"):CaptureWorldState(player),
		CraftRefund = service("CraftingService"):CaptureRefund(player),
	}
	if char and char.Parent then
		local root = char:FindFirstChild("HumanoidRootPart")
		state.Transform = Codec.CFrame(root and root.CFrame or char:GetPivot())
		state.TransformIsRoot = root ~= nil
		state.WetStacks = char:GetAttribute("WetStacks") or 0
	elseif previous and state.Death.Downed ~= true then
		-- Teleport can remove Character before PlayerRemoving. CharacterRemoving
		-- normally refreshes this cache first; preserve that last authoritative
		-- pose and health if the platform delivers the final signals differently.
		state.Transform = Codec.Copy(previous.Transform)
		state.TransformIsRoot = previous.TransformIsRoot == true
		state.WetStacks = previous.WetStacks
		state.Stats.Health = state.Stats.Health or (previous.Stats and previous.Stats.Health)
	end
	self._players[key], self._errors[key] = state, nil
	return state
end

Players.PlayerRemoving:Connect(function(player)
	local ok, err = pcall(Snapshot.CapturePlayer, Snapshot, player)
	if not ok then Snapshot._errors[tostring(player.UserId)] = tostring(err); warn("[WorldSnapshot] Departure capture failed:", err) end
	Snapshot._ready[player] = nil
end)

local function bindCharacterCapture(player)
	player.CharacterRemoving:Connect(function(character)
		if not Snapshot._ready[player] or player:GetAttribute("WorldPlayerRestoring") then return end
		local ok, err = pcall(Snapshot.CapturePlayer, Snapshot, player, character)
		if not ok then Snapshot._errors[tostring(player.UserId)] = tostring(err); warn("[WorldSnapshot] Character departure capture failed:", err) end
	end)
end
Players.PlayerAdded:Connect(bindCharacterCapture)
for _, player in ipairs(Players:GetPlayers()) do bindCharacterCapture(player) end

local function markJoiningPlayer(player)
	player:SetAttribute("WorldPlayerLoading", true)
	local state = Snapshot._players[tostring(player.UserId)]
	if state then
		player:SetAttribute("WorldPlayerRestoring", true)
		-- A fresh character is needed to reconstruct a saved downed body.
		player:SetAttribute("IsDead", false)
		service("RoleService"):ApplyRunRole(player, state.Role, state.ClassLevel or 1)
	end
end
Players.PlayerAdded:Connect(markJoiningPlayer)

function Snapshot:StageWorld(snapshot)
	assert(not self._staged, "World snapshot already staged")
	self._staged = true
	if snapshot then
		assert(type(snapshot)=="table", "Invalid overhaul snapshot")
		Rules.Configure(snapshot.GameplayRulesVersion, snapshot.ContentRelease)
	else
		Rules.Configure(Rules.GetVersion(), Rules.GetContentRelease())
	end
	service("CampaignService"):RestoreWorldState(snapshot and snapshot.Campaign)
	service("InteriorService"):RestoreWorldState(snapshot and snapshot.Interiors)
	service("EnchantingService"):RestoreWorldState(snapshot and snapshot.Enchanting)
	service("LandmarkCacheService"):RestoreWorldState(snapshot and snapshot.LandmarkCaches)
	service("InstrumentService"):RestoreWorldState(snapshot and snapshot.Instruments)
	service("EliteEncounterService"):RestoreWorldState(snapshot and snapshot.Elites)
	-- Only overhaul snapshots are accepted after the requested data reset.
	ReplicatedStorage:SetAttribute("CookingEnabled", true)
	ReplicatedStorage:SetAttribute("WorldRestoring", true)
	if not snapshot then
		service("TeamExplorationService"):RestoreWorldState(nil)
		for _, player in ipairs(Players:GetPlayers()) do markJoiningPlayer(player) end
		return true
	end
	assert(type(snapshot) == "table" and snapshot.Version == self.Version and snapshot.GeneratorVersion == self.GeneratorVersion, "Unsupported world snapshot/generator version")
	local structurallyValid, structuralError = Validator.Validate(snapshot, ReplicatedStorage:GetAttribute("OriginalCrewSize"))
	assert(structurallyValid, "Invalid world snapshot: " .. tostring(structuralError))
	local worldType = snapshot.WorldType or "Survival"
	assert(worldType == "Survival" or worldType == "Creative", "Unsupported world type")
	assert(worldType == (workspace:GetAttribute("WorldType") or "Survival"), "Saved world type does not match its reservation")
	assert(#HttpService:JSONEncode(snapshot) <= self.MaxBytes, "World snapshot exceeds supported size")
	Codec.BoundedCount(snapshot.Players, 100)
	self._snapshot, self._players = Codec.Copy(snapshot), Codec.Copy(snapshot.Players)
	service("TeamExplorationService"):RestoreWorldState(self._snapshot.Exploration)
	for _, player in ipairs(Players:GetPlayers()) do markJoiningPlayer(player) end
	service("BiomeService"):RestoreWorldState(snapshot.Biome)
	service("RoundService"):RestoreWorldState(snapshot.Round)
	service("DayNightService"):RestoreWorldState(snapshot.DayNight, snapshot.Round and snapshot.Round.Elapsed)
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
	service("EnemySpawner"):EnsurePrefabs()
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
		service("EnemySpawner"):BindRestored(model, actor)
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
		service("RoleService"):ApplyRunRole(player, state.Role, state.ClassLevel or 1)
		char:SetAttribute("WorldStateRestored", true)
		service("StatsService"):RestoreWorldState(player, state.Stats)
		service("InventoryService"):RestoreWorldState(player, state.Inventory)
		service("InteriorService"):RestorePlayer(player, state.InteriorId)
		if state.Transform then
			local transform = Codec.ReadCFrame(state.Transform)
			local root = char:FindFirstChild("HumanoidRootPart")
			if not state.InteriorId then
				local ground = service("OverhaulWorldService"):GetHeight(transform.Position.X, transform.Position.Z) + 3.2
				if transform.Position.Y < ground then
					transform = CFrame.new(transform.Position.X, ground, transform.Position.Z) * transform.Rotation
				end
			end
			if state.TransformIsRoot and root then
				-- Terrain is regenerated from the saved biome seed. Preserve the exact
				-- X/Z pose, lifting only old or clipped saves that ended below its land.
				root.CFrame = transform
			else
				-- Compatibility with snapshots written before root transforms were tagged.
				char:PivotTo(transform)
			end
			if root then root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero end
		end
		char:SetAttribute("WetStacks", Codec.Number(state.WetStacks or 0, 0, 5))
		service("CraftingService"):RestoreRefund(player, state)
		service("ClassAbilityService"):RestorePlayer(player, state.ClassAbility)
		service("CreativeService"):RestorePlayer(player, state.Creative)
		service("FoodService"):RestorePlayer(player, state.Death.Downed and nil or state.Food)
		service("GearService"):RestorePlayer(player, state.Gear)
		-- Reconstruct a saved corpse only after every system that may need the
		-- temporary character has restored its state. This is the final operation
		-- that destroys that character and switches the client to spectating.
		service("DeathService"):RestoreWorldState(player, state.Death)
	else
		-- New expeditions start at their class-adjusted maximum; restores and revives never heal here.
		local stats = service("StatsService")
		stats:SetModifier(player, "MaxHealth", player:GetAttribute("Class_MaxHealth") or 0, "Add", "ClassHealth")
		stats:SetModifier(player, "Speed", player:GetAttribute("Class_SpeedBonus") or 0, "Mult", "ClassSpeed")
		stats:SetBase(player, "Health", stats:GetStat(player, "MaxHealth"))
		char:SetAttribute("WorldStateRestored", true)
		service("InventoryService"):Reset(player, true)
		service("CreativeService"):RestorePlayer(player, nil)
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
		if model:IsA("Model") and not model:GetAttribute("EventInstanceId") and not model:GetAttribute("InteriorId") and not model:GetAttribute("EliteEncounterId") then
			local actor = Codec.Actor(model)
			if actor then assert(#enemies < Codec.MaxEnemies, "Enemy snapshot capacity exceeded"); table.insert(enemies, actor) end
		end
	end
	local auxiliary = {}
	for _, name in ipairs(AUXILIARY) do auxiliary[name] = service(name):CaptureState() end
	local state = {
		Version = self.Version, GeneratorVersion = self.GeneratorVersion,
		GameplayRulesVersion = Rules.GetVersion(), ContentRelease = Rules.GetContentRelease(),
		Campaign = service("CampaignService"):CaptureWorldState(),
		Interiors = service("InteriorService"):CaptureWorldState(),
		Enchanting = service("EnchantingService"):CaptureWorldState(),
		LandmarkCaches = service("LandmarkCacheService"):CaptureWorldState(),
		Instruments = service("InstrumentService"):CaptureWorldState(),
		Elites = service("EliteEncounterService"):CaptureWorldState(),
		CookingVersion = 2,
		WorldType = workspace:GetAttribute("WorldType") == "Creative" and "Creative" or "Survival",
		Biome = service("BiomeService"):CaptureWorldState(), Round = service("RoundService"):CaptureWorldState(),
		DayNight = service("DayNightService"):CaptureWorldState(), Match = service("GameStateService"):CaptureWorldState(),
		Generated = service("ChunkStreamingService"):CaptureWorldState(), Structures = service("BuildService"):CaptureWorldState(),
		Drops = service("ItemDropService"):CaptureWorldState(), Controls = service("WorldControlService"):CaptureWorldState(),
		RunStats = service("DeathService"):CaptureRunState(), Players = Codec.Copy(self._players), Enemies = enemies, Auxiliary = auxiliary,
		Exploration = service("TeamExplorationService"):CaptureWorldState(),
	}
	Codec.BoundedCount(state.Players, 100)
	state = Codec.Copy(state)
	local valid, reason = Validator.Validate(state, ReplicatedStorage:GetAttribute("OriginalCrewSize"))
	assert(valid, "Refusing incomplete world snapshot: " .. tostring(reason))
	assert(#HttpService:JSONEncode(state) <= self.MaxBytes, "World snapshot capacity exceeded; refusing partial save")
	return state
end
Snapshot.CaptureWorld = Snapshot.Capture
return Snapshot
