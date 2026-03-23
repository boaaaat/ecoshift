-- BuildService.lua
-- Server-authoritative grid placement with costs and workbench support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local GridService = require(script.Parent.GridService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local GameStateService = require(script.Parent.GameStateService)

local BuildService = {}
BuildService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
BuildService._remoteBuild = Util.GetRemote(BuildService._remotesFolder, Config.RemoteNames.Build)

local CHEST_TAGS = {
	Common_Chest = true,
	Rare_Chest = true,
	Legendary_Chest = true,
	Celestial_Chest = true,
}

local function isAllowedType(t)
	return Config.BUILD.AllowedTypes[t] == true
end

local function isPlaceableItem(t)
	return Config.BUILD.PlaceableItems and Config.BUILD.PlaceableItems[t] == true
end

local function isChestStructure(inst, buildType)
	if buildType == "Chest" then
		return true
	end
	for tag in pairs(CHEST_TAGS) do
		if CollectionService:HasTag(inst, tag) then
			return true
		end
	end
	return false
end

local function withinRange(plr, worldPos)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - worldPos).Magnitude <= (Config.GRID.BuildMaxDistance or 45)
end

local function getPrefab(buildType)
	local folder = ServerStorage:FindFirstChild("BuildPrefabs")
	if folder then
		return folder:FindFirstChild(buildType)
	end
	return nil
end

local function createFallbackPart(buildType, position)
	local part = Instance.new("Part")
	part.Size = Vector3.new(Config.GRID.Size, Config.GRID.Size, Config.GRID.Size)
	part.Anchored = true
	part.Position = position
	part.Name = "Build_" .. buildType
	part:SetAttribute("BuildType", buildType)
	return part
end

local function applyDurability(inst)
	local dur = Instance.new("NumberValue")
	dur.Name = "Durability"
	dur.Value = 100
	dur.Parent = inst
	inst:SetAttribute("DurabilityMax", 100)
end

-- Create interaction prompt for workbenches
local function setupWorkbenchInteraction(inst, stationType)
	local station = WorkbenchConfig.STATIONS[stationType]
	if not station then return end
	
	-- Find the part to attach prompt to
	local promptParent = inst
	if inst:IsA("Model") then
		promptParent = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
	end
	if not promptParent then return end
	
	-- Create proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = station.Name or stationType
	prompt.ActionText = "Open"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = station.InteractRadius or 8
	prompt.RequiresLineOfSight = true
	prompt.Parent = promptParent
	
	-- Store station type for client reference
	inst:SetAttribute("StationType", stationType)
	inst:SetAttribute("StationTier", station.Tier)
	
	-- Add tag for easy finding
	CollectionService:AddTag(inst, "CraftingStation")
end

local function resolveChestTag(inst)
	for tag in pairs(CHEST_TAGS) do
		if CollectionService:HasTag(inst, tag) then
			return tag
		end
	end

	local tagAttr = inst:GetAttribute("ChestTag")
	if type(tagAttr) == "string" and CHEST_TAGS[tagAttr] then
		return tagAttr
	end

	local tierAttr = tostring(inst:GetAttribute("ChestTier") or ""):lower()
	if tierAttr == "rare" then
		return "Rare_Chest"
	elseif tierAttr == "legendary" then
		return "Legendary_Chest"
	elseif tierAttr == "celestial" then
		return "Celestial_Chest"
	end

	return "Common_Chest"
end

local function setupChestInteraction(inst)
	CollectionService:AddTag(inst, resolveChestTag(inst))
end

