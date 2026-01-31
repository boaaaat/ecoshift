-- TerrainService.lua
-- Generates a flat terrain block and paints by biome.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TerrainService = {}

local function materialFromName(name)
	if typeof(name) == "EnumItem" then
		return name
	end
	if type(name) ~= "string" then
		return Enum.Material.Grass
	end
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material
	end
	return Enum.Material.Grass
end

function TerrainService:GenerateFlat(biomeName)
	local terrain = Workspace.Terrain
	terrain:Clear()

	local radius = Config.WORLD.WorldRadius or 2000
	local thickness = (Config.TERRAIN and Config.TERRAIN.Thickness) or 24
	local baseY = Config.WORLD.BaseY or 0

	local size = Vector3.new(radius * 2, thickness, radius * 2)
	local center = Vector3.new(0, baseY - (thickness * 0.5), 0)

	local matName = Config.TERRAIN and Config.TERRAIN.MaterialByBiome and Config.TERRAIN.MaterialByBiome[biomeName]
	local material = materialFromName(matName)

	terrain:FillBlock(CFrame.new(center), size, material)
end

return TerrainService
