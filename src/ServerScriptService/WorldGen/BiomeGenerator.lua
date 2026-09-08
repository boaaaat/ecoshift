local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local SpatialHash = require(script.Parent.SpatialHash)
local CenterClearance = require(script.Parent.CenterClearance)
local EntityConfig = require(script.Parent.Parent.AI.EntityConfig)

local BiomeGenerator = {}
BiomeGenerator.__index = BiomeGenerator

local function clamp_non_negative(value)
	if value < 0 then
		return 0
	end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
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

local function resolve_probability(rng, value)
	local chance = 0
	if type(value) == "table" and value.min and value.max then
		chance = rng:NextNumber(value.min, value.max)
	elseif type(value) == "number" then
		chance = value
	end
	chance = tonumber(chance) or 0
	if chance < 0 then chance = 0 end
	if chance > 1 then chance = 1 end
	return chance
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
	self.sampling_exclusion_radius = config_value(self.config, "generation_sampling_exclusion_radius", "generationSamplingExclusionRadius", self.center_exclusion_radius)
	self.sampling_exclusion_radius_sq = self.sampling_exclusion_radius * self.sampling_exclusion_radius
	self.base_y = config_value(self.config, "base_y", "baseY", 0)
	self.chunk_size = config_value(self.config, "chunk_size", "chunkSize", 240)
	self.max_chunks = config_value(self.config, "max_chunks", "maxChunks", nil)
	if self.max_chunks ~= nil then
		self.max_chunks = math.floor(tonumber(self.max_chunks) or 0)
		if self.max_chunks <= 0 then
			self.max_chunks = nil
		end
	end
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
	self.spawn_enemies = config_value(self.config, "spawn_enemies", "spawnEnemies", true) ~= false
	self.use_entity_config_enemies = config_value(self.config, "use_entity_config_enemies", "useEntityConfigEnemies", false)

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

function BiomeGenerator:_distance_t(x, z)
	local inner = self.sampling_exclusion_radius or 0
	local outer = self.world_radius or 1
	if outer <= inner then
		return 0
	end
	local dist = math.sqrt((x * x) + (z * z))
	return math.clamp((dist - inner) / math.max(outer - inner, 1), 0, 1)
end

function BiomeGenerator:_distance_weight_factor(weight, t)
	if t == nil then
		return 1
	end
	if type(weight) == "table" then
		local min = tonumber(weight.Min or weight.min) or 1
		local max = tonumber(weight.Max or weight.max) or 1
		return math.max(0, lerp(min, max, t))
	end
	if weight == nil then
		return 1
	end
	local w = tonumber(weight) or 1
	return math.max(0, lerp(1, w, t))
end

function BiomeGenerator:_entry_weight(entry, distance_t)
	local weight = tonumber(entry.Weight or entry.weight) or 1
	if distance_t ~= nil then
		local dWeight = entry.DistanceWeight or entry.distanceWeight
		weight = weight * self:_distance_weight_factor(dWeight, distance_t)
	end
	return weight
end

function BiomeGenerator:_distance_factor_for_list(list, distance_t)
	if distance_t == nil or not list or #list == 0 then
		return 1
	end
	local total = 0
	local weighted = 0
	for _, entry in ipairs(list) do
		local base = tonumber(entry.Weight or entry.weight) or 1
		if base > 0 then
			local dWeight = entry.DistanceWeight or entry.distanceWeight
			local factor = self:_distance_weight_factor(dWeight, distance_t)
			total += base
			weighted += base * factor
		end
	end
	if total <= 0 then
		return 1
	end
	return weighted / total
end

function BiomeGenerator:_entity_weight(spawn_def)
	if not spawn_def then return 0 end
	local elapsed = os.clock() - self.start_time
	local base = tonumber(spawn_def.Weight) or 1
	local scaled = tonumber(spawn_def.TimeScaledWeight) or 0
	local weight = base + (scaled * (elapsed / self.time_scale_seconds))
	return clamp_non_negative(weight)
end

