-- Server-owned sandbox controls. A creative world never becomes a reward world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage.Shared
local ItemDatabase = require(Shared.Items.ItemDatabase)
local BiomeConfig = require(Shared.BiomeConfig)
local SurvivalConfig = require(Shared.SurvivalConfig)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)
local CreativeService = { _requests = {}, _busy = {}, _worldRequests = {} }
local ACTIONS = { State = true, SetMode = true, GiveItem = true, SetInvincible = true, RestoreVitals = true,
	SetTime = true, SetShiftTimer = true, SetWeather = true, SetBiome = true, SpawnMonster = true,
	ClearMonsters = true, TeleportSpawn = true }

local function available()
	return workspace:GetAttribute("WorldType") == "Creative"
end
local function number(value, minimum, maximum, integer)
	return type(value) == "number" and value == value and value >= minimum and value <= maximum
		and (not integer or value % 1 == 0)
end
local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return not player:GetAttribute("IsDead") and hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart")
end
local function sortedEntries(defs, filter)
	local entries = {}
	for id, def in pairs(defs) do
		if not filter or filter(def) then table.insert(entries, { Id = id, Name = def.DisplayName or def.Name or id }) end
	end
	table.sort(entries, function(a, b) return a.Name < b.Name end)
	return entries
end

function CreativeService:GetState(player)
	if not available() then return { Available = false } end
	local biome = require(script.Parent.BiomeService)
	local weather = {}
	-- The same weather ID can have different strengths in different biomes.
	-- Offer only the current biome's definitions, then validate again on action.
	for _, def in ipairs(SurvivalConfig.WEATHER_BY_BIOME[biome:GetCurrent()] or {}) do
		table.insert(weather, { Id = def.Id, Name = def.Name })
	end
	return { Available = true, Mode = player:GetAttribute("CreativeMode") and "Creative" or "Survival",
		Invincible = player:GetAttribute("CreativeInvincible") == true,
		Biomes = sortedEntries(BiomeConfig.BIOMES), Weather = weather,
		Monsters = sortedEntries(EntityConfig.Entities, function(def) return def.Type == "Monster" end),
		Time = require(script.Parent.DayNightService):GetTime(), ShiftSeconds = biome:GetTiming().Remaining,
		Biome = biome:GetCurrent(), CurrentWeather = (biome:GetWeather() or {}).Id }
end

function CreativeService:_applyProtection(player)
	local char = player.Character
	if not char then return end
	local force = char:FindFirstChild("CreativeProtection")
	local protected = available() and player:GetAttribute("CreativeMode") == true and player:GetAttribute("CreativeInvincible") == true
	if protected and not force then
		force = Instance.new("ForceField")
		force.Name, force.Visible, force.Parent = "CreativeProtection", false, char
	elseif not protected and force then force:Destroy() end
end

function CreativeService:RestoreVitals(player)
	if not alive(player) then return false, "Switch to Creative mode to respawn first." end
	local stats = require(script.Parent.StatsService)
	stats:SetBaseStats(player, { Health = stats:GetStat(player, "MaxHealth") or 100,
		Hunger = stats:GetStat(player, "MaxHunger") or 100,
		Stamina = stats:GetStat(player, "MaxStamina") or 100, Temperature = 0 })
	player.Character:SetAttribute("WetStacks", 0)
	return true, "Vitals restored."
end

function CreativeService:CapturePlayer(player)
	if not available() then return nil end
	return { Mode = player:GetAttribute("CreativeMode") == true, Invincible = player:GetAttribute("CreativeInvincible") == true }
end

function CreativeService:RestorePlayer(player, state)
	local creative = available() and (type(state) ~= "table" or state.Mode ~= false)
	player:SetAttribute("CreativeMode", creative)
	player:SetAttribute("CreativeInvincible", creative and (type(state) ~= "table" or state.Invincible ~= false))
	self:_applyProtection(player)
end

function CreativeService:_setMode(player, mode)
	if mode ~= "Creative" and mode ~= "Survival" then return false, "Choose Creative or Survival." end
	local creative = mode == "Creative"
	player:SetAttribute("CreativeMode", creative)
	player:SetAttribute("CreativeInvincible", creative)
	self:_applyProtection(player)
	if creative then
		if player:GetAttribute("IsDead") then
			local ok = require(script.Parent.DeathService):CreativeRespawn(player)
			if not ok then return false, "Could not respawn yet. Try Creative mode again." end
		end
		self:RestoreVitals(player)
	end
	return true, mode .. " mode. This world still earns no progression rewards."
end

