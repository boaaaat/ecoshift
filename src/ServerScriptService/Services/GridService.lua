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
	local size = Config.GRID.Size
	local gx = math.floor((pos.X / size) + 0.5)
	local gz = math.floor((pos.Z / size) + 0.5)
	return gx, gz
end

function GridService:GridToWorld(gx, gz, y)
	local size = Config.GRID.Size
	return Vector3.new(gx * size, y or BiomeConfig.WORLD.BaseY, gz * size)
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