function BiomeGenerator:_resolve_entity_enemy_list(biome_name, region_def)
	local entities = EntityConfig.Entities or {}
	local type_weights = EntityConfig.TypeWeights or {}
	local lookup = self:_get_prefab_lookup("EnemyPrefabs", biome_name)
	local list = {}
	for id, def in pairs(entities) do
		local spawn = def.Spawn
		local biomes = spawn and spawn.Biomes
		local biome_def = biomes and biomes[biome_name]
		if spawn and biome_def then
			local prefab = lookup[id]
			if prefab then
				local base_weight = self:_entity_weight(spawn)
				local biome_weight = tonumber(biome_def.Weight) or 1
				local region_weight = 1
				if biome_def.Regions and region_def and region_def.name then
					region_weight = tonumber(biome_def.Regions[region_def.name]) or 1
				end
				local type_weight = tonumber(type_weights[def.Type or def.EntityType or "Monster"]) or 1
				local weight = base_weight * biome_weight * region_weight * type_weight
				if weight > 0 then
					local distance_weight = spawn.DistanceWeight or spawn.distanceWeight or (biome_def and (biome_def.DistanceWeight or biome_def.distanceWeight))
					list[#list + 1] = {
						Prefab = prefab,
						Weight = weight,
						DistanceWeight = distance_weight,
						Id = id,
						GroupSize = spawn.GroupSize,
						GroupRadius = spawn.GroupRadius,
						MaxGroupsPerRegion = spawn.MaxGroupsPerRegion,
						MaxCountPerRegion = spawn.MaxCountPerRegion,
					}
				end
			end
		end
	end
	return list
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
	-- OPTIMIZED: Use task.defer for smoother frame distribution
	task.defer(function() end)
	task.wait()
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

