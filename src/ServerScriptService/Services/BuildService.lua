-- BuildService.lua
-- Server-authoritative grid placement with costs and workbench support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local BuildPlacement = require(ReplicatedStorage.Shared:WaitForChild("BuildPlacement"))
local GridService = require(script.Parent.GridService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local GameStateService = require(script.Parent.GameStateService)
local ItemDropService = require(script.Parent.ItemDropService)

local BuildService = { _salvageHolds = {}, _requests = {}, _entries = setmetatable({}, {__mode="k"}) }
local Instances=require(ReplicatedStorage.Shared.ItemInstance)
local Catalog=require(ReplicatedStorage.Shared.OverhaulCatalog)
local LightConfig = require(ReplicatedStorage.Shared.LightConfig)
local BuildModels = require(ReplicatedStorage.Shared.Art.OverhaulBuildModels)
local SnapshotCodec = require(script.Parent.WorldSnapshotCodec)
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

local function isLightType(t)
	return LightConfig.Definitions[t] ~= nil
end

local function isChestStructure(inst, buildType)
	if buildType == "Chest" or buildType == "LargeChest" then
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
	if ReplicatedStorage:GetAttribute("WorldRestoring") or plr:GetAttribute("WorldPlayerLoading") or plr:GetAttribute("WorldPlayerRestoring") then return false end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or plr:GetAttribute("IsDead") then return false end
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
	if LightConfig.Definitions[buildType] then
		return BuildModels.Create(buildType)
	end

	local part = Instance.new("Part")
	local definition=Catalog.Placeables[buildType]
	part.Size=definition and definition.Size or Vector3.new(Config.GRID.Size,Config.GRID.Size,Config.GRID.Size)
	part.Anchored = true
	part.Position = position
	part.Name = "Build_" .. buildType
	part:SetAttribute("BuildType", buildType)
	return part
end

local function refundItems(plr, entries)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local basePos = root and root.Position or nil
	for _, entry in ipairs(entries or {}) do
		local itemId = entry and entry.Id
		local amount = math.max(0, math.floor(tonumber(entry and entry.N) or 0))
		if itemId and amount > 0 then
			local added = InventoryService:GiveEntry(plr, entry, false)
			local remaining = amount - added
			if remaining > 0 and basePos then
				local spill=Instances.Copy(entry);spill.N=remaining
				ItemDropService:SpawnDrop(itemId, remaining, basePos + Vector3.new(0, 2, 0), {Entry=spill})
			end
		end
	end
end

local function applyDurability(inst)
	local dur = inst:FindFirstChild("Durability")
	if dur and not dur:IsA("NumberValue") then dur:Destroy(); dur = nil end
	dur = dur or Instance.new("NumberValue")
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
	
	-- Reuse only this station's prompt, leaving unrelated authored interactions alone.
	local prompt
	for _, candidate in ipairs(inst:GetDescendants()) do
		if candidate:IsA("ProximityPrompt") and (candidate.Name == "CraftingStationPrompt"
			or (candidate.ObjectText == (station.Name or stationType) and candidate.ActionText == "Open")) then
			prompt = candidate
			break
		end
	end
	prompt = prompt or Instance.new("ProximityPrompt")
	prompt.Name = "CraftingStationPrompt"
	if inst:IsA("Model") then
		-- CraftingService validates from the model pivot, which can differ from its primary part.
		local anchor = promptParent:FindFirstChild("CraftingPromptAttachment")
		if not anchor or not anchor:IsA("Attachment") then
			anchor = Instance.new("Attachment")
			anchor.Name = "CraftingPromptAttachment"
			anchor.Parent = promptParent
		end
		anchor.WorldPosition = inst:GetPivot().Position
		promptParent = anchor
	end
	prompt.ObjectText = station.Name or stationType
	prompt.ActionText = "Open"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
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

function BuildService:Place(plr, buildType, worldPos, rotation)
	rotation = rotation == nil and 0 or rotation
	if type(rotation) ~= "number" or rotation ~= rotation or rotation < 0 or rotation >= 360 or rotation % 90 ~= 0 then
		return false, "InvalidRequest"
	end
	local count = 0
	for _, inst in ipairs(CollectionService:GetTagged("Structure")) do if inst:GetAttribute("BuildType") then count += 1 end end
	if count >= SnapshotCodec.MaxStructures then return false, "StructureLimit" end
	if type(buildType) ~= "string" or typeof(worldPos) ~= "Vector3" then
		return false, "InvalidPayload"
	end
	if worldPos.X ~= worldPos.X or worldPos.Y ~= worldPos.Y or worldPos.Z ~= worldPos.Z
		or worldPos.Magnitude == math.huge then return false, "InvalidPayload" end
	if GameStateService:IsGameOver() then
		return false, "GameOver"
	end
	if not isAllowedType(buildType) then return false, "InvalidType" end
	if not withinRange(plr, worldPos) then return false, "OutOfRange" end
	local held = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
	if not held or held.Name ~= buildType then return false, "EquipBuildItem" end
	if not BuildPlacement.WithinCamp(worldPos) and not isLightType(buildType) then return false, "OutsideCamp" end

	local gx, gz = GridService:WorldToGrid(worldPos)
	if GridService:IsOccupied(gx, gz) then return false, "Occupied" end
	local pos = BuildPlacement.Surface(worldPos)
	if not pos then return false, "NoSurface" end
	if not BuildPlacement.WithinCamp(pos) and not isLightType(buildType) then return false, "OutsideCamp" end
	if not withinRange(plr, pos) then return false, "OutOfRange" end
	local expiresOnBiomeShift = isLightType(buildType) and not BuildPlacement.WithinCamp(pos)
	local expiresAfterBiomeVisit = expiresOnBiomeShift and ((ReplicatedStorage:GetAttribute("BiomeVisitSerial") or 0) + 1) or nil

 -- Every build is an inventory item; retain its station grade and contents.
 local selectedIndex,heldEntry
 for index,entry in pairs(InventoryService:GetAll(plr).Hotbar) do
  if entry and entry.Id==buildType and (not held:GetAttribute("GearUid") or held:GetAttribute("GearUid")==entry.Uid) then selectedIndex=index;heldEntry=entry;break end
 end
 if not heldEntry then return false,"EquipBuildItem" end
 local creative=workspace:GetAttribute("WorldType")=="Creative" and plr:GetAttribute("CreativeMode")==true
 local placedEntry=Instances.Copy(heldEntry);placedEntry.N=1
 if creative then placedEntry.Uid=game:GetService("HttpService"):GenerateGUID(false)
 else
  placedEntry=InventoryService:TakeEntryFromSlot(plr,"Hotbar",selectedIndex,1,{ExpectedId=buildType})
  if not placedEntry then return false,"MissingPlaceableItem" end
 end
 local refundEntries=creative and {} or {placedEntry}

	local inst
	local placeOk, placeErr = pcall(function()
		local prefab = getPrefab(buildType)
		if prefab then
			inst = prefab:Clone()
		else
			inst = createFallbackPart(buildType, pos)
		end
		BuildPlacement.PutOnSurface(inst, CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation), 0))

		inst.Parent = workspace
		require(script.Parent.ExpeditionRewardsService):RecordActivity(plr)
		inst:SetAttribute("PlacementVersion", 1)
		inst:SetAttribute("OwnerUserId", plr.UserId)
		inst:SetAttribute("GridX", gx)
		inst:SetAttribute("GridZ", gz)
		inst:SetAttribute("BuildType", buildType)
		inst:SetAttribute("ExpiresOnBiomeShift", expiresOnBiomeShift or nil)
		inst:SetAttribute("ExpiresAfterBiomeVisit", expiresAfterBiomeVisit)
		self._entries[inst]=Instances.Copy(placedEntry)
		inst:SetAttribute("StationGrade",placedEntry.StationGrade or (Catalog.Stations[buildType] and Catalog.Stations[buildType].Grade))
		inst:SetAttribute("MapMarkerType", "PlayerBuiltStructure")
		inst:SetAttribute("MapMarkerLabel", tostring(buildType))
		applyDurability(inst)
		pcall(function() CollectionService:AddTag(inst, "Structure") end)
		require(script.Parent.UtilityBuildService):Bind(inst)
		require(script.Parent.UtilityBuildService):Restore(inst,placedEntry.UtilityState)

		-- Setup workbench interaction if this is a crafting station
		local stationDef = WorkbenchConfig.STATIONS[buildType]
		if stationDef then
			setupWorkbenchInteraction(inst, buildType)
			require(script.Parent.StationService):Bind(inst,buildType,placedEntry.StationGrade)
			require(script.Parent.StationService):Restore(inst,placedEntry.StationState)
			require(script.Parent.CookingService):RestoreStation(inst,placedEntry.CookingState)
		end
		if placedEntry.ChestState then LootService:RestoreChestState(inst,placedEntry.ChestState) end

		-- Placed chests must be tagged so LootService binds prompts and UI events.
		if buildType == "Chest" or buildType == "LargeChest" then
			setupChestInteraction(inst)
		end

		if not GridService:Reserve(gx, gz, plr.UserId, inst) then
			error("Occupied")
		end
	end)
	if not placeOk then
		if inst then
			pcall(function()
				GridService:ReleaseByInstance(inst)
				inst:Destroy()
			end)
		end
		refundItems(plr, refundEntries)
		if string.find(tostring(placeErr), "Occupied", 1, true) then
			return false, "Occupied"
		end
		warn("[BuildService] Placement failed:", placeErr)
		return false, "PlacementFailed"
	end
	
	print(string.format("[BuildService] %s placed %s at (%d, %d)", plr.Name, buildType, gx, gz))
	return true, expiresOnBiomeShift and "TemporaryLight" or "Success"
