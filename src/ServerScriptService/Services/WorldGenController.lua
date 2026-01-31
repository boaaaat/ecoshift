-- WorldGenController.lua
-- Regenerates the entire world when biome changes.
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local BiomeGenerator = require(script.Parent.Parent.WorldGen.BiomeGenerator)
local WorldGenConfig = require(script.Parent.Parent.WorldGen.BiomeConfig)
local BiomeService = require(script.Parent.BiomeService)
local GridService = require(script.Parent.GridService)
local TerrainService = require(script.Parent.TerrainService)
local ResourceNodeService = require(script.Parent.ResourceNodeService)

local WorldGenController = {}
WorldGenController._busy = false
WorldGenController._initialized = false

local function clearFolder(folder)
	if not folder then return end
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function clearGeneratedWorld()
	local folderName = WorldGenConfig.spawn_folder_name or "GeneratedWorld"
	local existing = Workspace:FindFirstChild(folderName)
	if existing then
		clearFolder(existing)
		existing:SetAttribute("Generated", false)
	end
end

local function clearEnemies()
	local worldEnemies = Workspace:FindFirstChild("Enemies")
	if worldEnemies then
		clearFolder(worldEnemies)
	end
end

function WorldGenController:GenerateBiome(biomeName)
	if self._busy then return end
	self._busy = true
	clearGeneratedWorld()
	clearEnemies()
	GridService:Clear()
	TerrainService:GenerateFlat(biomeName)
	local generator = BiomeGenerator.new(WorldGenConfig)
	generator:GenerateBiome(biomeName)
	ResourceNodeService:BindGeneratedWorld()
	local folderName = WorldGenConfig.spawn_folder_name or "GeneratedWorld"
	local created = Workspace:FindFirstChild(folderName)
	if created then
		created:SetAttribute("Generated", true)
	end
	self._busy = false
end

function WorldGenController:Init()
	if self._initialized then return end
	self._initialized = true
	local initial = BiomeService:GetCurrent()
	self:GenerateBiome(initial)
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 50 do
			if type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
				_G.Ecoshift.OnBiomeChangedAdd(function(newBiome)
					self:GenerateBiome(newBiome)
				end)
				break
			end
			task.wait(0.1)
		end
	end)
end

return WorldGenController
