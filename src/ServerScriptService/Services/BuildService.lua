-- BuildService.lua
-- Server-authoritative grid placement with costs and workbench support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local GridService = require(script.Parent.GridService)
local InventoryService = require(script.Parent.InventoryService)

local BuildService = {}
BuildService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
BuildService._remoteBuild = Util.GetRemote(BuildService._remotesFolder, Config.RemoteNames.Build)

local function isAllowedType(t)
	return Config.BUILD.AllowedTypes[t] == true
end

local function isPlaceableItem(t)
	return Config.BUILD.PlaceableItems and Config.BUILD.PlaceableItems[t] == true
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
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptParent
	
	-- Store station type for client reference
	inst:SetAttribute("StationType", stationType)
	inst:SetAttribute("StationTier", station.Tier)
	
	-- Add tag for easy finding
	CollectionService:AddTag(inst, "CraftingStation")
end

function BuildService:Place(plr, buildType, worldPos)
	if not isAllowedType(buildType) then return false end
	if not withinRange(plr, worldPos) then return false end
	local dist = math.sqrt(worldPos.X * worldPos.X + worldPos.Z * worldPos.Z)
	if dist > (Config.WORLD.WorldRadius or 2200) then return false end
	if dist < (Config.WORLD.CenterExclusionRadius or 0) then return false end

	local gx, gz = GridService:WorldToGrid(worldPos)
	if GridService:IsOccupied(gx, gz) then return false end

	-- Check if this is a placeable item (uses item from inventory)
	if isPlaceableItem(buildType) then
		-- Check if player has the item
		if not InventoryService:HasItem(plr, buildType, 1) then
			print(string.format("[BuildService] Player %s doesn't have %s to place", plr.Name, buildType))
			return false
		end
		-- Consume the item
		if not InventoryService:Take(plr, buildType, 1) then
			print(string.format("[BuildService] Failed to consume %s from %s", buildType, plr.Name))
			return false
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
		if not InventoryService:PayCost(plr, adjusted) then return false end
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
	applyDurability(inst)
	pcall(function() CollectionService:AddTag(inst, "Structure") end)

	-- Setup workbench interaction if this is a crafting station
	local stationDef = WorkbenchConfig.STATIONS[buildType]
	if stationDef and stationDef.BuildType then
		setupWorkbenchInteraction(inst, buildType)
	end

	GridService:Reserve(gx, gz, plr.UserId, inst)
	
	print(string.format("[BuildService] %s placed %s at (%d, %d)", plr.Name, buildType, gx, gz))
	return true
end

function BuildService:Remove(plr, target)
	if typeof(target) ~= "Instance" or not target.Parent then return false end
	local owner = target:GetAttribute("OwnerUserId")
	if owner and owner ~= plr.UserId then return false end
	local pos = target:IsA("Model") and target:GetPivot().Position or target.Position
	if not withinRange(plr, pos) then return false end
	
	-- Return placeable item to player's inventory
	local buildType = target:GetAttribute("BuildType")
	if buildType and isPlaceableItem(buildType) then
		InventoryService:Give(plr, buildType, 1)
		print(string.format("[BuildService] Returned %s to %s's inventory", buildType, plr.Name))
	end
	
	local gx = target:GetAttribute("GridX")
	local gz = target:GetAttribute("GridZ")
	if typeof(gx) == "number" and typeof(gz) == "number" then
		GridService:Release(gx, gz)
	else
		GridService:ReleaseByInstance(target)
	end
	target:Destroy()
	return true
end

function BuildService:Bind()
	if not self._remoteBuild then return end
	self._remoteBuild.OnServerEvent:Connect(function(plr, action, payload)
		if type(action) ~= "string" then return end
		if action == "Place" then
			local buildType = payload and payload.Type
			local pos = payload and payload.Position
			if typeof(pos) ~= "Vector3" or type(buildType) ~= "string" then return end
			pcall(function() BuildService:Place(plr, buildType, pos) end)
		elseif action == "Remove" then
			local target = payload and payload.Target
			pcall(function() BuildService:Remove(plr, target) end)
		end
	end)
end

return BuildService