end

local function resolveStructure(target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace)
		or (not target:IsA("Model") and not target:IsA("BasePart")) then return false, "InvalidPayload" end
	local placed = target
	while placed and placed ~= workspace do
		if placed:GetAttribute("BuildType") and CollectionService:HasTag(placed, "Structure") then break end
		placed = placed.Parent
	end
	if not placed or placed == workspace or (not placed:IsA("Model") and not placed:IsA("BasePart")) then return false, "NotStructure" end
	return placed
end

local function salvageTarget(plr, target)
	if GameStateService:IsGameOver() then return false, "GameOver" end
	local placed, reason = resolveStructure(target)
	if not placed then return false, reason end

	local owner = tonumber(placed:GetAttribute("OwnerUserId"))
	if owner ~= plr.UserId then return false, "NotOwner" end

	local pos = placed:IsA("Model") and placed:GetPivot().Position or placed.Position
	if not withinRange(plr, pos) then return false, "RemoveOutOfRange" end
	local origin = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	params.RespectCanCollide = true
	-- Ground-level model pivots can hit terrain before the visible build.
	local aimPosition = placed:IsA("Model") and placed:GetBoundingBox().Position or pos
	local obstruction = workspace:Raycast(origin.Position, aimPosition - origin.Position, params)
	if obstruction and obstruction.Instance ~= placed and not obstruction.Instance:IsDescendantOf(placed) then return false, "SalvageBlocked" end
	return placed, pos
