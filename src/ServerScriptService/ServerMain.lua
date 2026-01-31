-- ServerMain.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ThreatService = require(script.Parent.Services.ThreatService)
local EventService = require(script.Parent.Services.EventService)
local ObjectiveService = require(script.Parent.Services.ObjectiveService)
local SpawnService = require(script.Parent.Services.SpawnService)
local CombatService = require(script.Parent.Services.CombatService)
local BuildService = require(script.Parent.Services.BuildService)
local InteractService = require(script.Parent.Services.InteractService)
local SpawnerOrchestrator = require(script.Parent.Services.SpawnerOrchestrator)
local StatusService = require(script.Parent.Services.StatusService)
local RewardsObserver = require(script.Parent.Services.RewardsObserver)
local RoundService = require(script.Parent.Services.RoundService)
local WorldBuilder = require(script.Parent.Services.WorldBuilder)
local BiomeService = require(script.Parent.Services.BiomeService)
local WorldGenController = require(script.Parent.Services.WorldGenController)
local RoleService = require(script.Parent.Services.RoleService)
local ProfileService = require(script.Parent.Services.ProfileService)
local GameStateService = require(script.Parent.Services.GameStateService)
local EventEffectsService = require(script.Parent.Services.EventEffectsService)
local GameLoopService = require(script.Parent.Services.GameLoopService)
local ObjectiveRuntimeService = require(script.Parent.Services.ObjectiveRuntimeService)
local DropItemService = require(script.Parent.Services.DropItemService)
local InventoryActionService = require(script.Parent.Services.InventoryActionService)
local ToolService = require(script.Parent.Services.ToolService)
local ArmorService = require(script.Parent.Services.ArmorService)

-- Init / bind
ObjectiveService:Init()
BiomeService:Init()
CombatService:Bind()
BuildService:Bind()
InteractService:Bind()
SpawnerOrchestrator:Bind()
StatusService:Bind()
RoundService:Bind()
GameStateService:Init()
WorldGenController:Init()
RoleService:Init()
GameLoopService:Init()
ObjectiveRuntimeService:Init()
DropItemService:Init()
InventoryActionService:Init()
ToolService:Init()
ArmorService:Init()
--	WorldBuilder:Init()

-- Relay biome changes to BuildService for global Decay pass
Players.PlayerAdded:Connect(function(plr)
	BiomeService:SendToPlayer(plr)
	-- You can also send snapshots of EventService/Objectives via their remotes
end)

-- Biome change hook for Decay
if _G.Ecoshift and type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
	_G.Ecoshift.OnBiomeChangedAdd(function(cur)
		pcall(function() BuildService:OnBiomeChanged(cur) end)
	end)
end

-- Example: expose a function other systems can call to compute wave composition
_G.Ecoshift = _G.Ecoshift or {}
_G.Ecoshift.ComputeEnemyWave = function() return SpawnService:ComputeEnemyWave() end
_G.Ecoshift.GetActiveResourceTags = function() return SpawnService:GetActiveResourceTags() end
_G.Ecoshift.AIService = require(script.Parent.Services.AIService)
