-- WorldGenController.lua
-- Now uses ChunkStreamingService for dynamic chunk loading instead of generating entire world at once.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldGenConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local BiomeService = require(script.Parent.BiomeService)
local TerrainService = require(script.Parent.TerrainService)
local ChunkStreamingService = require(script.Parent.ChunkStreamingService)

local WorldGenController = {}
WorldGenController._busy = false
WorldGenController._initialized = false
WorldGenController._pendingBiome = nil

local function clearFolder(folder)
	if not folder then return end
	local children = folder:GetChildren()
	for i = 1, #children do
		if children[i] and children[i].Parent then
			children[i]:Destroy()
		end
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
	if type(biomeName) ~= "string" or not WorldGenConfig.biomes[biomeName] then return end
	self._pendingBiome = biomeName
	if self._busy then return end
	self._busy = true
	
	task.spawn(function()
		while self._pendingBiome do
			local requestedBiome = self._pendingBiome
			self._pendingBiome = nil
			local ok, err = pcall(function()
				-- Invalidate workers before any old folder or terrain is removed.
				ChunkStreamingService:Pause()
				clearGeneratedWorld()
				clearEnemies()
				-- Player buildings and their occupancy records persist through shifts.
				TerrainService:GenerateFlat(requestedBiome)
				task.wait()
				-- A newer request supersedes this terrain pass; do not spawn stale content.
				if self._pendingBiome then return end
				ChunkStreamingService:SetBiome(requestedBiome, true)
				local folderName = WorldGenConfig.spawn_folder_name or "GeneratedWorld"
				local created = Workspace:FindFirstChild(folderName)
				if created then created:SetAttribute("Generated", true) end
			end)
			if not ok then
				warn(string.format("[WorldGenController] Failed to generate %s: %s", requestedBiome, tostring(err)))
			end
		end
		self._busy = false
	end)
end

function WorldGenController:Init()
	if self._initialized then return end
	self._initialized = true
	
	-- Initialize ChunkStreamingService
	ChunkStreamingService:Init()
	
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