end

function BuildService:_beginSalvage(plr, target)
	self._salvageHolds[plr] = nil
	local placed, reason = salvageTarget(plr, target)
	if not placed then return false, reason end
	local now = os.clock()
	self._salvageHolds[plr] = { Target = placed, Character = plr.Character, Started = now, LastPulse = now }
	return true
end

function BuildService:_continueSalvage(plr, target)
	local hold = self._salvageHolds[plr]
	local placed = hold and salvageTarget(plr, target)
	if not hold or placed ~= hold.Target or hold.Character ~= plr.Character or os.clock() - hold.LastPulse > 0.6 then
		self._salvageHolds[plr] = nil
		return false
	end
	hold.LastPulse = os.clock()
	return true
end

function BuildService:Remove(plr, target)
	local hold = self._salvageHolds[plr]
	self._salvageHolds[plr] = nil
	local placed, pos = salvageTarget(plr, target)
	if not placed then return false, pos end
	if not hold or hold.Target ~= placed or hold.Character ~= plr.Character
		or os.clock() - hold.LastPulse > 0.6 or os.clock() - hold.Started < (Config.BUILD.SalvageSeconds or 3) then
		return false, "HoldToSalvage"
	end
	
	local buildType = placed:GetAttribute("BuildType")
	local creative = workspace:GetAttribute("WorldType") == "Creative" and plr:GetAttribute("CreativeMode") == true
	local refunded = false
	local utilityReady,utilityReason=require(script.Parent.UtilityBuildService):CanSalvage(placed)
	if not utilityReady then return false,utilityReason end
	local stationReady,stationReason=require(script.Parent.StationService):CanSalvage(plr,placed)
	if not stationReady then return false,stationReason end
	local kitchenReady, kitchenReason = require(script.Parent.CookingService):CanSalvage(placed)
	if not kitchenReady then return false, kitchenReason end
  if not creative and buildType and isPlaceableItem(buildType) then
  local entry=Instances.Copy(self._entries[placed] or {Id=buildType,N=1})
  entry.N=1;entry.StationGrade=placed:GetAttribute("StationGrade")
  entry.StationState=require(script.Parent.StationService):Snapshot(placed)
  entry.CookingState=require(script.Parent.CookingService):CaptureStation(placed)
  entry.UtilityState=require(script.Parent.UtilityBuildService):Capture(placed)
  if isChestStructure(placed,buildType) then entry.ChestState=LootService:CaptureChestState(placed) end
   if InventoryService:GiveEntry(plr,entry,true)~=1 then return false,"InventoryFull" end
   refunded = true
  end
	-- Runtime station state must be released in both modes. Creative simply skips
	-- serializing that state back into a returned inventory item.
	require(script.Parent.StationService):Remove(placed)
	require(script.Parent.UtilityBuildService):Remove(placed)

	local gx = placed:GetAttribute("GridX")
	local gz = placed:GetAttribute("GridZ")
	if typeof(gx) == "number" and typeof(gz) == "number" then
		GridService:Release(gx, gz)
	else
		GridService:ReleaseByInstance(placed)
	end
	placed:Destroy()
	require(script.Parent.ExpeditionRewardsService):RecordActivity(plr)
  return true, "Success", refunded
