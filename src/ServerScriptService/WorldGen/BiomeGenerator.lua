local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SpatialHash = require(script.Parent.SpatialHash)

local BiomeGenerator = {}
BiomeGenerator.__index = BiomeGenerator

local function clamp_non_negative(value)
	if value < 0 then
		return 0
	end
	return value
end

local function random_in_range(rng, range, fallback)
	if type(range) == "number" then
		return range
	end
	if type(range) == "table" and range.min and range.max then
		return rng:NextInteger(range.min, range.max)
	end
	return fallback or 0
end

local function get_offset_value(instance)
	local offset = instance:FindFirstChild("Offset", true)
	if offset and offset:IsA("NumberValue") then
		return offset.Value
	end
	return 0
end

local function get_prefab_size(prefab)
	if prefab:IsA("Model") then
		local _, size = prefab:GetBoundingBox()
		return size
	end
	if prefab:IsA("BasePart") then
		return prefab.Size
	end
	return Vector3.new(8, 8, 8)
end

local function rect_from_size(cx, cz, size_x, size_z, padding)
	local half_x = (size_x * 0.5) + (padding or 0)
	local half_z = (size_z * 0.5) + (padding or 0)
	return {
		min_x = cx - half_x,
		max_x = cx + half_x,
		min_z = cz - half_z,
		max_z = cz + half_z,
	}
end

