local SpatialHash = {}
SpatialHash.__index = SpatialHash

local function cell_key(cx, cz)
	return tostring(cx) .. ":" .. tostring(cz)
end

local function get_cell_range(rect, cell_size)
	local min_cx = math.floor(rect.min_x / cell_size)
	local max_cx = math.floor(rect.max_x / cell_size)
	local min_cz = math.floor(rect.min_z / cell_size)
	local max_cz = math.floor(rect.max_z / cell_size)
	return min_cx, max_cx, min_cz, max_cz
end

function SpatialHash.new(cell_size)
	local self = setmetatable({}, SpatialHash)
	self.cell_size = cell_size or 64
	self.buckets = {}
	self.items = {}
	return self
end

function SpatialHash:clear()
	table.clear(self.buckets)
	table.clear(self.items)
end

function SpatialHash:insert(id, rect)
	self.items[id] = rect
	local min_cx, max_cx, min_cz, max_cz = get_cell_range(rect, self.cell_size)
	for cx = min_cx, max_cx do
		for cz = min_cz, max_cz do
			local key = cell_key(cx, cz)
			local bucket = self.buckets[key]
			if not bucket then
				bucket = {}
				self.buckets[key] = bucket
			end
			bucket[#bucket + 1] = id
		end
	end
end

function SpatialHash:intersects(rect)
	local min_cx, max_cx, min_cz, max_cz = get_cell_range(rect, self.cell_size)
	for cx = min_cx, max_cx do
		for cz = min_cz, max_cz do
			local bucket = self.buckets[cell_key(cx, cz)]
			if bucket then
				for i = 1, #bucket do
					local other = self.items[bucket[i]]
					if other then
						if not (
							rect.max_x < other.min_x
							or rect.min_x > other.max_x
							or rect.max_z < other.min_z
							or rect.min_z > other.max_z
						) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

return SpatialHash