function BiomeGenerator:_resolve_prefabs_weighted(type_name, biome_name, names)
	local lookup = self:_get_prefab_lookup(type_name, biome_name)
	local list = {}
	if names == true or names == "*" then
		for _, prefab in pairs(lookup) do
			list[#list + 1] = { Prefab = prefab, Weight = 1 }
		end
		return list
	end

	if type(names) == "table" then
		if #names > 0 then
			for _, entry in ipairs(names) do
				if type(entry) == "string" then
					local prefab = lookup[entry]
					if prefab then
						list[#list + 1] = { Prefab = prefab, Weight = 1 }
					end
				elseif type(entry) == "table" then
					local name = entry.Name or entry.Id or entry.Prefab or entry[1]
					local weight = tonumber(entry.Weight or entry.weight) or 1
					local distance_weight = entry.DistanceWeight or entry.distanceWeight
					if type(name) == "string" then
						local prefab = lookup[name]
						if prefab and weight > 0 then
							list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
						end
					end
				end
			end
		else
			for key, value in pairs(names) do
				if type(key) == "string" then
					local prefab = lookup[key]
					local weight = 1
					local distance_weight = nil
					if type(value) == "number" then
						weight = value
					elseif type(value) == "table" then
						weight = tonumber(value.Weight or value.weight) or 1
						distance_weight = value.DistanceWeight or value.distanceWeight
					end
					if prefab and weight > 0 then
						list[#list + 1] = { Prefab = prefab, Weight = weight, DistanceWeight = distance_weight }
					end
				end
			end
		end
	end
	return list
end

function BiomeGenerator:_choose_weighted(list, distance_t)
	local total = 0
	for _, entry in ipairs(list) do
		total += self:_entry_weight(entry, distance_t)
	end
	if total <= 0 then return nil end
	local roll = self.random:NextNumber(0, total)
	for _, entry in ipairs(list) do
		roll -= self:_entry_weight(entry, distance_t)
		if roll <= 0 then
			return entry.Prefab
		end
	end
	return list[#list].Prefab
end

function BiomeGenerator:_choose_weighted_entry(list, distance_t)
	local total = 0
	for _, entry in ipairs(list) do
		total += self:_entry_weight(entry, distance_t)
	end
	if total <= 0 then return nil end
	local roll = self.random:NextNumber(0, total)
	for _, entry in ipairs(list) do
		roll -= self:_entry_weight(entry, distance_t)
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

function BiomeGenerator:_place_prefab(prefab, position, parent)
	if not prefab then
		return
	end
	-- OPTIMIZED: Use task.defer for non-blocking clone operations
	task.defer(function()
		local clone = prefab:Clone()
		if parent and parent.Name == "Enemies" then
			local entity_id = clone:GetAttribute("EntityId") or prefab:GetAttribute("EntityId") or prefab.Name
			local def = EntityConfig.Entities and EntityConfig.Entities[entity_id]
			local entity_type = clone:GetAttribute("EntityType") or prefab:GetAttribute("EntityType") or (def and def.Type) or "Monster"
			clone:SetAttribute("EntityId", entity_id)
			clone:SetAttribute("EntityType", entity_type)
			if entity_type == "Animal" then
				CollectionService:AddTag(clone, "Animal")
			else
				CollectionService:AddTag(clone, "Monster")
			end
		end
		if parent and (parent.Name == "Resources" or parent.Name == "Props" or parent.Name == "Structures" or parent.Name == "Objectives") then
			if clone:IsA("BasePart") then
				clone.CanQuery = true
			end
			-- OPTIMIZED: Batch descendant iteration
			local descendants = clone:GetDescendants()
			for i = 1, #descendants do
				local d = descendants[i]
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
		-- The random point fallback can be clamped into the clearing; checking the
		-- final footprint also rejects large props whose pivot is just outside it.
		if CenterClearance.Overlaps(clone, self.center_exclusion_radius) then
			clone:Destroy()
			return
		end
		clone.Parent = parent
	end)
end

function BiomeGenerator:_random_point_in_bounds(min_x, max_x, min_z, max_z)
	if self.sampling_exclusion_radius <= 0 then
		local x = self.random:NextNumber(min_x, max_x)
		local z = self.random:NextNumber(min_z, max_z)
		return Vector3.new(x, self.base_y, z)
	end

	for _ = 1, 8 do
		local x = self.random:NextNumber(min_x, max_x)
		local z = self.random:NextNumber(min_z, max_z)
		if (x * x + z * z) >= self.sampling_exclusion_radius_sq then
			return Vector3.new(x, self.base_y, z)
		end
	end

	local angle = self.random:NextNumber(0, math.pi * 2)
	local radius = self.sampling_exclusion_radius + 1
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
	local resource_prefabs = self:_resolve_prefabs_weighted("ResourcePrefabs", biome_name, region_def.resources)
	local prop_prefabs = self:_resolve_prefabs_weighted("PropPrefabs", biome_name, region_def.props)
	local enemy_prefabs = nil
	if self.spawn_enemies then
		if self.use_entity_config_enemies then
			enemy_prefabs = self:_resolve_entity_enemy_list(biome_name, region_def)
		end
		if not enemy_prefabs or #enemy_prefabs == 0 then
			enemy_prefabs = self:_resolve_prefabs_weighted("EnemyPrefabs", biome_name, region_def.enemies)
		end
	end

	local distance_t = self:_distance_t(region_center.X, region_center.Z)
	local resource_count = random_in_range(self.random, region_def.resource_count or region_def.resourceCount)
	local prop_count = random_in_range(self.random, region_def.prop_count or region_def.propCount)
	local enemy_count = self.spawn_enemies and random_in_range(self.random, region_def.enemy_count or region_def.enemyCount) or 0

	local resource_factor = self:_distance_factor_for_list(resource_prefabs, distance_t)
	local prop_factor = self:_distance_factor_for_list(prop_prefabs, distance_t)
	local enemy_factor = self.spawn_enemies and self:_distance_factor_for_list(enemy_prefabs, distance_t) or 1

	resource_count = math.max(0, math.floor(resource_count * resource_factor + 0.5))
	prop_count = math.max(0, math.floor(prop_count * prop_factor + 0.5))
	enemy_count = self.spawn_enemies and math.max(0, math.floor(enemy_count * enemy_factor + 0.5)) or 0

	for _ = 1, resource_count do
		local prefab = self:_choose_weighted(resource_prefabs, distance_t)
		if prefab then
			-- Try multiple positions to avoid structures
			local placed = false
			for _ = 1, 3 do
				local position = self:_random_point_in_region(region_center, region_def.size)
				if not isInsideStructure(position, prefab) then
					self:_place_prefab(prefab, position, self.spawn_subfolders.Resources)
					self.stats.resources += 1
					placed = true
					break
				end
			end
		end
		self:_step()
	end

	for _ = 1, prop_count do
		local prefab = self:_choose_weighted(prop_prefabs, distance_t)
		if prefab then
			-- Try multiple positions to avoid structures
			local placed = false
			for _ = 1, 3 do
				local position = self:_random_point_in_region(region_center, region_def.size)
				if not isInsideStructure(position, prefab) then
					self:_place_prefab(prefab, position, self.spawn_subfolders.Props)
					self.stats.props += 1
					placed = true
					break
				end
			end
		end
		self:_step()
	end

	if self.spawn_enemies and enemy_count > 0 then
		local group_counts = {}
		local member_counts = {}
		for _ = 1, enemy_count do
			local entry = self:_choose_weighted_entry(enemy_prefabs, distance_t)
			if entry then
				local id = entry.Id or (entry.Prefab and entry.Prefab.Name) or "Enemy"
				local max_groups = tonumber(entry.MaxGroupsPerRegion)
				if max_groups and (group_counts[id] or 0) >= max_groups then
					self:_step()
					goto continue_enemy
				end
				local max_members = tonumber(entry.MaxCountPerRegion)
				if max_members and (member_counts[id] or 0) >= max_members then
					self:_step()
					goto continue_enemy
				end

				-- Try to find a position outside structures for the group
			local position = nil
			for _ = 1, 3 do
				local testPos = self:_random_point_in_region(region_center, region_def.size)
				local testRect = rect_from_size(testPos.X, testPos.Z, 4, 4, 2)
				if not self.structure_hash:intersects(testRect) then
					position = testPos
					break
				end
			end
			if not position then
				self:_step()
				goto continue_enemy
			end

				local group_size = random_in_range(self.random, entry.GroupSize, 1)
				local radius = tonumber(entry.GroupRadius) or 6
				group_counts[id] = (group_counts[id] or 0) + 1
				for i = 1, group_size do
					if max_members and (member_counts[id] or 0) >= max_members then
						break
					end
					local offset = Vector3.new(
						self.random:NextNumber(-radius, radius),
						0,
						self.random:NextNumber(-radius, radius)
					)
					self:_place_prefab(entry.Prefab, position + offset, self.spawn_subfolders.Enemies)
					self.stats.enemies += 1
					member_counts[id] = (member_counts[id] or 0) + 1
				end
			end
			::continue_enemy::
			self:_step()
		end
	end
end

function BiomeGenerator:_place_large_objects(biome_name, list, count, padding, parent, prefabs, distance_t)
	if count <= 0 then
		return
	end
	local prefabs = prefabs or self:_resolve_prefabs_weighted(list.type_name, biome_name, list.names)
	if #prefabs == 0 then
		return
	end
	if distance_t == nil and list.chunk_center then
		distance_t = self:_distance_t(list.chunk_center.X, list.chunk_center.Z)
	end
	local tries = list.placement_tries or 10

	for _ = 1, count do
		local placed = false
		for _ = 1, tries do
			local position = self:_random_point_in_chunk(list.chunk_center)
			local prefab = self:_choose_weighted(prefabs, distance_t)
			if not prefab then break end
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
	local inner = self.sampling_exclusion_radius
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
	if self.max_chunks and #centers > self.max_chunks then
		local trimmed = {}
		for i = 1, self.max_chunks do
			trimmed[i] = centers[i]
		end
		centers = trimmed
	end

	local forced_biome = override_biome and self:_find_biome(override_biome) or nil

	for _, center in ipairs(centers) do
		local chunk_center = Vector3.new(center.X, self.base_y, center.Y)
		local biome = forced_biome or self:_select_biome(center.X, center.Y)
		local biome_name = biome.name
		local distance_t = self:_distance_t(center.X, center.Y)

		self.stats.chunks += 1

		-- Place structures FIRST so resources can avoid them
		local structure_chance = resolve_probability(self.random, biome.structure_count or biome.structureCount)
		local structure_prefabs = self:_resolve_prefabs_weighted("StructurePrefabs", biome_name, biome.structures)
		local structure_factor = self:_distance_factor_for_list(structure_prefabs, distance_t)
		local structure_count = (self.random:NextNumber() <= (structure_chance * structure_factor)) and 1 or 0
		if structure_count > 0 then
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
				self.spawn_subfolders.Structures,
				structure_prefabs,
				distance_t
			)
		end

		local objective_chance = resolve_probability(self.random, biome.objective_count or biome.objectiveCount)
		local objective_prefabs = self:_resolve_prefabs_weighted("ObjectivePrefabs", biome_name, biome.objectives)
		local objective_factor = self:_distance_factor_for_list(objective_prefabs, distance_t)
		local objective_count = (self.random:NextNumber() <= (objective_chance * objective_factor)) and 1 or 0
		if objective_count > 0 then
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
				self.spawn_subfolders.Objectives,
				objective_prefabs,
				distance_t
			)
		end

		-- Now place regions and scatter resources (they will avoid structures)
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
