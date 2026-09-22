-- GridService.lua
-- Handles grid snapping and occupancy for building.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)

local GridService = {}
GridService._grid = {} -- [key] = {ownerId, instance}

local function key(x, z)
	return tostring(x) .. ":" .. tostring(z)
end

function GridService:WorldToGrid(pos)
	-- Occupancy uses half-cell coordinates. Tile centers are even/even while
	-- wall, door, and gate edges use one odd coordinate.
	local spacing = Config.GRID.Size * 0.5
	local gx = math.floor((pos.X / spacing) + 0.5)
	local gz = math.floor((pos.Z / spacing) + 0.5)
	return gx, gz
end

function GridService:GridToWorld(gx, gz, y)
	local spacing = Config.GRID.Size * 0.5
	return Vector3.new(gx * spacing, y or BiomeConfig.WORLD.BaseY, gz * spacing)
end

function GridService:IsOccupied(gx, gz)
	return self._grid[key(gx, gz)] ~= nil
end

function GridService:Reserve(gx, gz, ownerId, instance)
	local k = key(gx, gz)
	if self._grid[k] then return false end
	self._grid[k] = { Owner = ownerId, Instance = instance }
	return true
end

function GridService:Release(gx, gz)
	self._grid[key(gx, gz)] = nil
end

function GridService:ReleaseByInstance(inst)
	for k, entry in pairs(self._grid) do
		if entry.Instance == inst then
			self._grid[k] = nil
			break
		end
	end
end

function GridService:Clear()
	table.clear(self._grid)
end

return GridService
