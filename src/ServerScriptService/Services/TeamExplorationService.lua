-- Server-authoritative team exploration; only discovered cells are replicated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Biomes = require(ReplicatedStorage.Shared.BiomeConfig)
local MapConfig = require(ReplicatedStorage.Shared.MapConfig)
local CHUNK_SIZE = Biomes.chunk_size or 240
local WORLD_RADIUS = Biomes.world_radius or (Biomes.WORLD and Biomes.WORLD.WorldRadius) or 1500
local REVEAL_RADIUS = math.max(0, math.floor((MapConfig.Exploration or {}).RevealChunkRadius or 1))
local GRID_LIMIT = math.ceil(WORLD_RADIUS / CHUNK_SIZE) + 1
local MAX_REGIONS, MAX_REGION_JSON = 64, 32768
local Service = { _cells = {}, _metadata = {}, _lastCells = {} }

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function cellValid(x, z)
	if not finite(x) or not finite(z) or x % 1 ~= 0 or z % 1 ~= 0 then return false end
	local wx, wz = (x + .5) * CHUNK_SIZE, (z + .5) * CHUNK_SIZE
	return wx * wx + wz * wz <= WORLD_RADIUS * WORLD_RADIUS
end
local MAX_CELLS = 0
for x = -GRID_LIMIT, GRID_LIMIT do
	for z = -GRID_LIMIT, GRID_LIMIT do if cellValid(x, z) then MAX_CELLS += 1 end end
