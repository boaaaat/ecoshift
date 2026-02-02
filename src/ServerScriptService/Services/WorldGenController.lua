-- WorldGenController.lua
-- Now uses ChunkStreamingService for dynamic chunk loading instead of generating entire world at once.
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local WorldGenConfig = require(script.Parent.Parent.WorldGen.BiomeConfig)
local BiomeService = require(script.Parent.BiomeService)
local GridService = require(script.Parent.GridService)
local TerrainService = require(script.Parent.TerrainService)
local ChunkStreamingService = require(script.Parent.ChunkStreamingService)
local LootService = require(script.Parent.LootService)

local WorldGenController = {}
WorldGenController._busy = false
WorldGenController._initialized = false

-- Use streaming from config (set Config.use_streaming = false in BiomeConfig to revert)
local USE_STREAMING = WorldGenConfig.use_streaming ~= false

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
	if self._busy then return end
	self._busy = true
	
	task.spawn(function()
		clearGeneratedWorld()
		clearEnemies()
		GridService:Clear()
		
		-- Terrain generation (still generates full terrain - Roblox terrain can't easily stream)
		TerrainService:GenerateFlat(biomeName)
		task.wait()
		
		if USE_STREAMING then
			-- Use dynamic chunk streaming - chunks load around players
			ChunkStreamingService:SetBiome(biomeName, true)
			print("[WorldGenController] Streaming mode - chunks will load around players")
		else
			-- Legacy: Generate entire world at once
			local BiomeGenerator = require(script.Parent.Parent.WorldGen.BiomeGenerator)
			local ResourceNodeService = require(script.Parent.ResourceNodeService)
			local generator = BiomeGenerator.new(WorldGenConfig)
			generator:GenerateBiome(biomeName)
			task.defer(function()
				ResourceNodeService:BindGeneratedWorld()
				if LootService and LootService.RescanChests then
					LootService:RescanChests()
				else
					warn("[WorldGenController] LootService missing RescanChests")
				end
				if LootService and LootService.RescanMonsters then
					LootService:RescanMonsters()
				end
			end)
		end
		
		local folderName = WorldGenConfig.spawn_folder_name or "GeneratedWorld"
		local created = Workspace:FindFirstChild(folderName)
		if created then
			created:SetAttribute("Generated", true)
		end
		self._busy = false
	end)
end

function WorldGenController:Init()
	if self._initialized then return end
	self._initialized = true
	
	-- Initialize ChunkStreamingService if using streaming
	if USE_STREAMING then
		ChunkStreamingService:Init()
	end
	
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