local function normalize_biomes(biomes)
	local list = {}
	if type(biomes) ~= "table" then
		return list
	end
	if #biomes > 0 then
		for index, biome in ipairs(biomes) do
			biome.name = biome.name or ("Biome" .. tostring(index))
			list[#list + 1] = biome
		end
	else
		for name, biome in pairs(biomes) do
			biome.name = biome.name or name
			list[#list + 1] = biome
		end
		table.sort(list, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
	end
	return list
end

local function config_value(config, snake_key, camel_key, default_value)
	local value = config[snake_key]
	if value == nil and camel_key then
		value = config[camel_key]
	end
	if value == nil then
		value = default_value
	end
	return value
end

function BiomeGenerator.new(config)
	local self = setmetatable({}, BiomeGenerator)
	self.config = config or {}
	self.seed = self.config.seed or math.floor(os.clock() * 100000)
	self.random = Random.new(self.seed)
	self.start_time = os.clock()

	self.world_radius = config_value(self.config, "world_radius", "worldRadius", 2000)
	self.center_exclusion_radius = config_value(self.config, "center_exclusion_radius", "centerExclusionRadius", 0)
	self.center_exclusion_radius_sq = self.center_exclusion_radius * self.center_exclusion_radius
	self.base_y = config_value(self.config, "base_y", "baseY", 0)
	self.chunk_size = config_value(self.config, "chunk_size", "chunkSize", 240)
	self.biome_noise_scale = config_value(self.config, "biome_noise_scale", "biomeNoiseScale", 0.0016)
	self.time_scale_seconds = config_value(self.config, "time_scale_seconds", "timeScaleSeconds", 900)
	if self.time_scale_seconds <= 0 then
		self.time_scale_seconds = 1
	end
	self.ops_per_yield = config_value(self.config, "ops_per_yield", "opsPerYield", 40)
	self.step_delay = config_value(self.config, "step_delay", "stepDelay", 0)
	self.region_padding = config_value(self.config, "region_padding", "regionPadding", 8)
	self.structure_padding = config_value(self.config, "structure_padding", "structurePadding", 6)
	self.objective_padding = config_value(self.config, "objective_padding", "objectivePadding", 6)
	self.avoid_regions_for_structures = config_value(self.config, "avoid_regions_for_structures", "avoidRegionsForStructures", true)
	self.spawn_folder_name = config_value(self.config, "spawn_folder_name", "spawnFolderName", "GeneratedWorld")

	self.biomes = normalize_biomes(self.config.biomes or {})
	self.weight_cache = {}

	self.region_hash = SpatialHash.new(self.chunk_size)
	self.structure_hash = SpatialHash.new(math.max(64, self.chunk_size * 0.5))
	self.next_rect_id = 1

	self.prefab_roots = {
		ResourcePrefabs = ServerStorage:FindFirstChild("ResourcePrefabs"),
		StructurePrefabs = ServerStorage:FindFirstChild("StructurePrefabs"),
		PropPrefabs = ServerStorage:FindFirstChild("PropPrefabs"),
		ObjectivePrefabs = ServerStorage:FindFirstChild("ObjectivePrefabs"),
		EnemyPrefabs = ServerStorage:FindFirstChild("EnemyPrefabs"),
	}
	self.prefab_lookup = {}

	self.stats = {
		chunks = 0,
		regions = 0,
		resources = 0,
		props = 0,
		structures = 0,
		objectives = 0,
		enemies = 0,
	}

	return self
end

function BiomeGenerator:_reset_stats()
	self.stats = {
		chunks = 0,
		regions = 0,
		resources = 0,
		props = 0,
		structures = 0,
		objectives = 0,
		enemies = 0,
	}
end

function BiomeGenerator:_find_biome(name)
	if not name then return nil end
	for _, biome in ipairs(self.biomes) do
		if biome.name == name then
			return biome
		end
	end
	return nil
end

function BiomeGenerator:_step()
	self.ops = (self.ops or 0) + 1
	if self.ops < self.ops_per_yield then
		return
	end
	self.ops = 0
	if self.step_delay > 0 then
		task.wait(self.step_delay)
	else
		task.wait()
	end
end

function BiomeGenerator:_get_biome_weight(biome)
	local elapsed = os.clock() - self.start_time
	local base_weight = biome.weight or 0
	local scaled = biome.time_scaled_weight
	if scaled == nil then
		scaled = biome.timeScaledWeight or 0
	end
	return clamp_non_negative(base_weight + (scaled * (elapsed / self.time_scale_seconds)))
end

function BiomeGenerator:_select_biome(x, z)
	local total = 0
	for i, biome in ipairs(self.biomes) do
		local weight = self:_get_biome_weight(biome)
		self.weight_cache[i] = weight
		total += weight
	end
	if total <= 0 then
		return self.biomes[1]
	end
	local noise_value = (math.noise(x * self.biome_noise_scale, z * self.biome_noise_scale, self.seed * 0.001) + 1) * 0.5
	local target = noise_value * total
	local cumulative = 0
	for i, biome in ipairs(self.biomes) do
		cumulative += self.weight_cache[i]
		if target <= cumulative then
			return biome
		end
	end
	return self.biomes[#self.biomes]
end

function BiomeGenerator:_ensure_spawn_folders()
	local folder = Workspace:FindFirstChild(self.spawn_folder_name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = self.spawn_folder_name
		folder.Parent = Workspace
	end
	self.spawn_folder = folder
	self.spawn_subfolders = {
		Resources = folder:FindFirstChild("Resources") or Instance.new("Folder"),
		Props = folder:FindFirstChild("Props") or Instance.new("Folder"),
		Structures = folder:FindFirstChild("Structures") or Instance.new("Folder"),
		Objectives = folder:FindFirstChild("Objectives") or Instance.new("Folder"),
		Enemies = folder:FindFirstChild("Enemies") or Instance.new("Folder"),
	}
	for name, subfolder in pairs(self.spawn_subfolders) do
		subfolder.Name = name
		subfolder.Parent = folder
	end
end

function BiomeGenerator:_get_prefab_lookup(type_name, biome_name)
	local biome_cache = self.prefab_lookup[biome_name]
	if not biome_cache then
		biome_cache = {}
		self.prefab_lookup[biome_name] = biome_cache
	end
	local type_cache = biome_cache[type_name]
	if type_cache then
		return type_cache
	end
	local root = self.prefab_roots[type_name]
	local folder = root and root:FindFirstChild(biome_name)
	local lookup = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			lookup[child.Name] = child
		end
	end
	biome_cache[type_name] = lookup
	return lookup
end

function BiomeGenerator:_resolve_prefabs(type_name, biome_name, names)
	local lookup = self:_get_prefab_lookup(type_name, biome_name)
	local list = {}
	if names == true or names == "*" then
		for _, prefab in pairs(lookup) do
			list[#list + 1] = prefab
		end
	elseif type(names) == "table" and #names > 0 then
		for _, prefab_name in ipairs(names) do
			local prefab = lookup[prefab_name]
			if prefab then
				list[#list + 1] = prefab
			end
		end
	end
	return list
end

function BiomeGenerator:_place_prefab(prefab, position, parent)
	if not prefab then
		return
	end
	local clone = prefab:Clone()
	if parent and parent.Name == "Resources" then
		if clone:IsA("BasePart") then
			clone.CanQuery = true
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanQuery = true
			end
		end
	end
	local y_offset = get_offset_value(clone)
	local target_cf = CFrame.new(position.X, self.base_y + y_offset, position.Z)
	if clone:IsA("Model") then
		clone:PivotTo(target_cf)
	elseif clone:IsA("BasePart") then
		clone.CFrame = target_cf
	end
	clone.Parent = parent
end

function BiomeGenerator:_random_point_in_bounds(min_x, max_x, min_z, max_z)
	if self.center_exclusion_radius <= 0 then
		local x = self.random:NextNumber(min_x, max_x)
		local z = self.random:NextNumber(min_z, max_z)
		return Vector3.new(x, self.base_y, z)
	end

	for _ = 1, 8 do
		local x = self.random:NextNumber(min_x, max_x)
		local z = self.random:NextNumber(min_z, max_z)
		if (x * x + z * z) >= self.center_exclusion_radius_sq then
			return Vector3.new(x, self.base_y, z)
		end
	end

	local angle = self.random:NextNumber(0, math.pi * 2)
	local radius = self.center_exclusion_radius + 1
	local x = math.clamp(radius * math.cos(angle), min_x, max_x)
	local z = math.clamp(radius * math.sin(angle), min_z, max_z)
	return Vector3.new(x, self.base_y, z)
end

function BiomeGenerator:_random_point_in_chunk(chunk_center)
	local half = self.chunk_size * 0.5
	local min_x = chunk_center.X - half
	local max_x = chunk_center.X + half
	local min_z = chunk_center.Z - half
	local max_z = chunk_center.Z + half
	return self:_random_point_in_bounds(min_x, max_x, min_z, max_z)
end

function BiomeGenerator:_random_point_in_region(region_center, region_size)
	local half_x = region_size.X * 0.5
	local half_z = region_size.Y * 0.5
	local min_x = region_center.X - half_x
	local max_x = region_center.X + half_x
	local min_z = region_center.Z - half_z
	local max_z = region_center.Z + half_z
	return self:_random_point_in_bounds(min_x, max_x, min_z, max_z)
end

function BiomeGenerator:_try_place_region(chunk_center, region_def)
	local size = region_def.size
	if not size then
		return nil
	end

	local half_chunk = self.chunk_size * 0.5
	local half_x = size.X * 0.5
	local half_z = size.Y * 0.5
	local min_x = chunk_center.X - half_chunk + half_x
	local max_x = chunk_center.X + half_chunk - half_x
	local min_z = chunk_center.Z - half_chunk + half_z
	local max_z = chunk_center.Z + half_chunk - half_z
	if min_x > max_x or min_z > max_z then
		return nil
	end

	local tries = region_def.placement_tries or region_def.placementTries or 6
	for _ = 1, tries do
		local x = self.random:NextNumber(min_x, max_x)
		local z = self.random:NextNumber(min_z, max_z)
		local rect = rect_from_size(x, z, size.X, size.Y, self.region_padding)
		if not self.region_hash:intersects(rect) and not self.structure_hash:intersects(rect) then
			local id = self.next_rect_id
			self.next_rect_id += 1
			self.region_hash:insert(id, rect)
			self.stats.regions += 1
			return Vector3.new(x, self.base_y, z)
		end
	end
	return nil
end

function BiomeGenerator:_scatter_in_region(biome_name, region_center, region_def)
	local resource_prefabs = self:_resolve_prefabs("ResourcePrefabs", biome_name, region_def.resources)
	local prop_prefabs = self:_resolve_prefabs("PropPrefabs", biome_name, region_def.props)
	local enemy_prefabs = self:_resolve_prefabs("EnemyPrefabs", biome_name, region_def.enemies)

	local resource_count = random_in_range(self.random, region_def.resource_count or region_def.resourceCount)
	local prop_count = random_in_range(self.random, region_def.prop_count or region_def.propCount)
	local enemy_count = random_in_range(self.random, region_def.enemy_count or region_def.enemyCount)

	for _ = 1, resource_count do
		local prefab = resource_prefabs[self.random:NextInteger(1, math.max(1, #resource_prefabs))]
		if prefab then
			local position = self:_random_point_in_region(region_center, region_def.size)
			self:_place_prefab(prefab, position, self.spawn_subfolders.Resources)
			self.stats.resources += 1
		end
		self:_step()
	end

	for _ = 1, prop_count do
		local prefab = prop_prefabs[self.random:NextInteger(1, math.max(1, #prop_prefabs))]
		if prefab then
			local position = self:_random_point_in_region(region_center, region_def.size)
			self:_place_prefab(prefab, position, self.spawn_subfolders.Props)
			self.stats.props += 1
		end
		self:_step()
	end

	for _ = 1, enemy_count do
		local prefab = enemy_prefabs[self.random:NextInteger(1, math.max(1, #enemy_prefabs))]
		if prefab then
			local position = self:_random_point_in_region(region_center, region_def.size)
			self:_place_prefab(prefab, position, self.spawn_subfolders.Enemies)
			self.stats.enemies += 1
		end
		self:_step()
	end
end

function BiomeGenerator:_place_large_objects(biome_name, list, count, padding, parent)
	if count <= 0 then
		return
	end
	local prefabs = self:_resolve_prefabs(list.type_name, biome_name, list.names)
	if #prefabs == 0 then
		return
	end
	local tries = list.placement_tries or 10

	for _ = 1, count do
		local placed = false
		for _ = 1, tries do
			local position = self:_random_point_in_chunk(list.chunk_center)
			local prefab = prefabs[self.random:NextInteger(1, #prefabs)]
			local size = get_prefab_size(prefab)
			local rect = rect_from_size(position.X, position.Z, size.X, size.Z, padding)
			local intersects_region = self.avoid_regions_for_structures and self.region_hash:intersects(rect)
			if not intersects_region and not self.structure_hash:intersects(rect) then
				local id = self.next_rect_id
				self.next_rect_id += 1
				self.structure_hash:insert(id, rect)
				self:_place_prefab(prefab, position, parent)
				placed = true
				break
			end
		end
		if placed and parent == self.spawn_subfolders.Structures then
			self.stats.structures += 1
		elseif placed and parent == self.spawn_subfolders.Objectives then
			self.stats.objectives += 1
		end
		self:_step()
	end
end

function BiomeGenerator:_generate(override_biome)
	if #self.biomes == 0 then
		return self.stats
	end

	self:_reset_stats()
	self:_ensure_spawn_folders()

	local radius = self.world_radius
	local inner = self.center_exclusion_radius
	local chunk_step = self.chunk_size

	local centers = {}
	for x = -radius, radius, chunk_step do
		for z = -radius, radius, chunk_step do
			local cx = x + chunk_step * 0.5
			local cz = z + chunk_step * 0.5
			local dist = math.sqrt(cx * cx + cz * cz)
			if dist >= inner and dist <= radius then
				centers[#centers + 1] = Vector2.new(cx, cz)
			end
		end
	end

	table.sort(centers, function(a, b)
		return (a.X * a.X + a.Y * a.Y) < (b.X * b.X + b.Y * b.Y)
	end)

	local forced_biome = override_biome and self:_find_biome(override_biome) or nil

	for _, center in ipairs(centers) do
		local chunk_center = Vector3.new(center.X, self.base_y, center.Y)
		local biome = forced_biome or self:_select_biome(center.X, center.Y)
		local biome_name = biome.name

		self.stats.chunks += 1

		local region_count = random_in_range(self.random, biome.region_count or biome.regionCount, 1)
		for _ = 1, region_count do
			local region_def = nil
			if biome.regions and #biome.regions > 0 then
				region_def = biome.regions[self.random:NextInteger(1, #biome.regions)]
			end
			if region_def then
				local region_center = self:_try_place_region(chunk_center, region_def)
				if region_center then
					self:_scatter_in_region(biome_name, region_center, region_def)
				end
			end
			self:_step()
		end

		local structure_count = random_in_range(self.random, biome.structure_count or biome.structureCount)
		self:_place_large_objects(
			biome_name,
			{
				type_name = "StructurePrefabs",
				names = biome.structures,
				chunk_center = chunk_center,
				placement_tries = biome.structure_placement_tries or biome.structurePlacementTries,
			},
			structure_count,
			self.structure_padding,
			self.spawn_subfolders.Structures
		)

		local objective_count = random_in_range(self.random, biome.objective_count or biome.objectiveCount)
		self:_place_large_objects(
			biome_name,
			{
				type_name = "ObjectivePrefabs",
				names = biome.objectives,
				chunk_center = chunk_center,
				placement_tries = biome.objective_placement_tries or biome.objectivePlacementTries,
			},
			objective_count,
			self.objective_padding,
			self.spawn_subfolders.Objectives
		)

		self:_step()
	end

	return self.stats
end

function BiomeGenerator:GenerateAsync()
	return self:_generate(nil)
end

function BiomeGenerator:GenerateBiome(biome_name)
	return self:_generate(biome_name)
end

return BiomeGenerator