function CreativeService:_act(player, action, payload)
	if action == "State" then return true, "Creative world controls." end
	if action == "SetMode" then return self:_setMode(player, payload.Mode) end
	if not alive(player) then return false, "Switch to Creative mode to respawn first." end
	if action == "GiveItem" then
		if type(payload.Id) ~= "string" or not ItemDatabase:Get(payload.Id) or not number(payload.Quantity, 1, 999, true) then
			return false, "Choose an item and a quantity from 1 to 999."
		end
		local inventory = require(script.Parent.InventoryService)
		if inventory:Give(player, payload.Id, payload.Quantity, true) ~= payload.Quantity then return false, "Make more space in your inventory first." end
		return true, "Added " .. payload.Quantity .. " × " .. (ItemDatabase:Get(payload.Id).Name or payload.Id) .. "."
	elseif action == "SetInvincible" then
		if not player:GetAttribute("CreativeMode") then return false, "Switch to Creative mode to enable invincibility." end
		if type(payload.Enabled) ~= "boolean" then return false, "Choose an invincibility setting." end
		player:SetAttribute("CreativeInvincible", payload.Enabled)
		self:_applyProtection(player)
		if payload.Enabled then self:RestoreVitals(player) end
		return true, payload.Enabled and "Invincibility enabled." or "Invincibility disabled."
	elseif action == "RestoreVitals" then return self:RestoreVitals(player)
	elseif action == "SetTime" then
		if not number(payload.Hour, 0, 24) then return false, "Choose an hour from 0 to 24." end
		require(script.Parent.DayNightService):SetTime(payload.Hour)
		return true, "Time of day changed."
	elseif action == "SetShiftTimer" then
		if not number(payload.Seconds, 5, 3600, true) then return false, "Choose 5 to 3600 seconds." end
		return require(script.Parent.BiomeService):SetCreativeShiftTimer(payload.Seconds)
	elseif action == "SetWeather" then
		if type(payload.Id) ~= "string" then return false, "Choose weather for the current biome." end
		return require(script.Parent.BiomeService):SetCreativeWeather(payload.Id)
	elseif action == "SetBiome" then
		if type(payload.Id) ~= "string" or not BiomeConfig.BIOMES[payload.Id] then return false, "Choose an implemented biome." end
		if require(script.Parent.WorldGenController)._busy then return false, "The world is still changing. Please wait." end
		if os.clock() - (self._worldRequests.Biome or -math.huge) < 10 then return false, "Wait a few seconds between biome changes." end
		self._worldRequests.Biome = os.clock()
		if not require(script.Parent.BiomeService):SetCurrent(payload.Id, "Creative") then return false, "The biome cannot change right now." end
		require(script.Parent.GameStateService):Broadcast()
		return true, "World changed to " .. BiomeConfig.BIOMES[payload.Id].DisplayName .. "."
	elseif action == "SpawnMonster" then
		local def = type(payload.Id) == "string" and EntityConfig.Entities[payload.Id]
		if not def or def.Type ~= "Monster" or not number(payload.Count, 1, 10, true) or not number(payload.Level, 1, 25, true) then
			return false, "Choose a monster, 1–10 spawns, and level 1–25."
		end
		local root = alive(player)
		local spawner, spawned = require(script.Parent.EnemySpawner), 0
		for i = 1, payload.Count do
			local angle = (i - 1) * math.pi * 2 / payload.Count
			local position = root.Position + root.CFrame.LookVector * 24 + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
			if spawner:SpawnCreative(payload.Id, position, payload.Level) then spawned += 1 end
		end
		return spawned > 0, spawned > 0 and ("Spawned " .. spawned .. " monsters.") or "No monsters spawned: the active limit is reached or the model is unavailable."
	elseif action == "ClearMonsters" then
		local count = 0
		for _, monster in ipairs(CollectionService:GetTagged("Monster")) do
			if monster:IsDescendantOf(workspace) then monster:Destroy(); count += 1 end
		end
		return true, "Cleared " .. count .. " monsters. Natural spawns remain enabled."
	elseif action == "TeleportSpawn" then
		local char = player.Character
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local surfaces = {workspace.Terrain}
		local generated = workspace:FindFirstChild("GeneratedWorld")
		if generated then table.insert(surfaces, generated) end
		params.FilterDescendantsInstances = surfaces
		local ground = workspace:Raycast(Vector3.new(0, 1024, 0), Vector3.new(0, -2048, 0), params)
		if not ground then return false, "Spawn ground is still loading." end
		char:PivotTo(CFrame.new(ground.Position + Vector3.new(0, 5, 0)))
		local root = char:FindFirstChild("HumanoidRootPart")
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		return true, "Returned to spawn."
	end
	return false, "Unknown creative control."
end

function CreativeService:Init()
	if self._initialized then return end
	self._initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("CreativeAction") or Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "CreativeAction", remotes
	remote.OnServerInvoke = function(player, action, payload)
		if not available() then return { Success = false, Message = "Creative controls are only available in creative worlds." } end
		if type(action) ~= "string" or not ACTIONS[action] or (payload ~= nil and type(payload) ~= "table") then return { Success = false, Message = "Invalid creative request." } end
		if ReplicatedStorage:GetAttribute("ServerBootState") ~= "Ready" or ReplicatedStorage:GetAttribute("WorldRestoring")
			or player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") then
			return { Success = false, Message = "The world is still loading." }
		end
		local now, delay = os.clock(), action == "SpawnMonster" and 2 or 0.15
		local requests = self._requests[player] or {}
		self._requests[player] = requests
		if self._busy[player] or now - (requests[action] or -math.huge) < delay or now - (requests.Any or -math.huge) < 0.1 then
			return { Success = false, Message = "Please wait a moment." }
		end
		requests[action], requests.Any, self._busy[player] = now, now, true
		local ok, success, message = xpcall(function() return self:_act(player, action, payload or {}) end, debug.traceback)
		self._busy[player] = nil
		if not ok then warn("[CreativeService] " .. tostring(success)); return { Success = false, Message = "That action could not finish. Please try again." } end
		return { Success = success == true, Message = message, State = self:GetState(player) }
	end
	local function bind(player)
		-- Snapshot restoration replaces defaults once the saved character is ready.
		if player:GetAttribute("CreativeMode") == nil then self:RestorePlayer(player, nil) end
		player.CharacterAdded:Connect(function() self:_applyProtection(player) end)
		player:GetAttributeChangedSignal("CreativeMode"):Connect(function() self:_applyProtection(player) end)
		player:GetAttributeChangedSignal("CreativeInvincible"):Connect(function() self:_applyProtection(player) end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	Players.PlayerRemoving:Connect(function(player) self._requests[player], self._busy[player] = nil, nil end)
end

return CreativeService