end

function BuildService:PickBlock(plr, target)
	if GameStateService:IsGameOver() then return false, "GameOver" end
	local placed, reason = resolveStructure(target)
	if not placed then return false, reason end
	local position = placed:IsA("Model") and placed:GetPivot().Position or placed.Position
	if not withinRange(plr, position) then return false, "OutOfRange" end
	local buildType = placed:GetAttribute("BuildType")
	if type(buildType) ~= "string" or not isPlaceableItem(buildType) then return false, "InvalidType" end
	local slotIndex = math.clamp(math.floor(tonumber(plr:GetAttribute("SelectedHotbarSlot")) or 1), 1, 6)
	local creative = workspace:GetAttribute("WorldType") == "Creative" and plr:GetAttribute("CreativeMode") == true
	if not InventoryService:PickToHotbar(plr, buildType, slotIndex, creative) then
		return false, "MissingPlaceableItem"
	end
	return true, "Success", slotIndex, buildType
end

function BuildService:CaptureWorldState()
	local result = {}
	for _, inst in ipairs(CollectionService:GetTagged("Structure")) do
		if inst:IsDescendantOf(workspace) and inst:GetAttribute("BuildType") then
			assert(#result < SnapshotCodec.MaxStructures, "Saved structure capacity exceeded")
			local durability = inst:FindFirstChild("Durability")
			local state = { Type = inst:GetAttribute("BuildType"), Owner = inst:GetAttribute("OwnerUserId"),
				PlacementVersion = inst:GetAttribute("PlacementVersion"),
				GridX = inst:GetAttribute("GridX"), GridZ = inst:GetAttribute("GridZ"), Transform = SnapshotCodec.CFrame(inst:GetPivot()),
				Durability = durability and durability.Value or 100, DurabilityMax = inst:GetAttribute("DurabilityMax") or 100 }
			if inst:GetAttribute("ExpiresOnBiomeShift") == true then state.ExpiresOnBiomeShift = true end
			if inst:GetAttribute("ExpiresAfterBiomeVisit") ~= nil then state.ExpiresAfterBiomeVisit = inst:GetAttribute("ExpiresAfterBiomeVisit") end
			if isChestStructure(inst, state.Type) then state.Chest = LootService:CaptureChestState(inst) end
			state.Cooking = require(script.Parent.CookingService):CaptureStation(inst)
			state.Station = require(script.Parent.StationService):Snapshot(inst)
			state.StationGrade=inst:GetAttribute("StationGrade")
			state.Item=Instances.Copy(self._entries[inst])
			state.Utility=require(script.Parent.UtilityBuildService):Capture(inst)
			table.insert(result, state)
		end
	end
	table.sort(result, function(a, b) if a.GridX ~= b.GridX then return a.GridX < b.GridX end; return a.GridZ < b.GridZ end)
	return result
end

function BuildService:RestoreWorldState(states)
	SnapshotCodec.BoundedCount(states, SnapshotCodec.MaxStructures)
	local occupied, prepared = {}, {}
	for _, state in ipairs(states) do
		assert(isAllowedType(state.Type), "Saved build type unavailable: " .. tostring(state.Type))
		local gx, gz = SnapshotCodec.Number(state.GridX, -1e5, 1e5), SnapshotCodec.Number(state.GridZ, -1e5, 1e5)
		assert(gx % 1 == 0 and gz % 1 == 0 and not occupied[gx .. ":" .. gz], "Invalid saved grid occupancy")
		occupied[gx .. ":" .. gz] = true
		local cf = SnapshotCodec.ReadCFrame(state.Transform)
		local expiresOnBiomeShift = state.ExpiresOnBiomeShift == true
		if state.ExpiresOnBiomeShift == nil and isLightType(state.Type) and not BuildPlacement.WithinCamp(cf.Position) then
			expiresOnBiomeShift = true
		end
		local currentBiomeVisit = ReplicatedStorage:GetAttribute("BiomeVisitSerial") or 0
		local expiresAfterBiomeVisit = state.ExpiresAfterBiomeVisit
		if expiresOnBiomeShift and expiresAfterBiomeVisit == nil then expiresAfterBiomeVisit = currentBiomeVisit + 1 end
		if expiresOnBiomeShift and expiresAfterBiomeVisit <= currentBiomeVisit then continue end
		local prefab = getPrefab(state.Type)
		local inst = prefab and prefab:Clone() or createFallbackPart(state.Type, cf.Position)
		inst:PivotTo(cf)
		inst:SetAttribute("PlacementVersion", 1)
		inst:SetAttribute("OwnerUserId", SnapshotCodec.Number(state.Owner))
		inst:SetAttribute("GridX", gx); inst:SetAttribute("GridZ", gz)
		inst:SetAttribute("BuildType", state.Type)
		inst:SetAttribute("ExpiresOnBiomeShift", expiresOnBiomeShift or nil)
		inst:SetAttribute("ExpiresAfterBiomeVisit", expiresAfterBiomeVisit)
		inst:SetAttribute("StationGrade",state.StationGrade)
		require(script.Parent.UtilityBuildService):Restore(inst,state.Utility)
		self._entries[inst]=Instances.Copy(state.Item or {Id=state.Type,N=1})
		inst:SetAttribute("MapMarkerType", "PlayerBuiltStructure")
		inst:SetAttribute("MapMarkerLabel", state.Type)
		applyDurability(inst)
		inst.Durability.Value = SnapshotCodec.Number(state.Durability, 0, 1e6)
		inst:SetAttribute("DurabilityMax", SnapshotCodec.Number(state.DurabilityMax, 1, 1e6))
		if WorkbenchConfig.STATIONS[state.Type] then
			setupWorkbenchInteraction(inst, state.Type)
			require(script.Parent.StationService):Bind(inst,state.Type,state.StationGrade)
			require(script.Parent.StationService):Restore(inst,state.Station)
		end
		if state.Chest then LootService:RestoreChestState(inst, state.Chest) end
		if ReplicatedStorage:GetAttribute("CookingEnabled") == true then require(script.Parent.CookingService):RestoreStation(inst, state.Cooking) end
		table.insert(prepared, inst)
	end
	for _, inst in ipairs(CollectionService:GetTagged("Structure")) do
		if inst:IsDescendantOf(workspace) and inst:GetAttribute("BuildType") then inst:Destroy() end
	end
	GridService:Clear()
	for _, inst in ipairs(prepared) do
		inst.Parent = workspace
		CollectionService:AddTag(inst, "Structure")
		require(script.Parent.UtilityBuildService):Bind(inst)
		if inst:GetAttribute("BuildType") == "Chest" or inst:GetAttribute("BuildType")=="LargeChest" then setupChestInteraction(inst) end
		assert(GridService:Reserve(inst:GetAttribute("GridX"), inst:GetAttribute("GridZ"), inst:GetAttribute("OwnerUserId"), inst), "Saved structure grid conflict")
	end
end

function BuildService:RemoveBiomeShiftLights()
	local removed = 0
	local currentBiomeVisit = ReplicatedStorage:GetAttribute("BiomeVisitSerial") or 0
	for _, inst in ipairs(CollectionService:GetTagged("Structure")) do
		if inst:IsDescendantOf(workspace) and inst:GetAttribute("ExpiresOnBiomeShift") == true
			and isLightType(inst:GetAttribute("BuildType"))
			and (inst:GetAttribute("ExpiresAfterBiomeVisit") == nil or inst:GetAttribute("ExpiresAfterBiomeVisit") <= currentBiomeVisit) then
			for player, hold in pairs(self._salvageHolds) do
				if hold.Target == inst then self._salvageHolds[player] = nil end
			end
			require(script.Parent.StationService):Remove(inst)
			require(script.Parent.UtilityBuildService):Remove(inst)
			GridService:ReleaseByInstance(inst)
			self._entries[inst] = nil
			inst:Destroy()
			removed += 1
		end
	end
	return removed
end

function BuildService:Bind()
	if self._bound then return end
	if not self._remoteBuild then
		warn("[BuildService] Missing build remote:", Config.RemoteNames.Build)
		return
	end
	self._bound = true
	Players.PlayerRemoving:Connect(function(plr) self._salvageHolds[plr], self._requests[plr] = nil, nil end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		for plr, hold in pairs(self._salvageHolds) do
			if plr.Parent ~= Players or plr.Character ~= hold.Character or os.clock() - hold.LastPulse > 0.6
				or not salvageTarget(plr, hold.Target) then self._salvageHolds[plr] = nil end
		end
	end)
	self._remoteBuild.OnServerEvent:Connect(function(plr, action, payload)
		if action ~= "Place" and action ~= "Remove" and action ~= "PickBlock" and action ~= "BeginSalvage" and action ~= "ContinueSalvage" and action ~= "CancelSalvage" then return end
		if action == "CancelSalvage" then self._salvageHolds[plr] = nil; return end
		local requests, now = self._requests[plr] or {}, os.clock()
		self._requests[plr] = requests
		if now - (requests[action] or -math.huge) < 0.1 then return end
		requests[action] = now
		if type(payload) ~= "table" then
			self._salvageHolds[plr] = nil
			self._remoteBuild:FireClient(plr, "Result", { Action = action, Success = false, Reason = "InvalidPayload" })
			return
		end
		if action == "BeginSalvage" then
			local started, reason = self:_beginSalvage(plr, payload.Target)
			if not started then self._remoteBuild:FireClient(plr, "Result", { Action = "Remove", Success = false, Reason = reason }) end
		elseif action == "ContinueSalvage" then
			self:_continueSalvage(plr, payload.Target)
		elseif action == "Place" then
			self._salvageHolds[plr] = nil
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
				return BuildService:Place(plr, buildType, pos, payload.Rotation)
			end)
			local success = ok and placed == true
			self._remoteBuild:FireClient(plr, "Result", {
				Action = "Place",
				Success = success,
				Reason = success and (reason or "Success") or (ok and (reason or "Unknown") or "Unknown"),
			})
		elseif action == "PickBlock" then
			local ok, picked, reason, slotIndex, buildType = pcall(function()
				return BuildService:PickBlock(plr, payload.Target)
			end)
			local success = ok and picked == true
			self._remoteBuild:FireClient(plr, "Result", {
				Action = "PickBlock", Success = success,
				Reason = success and (reason or "Success") or (ok and (reason or "Unknown") or "Unknown"),
				SlotIndex = slotIndex, BuildType = buildType,
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
			local ok, removed, reason, refunded = pcall(function()
				return BuildService:Remove(plr, target)
			end)
			local success = ok and removed == true
			self._remoteBuild:FireClient(plr, "Result", {
				Action = "Remove",
				Success = success,
				Reason = success and (reason or "Success") or (ok and (reason or "Unknown") or "Unknown"),
				Refunded = refunded == true,
			})
		end
	end)
end

return BuildService