function BuildService:Place(plr, buildType, worldPos)
	if type(buildType) ~= "string" or typeof(worldPos) ~= "Vector3" then
		return false, "InvalidPayload"
	end
	if GameStateService:IsGameOver() then
		return false, "GameOver"
	end
	if not isAllowedType(buildType) then return false, "InvalidType" end
	if not withinRange(plr, worldPos) then return false, "OutOfRange" end
	local dist = math.sqrt(worldPos.X * worldPos.X + worldPos.Z * worldPos.Z)
	if dist > (BiomeConfig.WORLD.WorldRadius or 2200) then return false, "OutOfBounds" end
	if dist < (BiomeConfig.WORLD.CenterExclusionRadius or 0) then return false, "OutOfBounds" end

	local gx, gz = GridService:WorldToGrid(worldPos)
	if GridService:IsOccupied(gx, gz) then return false, "Occupied" end

	-- Check if this is a placeable item (uses item from inventory)
	if isPlaceableItem(buildType) then
		-- Check if player has the item
		if not InventoryService:HasItem(plr, buildType, 1) then
			print(string.format("[BuildService] Player %s doesn't have %s to place", plr.Name, buildType))
			return false, "MissingPlaceableItem"
		end
		-- Consume the item
		if not InventoryService:Take(plr, buildType, 1) then
			print(string.format("[BuildService] Failed to consume %s from %s", buildType, plr.Name))
			return false, "MissingPlaceableItem"
		end
	else
		-- Traditional building with resource costs
		local cost = Config.BUILD.Costs[buildType] or {}
		local buildMult = tonumber(plr:GetAttribute("Role_Build")) or 1.0
		local adjusted = {}
		for _, entry in ipairs(cost) do
			local n = math.max(1, math.floor((entry.N or 1) / math.max(buildMult, 0.1)))
			adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
		end
		if not InventoryService:PayCost(plr, adjusted) then return false, "MissingCost" end
	end

	local pos = GridService:GridToWorld(gx, gz, worldPos.Y)
	local prefab = getPrefab(buildType)
	local inst
	if prefab then
		inst = prefab:Clone()
		if inst:IsA("Model") then
			inst:PivotTo(CFrame.new(pos))
		elseif inst:IsA("BasePart") then
			inst.CFrame = CFrame.new(pos)
		end
	else
		inst = createFallbackPart(buildType, pos)
	end

	inst.Parent = workspace
	inst:SetAttribute("OwnerUserId", plr.UserId)
	inst:SetAttribute("GridX", gx)
	inst:SetAttribute("GridZ", gz)
	inst:SetAttribute("BuildType", buildType)
	inst:SetAttribute("MapMarkerType", "PlayerBuiltStructure")
	inst:SetAttribute("MapMarkerLabel", tostring(buildType))
	applyDurability(inst)
	pcall(function() CollectionService:AddTag(inst, "Structure") end)

	-- Setup workbench interaction if this is a crafting station
	local stationDef = WorkbenchConfig.STATIONS[buildType]
	if stationDef and stationDef.BuildType then
		setupWorkbenchInteraction(inst, buildType)
	end

	-- Placed chests must be tagged so LootService binds prompts and UI events.
	if buildType == "Chest" then
		setupChestInteraction(inst)
	end

	GridService:Reserve(gx, gz, plr.UserId, inst)
	
	print(string.format("[BuildService] %s placed %s at (%d, %d)", plr.Name, buildType, gx, gz))
	return true, "Success"
end

function BuildService:Remove(plr, target)
	if typeof(target) ~= "Instance" or not target.Parent then return false, "InvalidPayload" end
	if GameStateService:IsGameOver() then
		return false, "GameOver"
	end
	local placed = target
	if placed:IsA("BasePart") then
		local maybeModel = placed:FindFirstAncestorOfClass("Model")
		if maybeModel and maybeModel:GetAttribute("BuildType") then
			placed = maybeModel
		end
	end
	if not placed:GetAttribute("BuildType") then return false, "NotStructure" end
	if not CollectionService:HasTag(placed, "Structure") then return false, "NotStructure" end

	local owner = tonumber(placed:GetAttribute("OwnerUserId"))
	if owner ~= plr.UserId then return false, "NotOwner" end

	local pos = placed:IsA("Model") and placed:GetPivot().Position or placed.Position
	if not withinRange(plr, pos) then return false, "RemoveOutOfRange" end
	
	local buildType = placed:GetAttribute("BuildType")
	if buildType and isPlaceableItem(buildType) then
		if not InventoryService:CanFit(plr, buildType, 1) then
			return false, "InventoryFull"
		end
		if isChestStructure(placed, buildType) then
			local contents = LootService:GetChestContents(placed)
			if #contents > 0 then
				LootService:SpillChestContents(placed, pos)
			end
		end
		if InventoryService:Give(plr, buildType, 1, true) ~= 1 then
			return false, "InventoryFull"
		end
		print(string.format("[BuildService] Returned %s to %s's inventory", buildType, plr.Name))
	end
	
	local gx = placed:GetAttribute("GridX")
	local gz = placed:GetAttribute("GridZ")
	if typeof(gx) == "number" and typeof(gz) == "number" then
		GridService:Release(gx, gz)
	else
		GridService:ReleaseByInstance(placed)
	end
	placed:Destroy()
	return true, "Success"
end

function BuildService:Bind()
	if not self._remoteBuild then
		warn("[BuildService] Missing build remote:", Config.RemoteNames.Build)
		return
	end
	self._remoteBuild.OnServerEvent:Connect(function(plr, action, payload)
		if type(action) ~= "string" then return end
		if action == "Place" then
			local buildType = payload and payload.Type
			local pos = payload and payload.Position
			if typeof(pos) ~= "Vector3" or type(buildType) ~= "string" then
				self._remoteBuild:FireClient(plr, "Result", {
					Action = "Place",
					Success = false,
					Reason = "InvalidPayload",
				})
				return
			end
			local ok, placed, reason = pcall(function()
				return BuildService:Place(plr, buildType, pos)
			end)
			local success = ok and placed == true
			self._remoteBuild:FireClient(plr, "Result", {
				Action = "Place",
				Success = success,
				Reason = success and (reason or "Success") or (ok and (reason or "Unknown") or "Unknown"),
			})
		elseif action == "Remove" then
			local target = payload and payload.Target
			if typeof(target) ~= "Instance" then
				self._remoteBuild:FireClient(plr, "Result", {
					Action = "Remove",
					Success = false,
					Reason = "InvalidPayload",
				})
				return
			end
			local ok, removed, reason = pcall(function()
				return BuildService:Remove(plr, target)
			end)
			local success = ok and removed == true
			self._remoteBuild:FireClient(plr, "Result", {
				Action = "Remove",
				Success = success,
				Reason = success and (reason or "Success") or (ok and (reason or "Unknown") or "Unknown"),
			})
		end
	end)
end

return BuildService