end
local function key(x, z) return tostring(x) .. "," .. tostring(z) end
local function denseCount(list, limit)
	assert(type(list) == "table", "Exploration array required")
	local count = 0
	for index in pairs(list) do
		assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #list, "Sparse exploration array")
		count += 1
		assert(count <= limit, "Exploration capacity exceeded")
	end
	assert(count == #list, "Sparse exploration array")
	return count
end
local function regionsCopy(regions)
	denseCount(regions, MAX_REGIONS)
	local result = {}
	for _, region in ipairs(regions) do
		assert(type(region) == "table" and type(region.name) == "string" and #region.name <= 64, "Invalid exploration region")
		local copy = { name = region.name }
		for _, field in ipairs({"x", "z", "sx", "sz"}) do
			local n = region[field]
			assert(finite(n), "Invalid exploration region coordinate")
			if field == "sx" or field == "sz" then
				assert(n >= 0 and n <= WORLD_RADIUS * 2, "Invalid exploration region size")
			else assert(math.abs(n) <= WORLD_RADIUS + CHUNK_SIZE, "Invalid exploration region position") end
			copy[field] = n
		end
		if region.temp ~= nil then
			assert(finite(region.temp) and math.abs(region.temp) <= 1000, "Invalid exploration temperature")
			copy.temp = region.temp
		end
		table.insert(result, copy)
	end
	assert(#HttpService:JSONEncode(result) <= MAX_REGION_JSON, "Exploration region data too large")
	return result
end
local function biomeValid(name) return type(name) == "string" and Biomes.BIOMES[name] ~= nil end

function Service:_publish(cell)
	if not self._folder then return end
	local name = key(cell.X, cell.Z)
	local folder = self._folder:FindFirstChild(name)
	if not folder then folder = Instance.new("Folder"); folder.Name = name end
	folder:SetAttribute("MapChunkX", cell.X)
	folder:SetAttribute("MapChunkZ", cell.Z)
	folder:SetAttribute("MapBiome", cell.Biome or self._biome or "Unknown")
	folder:SetAttribute("MapRegionsJson", HttpService:JSONEncode(cell.Regions or {}))
	folder.Parent = self._folder
end

function Service:Init()
	if self._folder then return end
	local folder = ReplicatedStorage:FindFirstChild("TeamExploration")
	if folder then
		assert(folder:IsA("Folder"), "TeamExploration must be a Folder")
		folder:ClearAllChildren()
	else folder = Instance.new("Folder"); folder.Name = "TeamExploration" end
	self._folder = folder
	folder:SetAttribute("Version", 1)
	folder:SetAttribute("ChunkSize", CHUNK_SIZE)
	folder:SetAttribute("Biome", self._biome)
	folder:SetAttribute("Epoch", self._epoch)
	for _, cell in pairs(self._cells) do self:_publish(cell) end
	folder.Parent = ReplicatedStorage
	self._removing = Players.PlayerRemoving:Connect(function(player) self._lastCells[player] = nil end)
end

function Service:BeginBiome(biome, epoch)
	assert(biomeValid(biome) and finite(epoch) and epoch >= 0 and epoch % 1 == 0, "Invalid exploration generation")
	self:Init()
	if self._biome == biome and self._epoch == epoch then return end
	self._biome, self._epoch = biome, epoch
	self._metadata = {}
	for _, cell in pairs(self._cells) do
		cell.Biome, cell.Regions = biome, {}
		self:_publish(cell)
	end
	self._folder:SetAttribute("Biome", biome)
	self._folder:SetAttribute("Epoch", epoch)
end

function Service:RecordChunk(folder, epoch)
	if epoch ~= self._epoch or not folder or not folder.Parent then return false end
	local x, z = folder:GetAttribute("MapChunkX"), folder:GetAttribute("MapChunkZ")
	local biome, json = folder:GetAttribute("MapBiome"), folder:GetAttribute("MapRegionsJson")
	if not cellValid(x, z) or biome ~= self._biome or type(json) ~= "string" or #json > MAX_REGION_JSON then return false end
	local ok, regions = pcall(function() return regionsCopy(HttpService:JSONDecode(json)) end)
	if not ok then warn("[TeamExploration] Invalid generated region metadata:", regions); return false end
	local id = key(x, z)
	local metadata = { X = x, Z = z, Biome = biome, Regions = regions }
	self._metadata[id] = metadata
	if self._cells[id] then self._cells[id] = metadata; self:_publish(metadata) end
	return true
end

function Service:RevealFromPlayer(player, position)
	if player.Parent ~= Players or player:GetAttribute("IsDead") or player:GetAttribute("WorldPlayerLoading")
		or player:GetAttribute("WorldPlayerRestoring") or ReplicatedStorage:GetAttribute("WorldRestoring") then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not root:IsDescendantOf(workspace) or not humanoid or humanoid.Health <= 0 then return false end
	if typeof(position) ~= "Vector3" or not finite(position.X) or not finite(position.Y) or not finite(position.Z) then return false end
	-- The caller uses the server's root pose; refuse fabricated positions even
	-- from a mistaken future server integration.
	if (position - root.Position).Magnitude > 1 then return false end
	local x, z = math.floor(position.X / CHUNK_SIZE), math.floor(position.Z / CHUNK_SIZE)
	if not cellValid(x, z) or not self._biome then return false end
	local center = key(x, z)
	if self._lastCells[player] == center then return false end
	self._lastCells[player] = center
	local changed = false
	for dx = -REVEAL_RADIUS, REVEAL_RADIUS do
		for dz = -REVEAL_RADIUS, REVEAL_RADIUS do
			local cx, cz = x + dx, z + dz
			if cellValid(cx, cz) then
				local id = key(cx, cz)
				if not self._cells[id] then
					local cell = self._metadata[id] or { X = cx, Z = cz, Biome = self._biome, Regions = {} }
					self._cells[id] = cell
					self:_publish(cell)
					changed = true
				end
			end
		end
	end
	return changed
end

function Service:CaptureWorldState()
	local cells = {}
	for _, cell in pairs(self._cells) do
		table.insert(cells, { X = cell.X, Z = cell.Z, Biome = cell.Biome, Regions = regionsCopy(cell.Regions or {}) })
	end
	assert(#cells <= MAX_CELLS, "Exploration cell capacity exceeded")
	table.sort(cells, function(a, b) return a.X == b.X and a.Z < b.Z or a.X < b.X end)
	return { Version = 1, Biome = self._biome, Epoch = self._epoch, Cells = cells }
end

function Service:RestoreWorldState(state)
	local restored, biome, epoch = {}, nil, nil
	if state ~= nil then
		assert(type(state) == "table" and state.Version == 1 and biomeValid(state.Biome), "Invalid exploration snapshot")
		assert(finite(state.Epoch) and state.Epoch >= 0 and state.Epoch <= 1e8 and state.Epoch % 1 == 0, "Invalid exploration epoch")
		denseCount(state.Cells, MAX_CELLS)
		biome, epoch = state.Biome, state.Epoch
		for _, cell in ipairs(state.Cells) do
			assert(type(cell) == "table" and cellValid(cell.X, cell.Z) and cell.Biome == biome, "Invalid explored cell")
			local id = key(cell.X, cell.Z)
			assert(not restored[id], "Duplicate explored cell")
			restored[id] = { X = cell.X, Z = cell.Z, Biome = cell.Biome, Regions = regionsCopy(cell.Regions or {}) }
		end
	end
	self._cells, self._metadata, self._lastCells = restored, {}, {}
	self._biome, self._epoch = biome, epoch
	if self._folder then
		self._folder:ClearAllChildren()
		self._folder:SetAttribute("Biome", biome)
		self._folder:SetAttribute("Epoch", epoch)
		for _, cell in pairs(restored) do self:_publish(cell) end
	end
	return true
end

return Service
