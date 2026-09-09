-- BuildService.lua
-- Server-authoritative grid placement with costs and workbench support
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local WorkbenchConfig = require(ReplicatedStorage.Shared.WorkbenchConfig)
local BuildPlacement = require(ReplicatedStorage.Shared:WaitForChild("BuildPlacement"))
local GridService = require(script.Parent.GridService)
local InventoryService = require(script.Parent.InventoryService)
local LootService = require(script.Parent.LootService)
local GameStateService = require(script.Parent.GameStateService)
local ItemDropService = require(script.Parent.ItemDropService)

local BuildService = {}
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
	if buildType == "Torch" then
		local model = Instance.new("Model")
		model.Name = "Build_" .. buildType
		model:SetAttribute("BuildType", buildType)

		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(0.5, 3.5, 0.5)
		post.Anchored = true
		post.CanCollide = true
		post.Material = Enum.Material.Wood
		post.Color = Color3.fromRGB(94, 70, 44)
		post.Parent = model

		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Shape = Enum.PartType.Ball
		flame.Size = Vector3.new(0.8, 0.8, 0.8)
		flame.Anchored = true
		flame.CanCollide = false
		flame.Material = Enum.Material.Neon
		flame.Color = Color3.fromRGB(255, 186, 80)
		flame.Parent = model

		local light = Instance.new("PointLight")
		light.Name = "TorchLight"
		light.Brightness = 2
		light.Range = 16
		light.Color = Color3.fromRGB(255, 214, 138)
		light.Shadows = true
		light.Parent = flame

		model.PrimaryPart = post
		post.CFrame = CFrame.new(position + Vector3.new(0, post.Size.Y * 0.5, 0))
		flame.CFrame = CFrame.new(position + Vector3.new(0, post.Size.Y + flame.Size.Y * 0.3, 0))
		return model
	end

	local part = Instance.new("Part")
	part.Size = Vector3.new(Config.GRID.Size, Config.GRID.Size, Config.GRID.Size)
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
			local added = InventoryService:Give(plr, itemId, amount)
			local remaining = amount - added
			if remaining > 0 and basePos then
				ItemDropService:SpawnDrop(itemId, remaining, basePos + Vector3.new(0, 2, 0))
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
	if not BuildPlacement.WithinCamp(worldPos) then return false, "OutsideCamp" end

	local gx, gz = GridService:WorldToGrid(worldPos)
	if GridService:IsOccupied(gx, gz) then return false, "Occupied" end
	local pos = BuildPlacement.Surface(worldPos)
	if not pos then return false, "NoSurface" end
	if not BuildPlacement.WithinCamp(pos) then return false, "OutsideCamp" end
	if not withinRange(plr, pos) then return false, "OutOfRange" end

	-- Check if this is a placeable item (uses item from inventory)
	local refundEntries = nil
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
		refundEntries = { { Id = buildType, N = 1 } }
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
		refundEntries = adjusted
	end

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
		inst:SetAttribute("PlacementVersion", 1)
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
	return true, "Success"
end

function BuildService:Remove(plr, target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace)
		or (not target:IsA("Model") and not target:IsA("BasePart")) then return false, "InvalidPayload" end
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
			if isChestStructure(inst, state.Type) then state.Chest = LootService:CaptureChestState(inst) end
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
		local prefab = getPrefab(state.Type)
		local inst = prefab and prefab:Clone() or createFallbackPart(state.Type, cf.Position)
		inst:PivotTo(cf)
		if state.PlacementVersion == nil and inst:IsA("Model") and inst:GetAttribute("ArtStyle") == "Expedition" then
			-- Correct only the recognizable old half-grid gap. Grounded or deliberately
			-- elevated saved builds keep their transform; no repeated lowering on resume.
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { workspace.Terrain }
			local bottom = BuildPlacement.Bottom(inst)
			local ground = workspace:Raycast(Vector3.new(cf.X, bottom + .1, cf.Z), Vector3.new(0, -Config.GRID.Size, 0), params)
			if ground and math.abs(bottom - ground.Position.Y - Config.GRID.Size / 2) < .1 then
				inst:PivotTo(cf + Vector3.new(0, ground.Position.Y - bottom, 0))
			end
		end
		inst:SetAttribute("PlacementVersion", 1)
		inst:SetAttribute("OwnerUserId", SnapshotCodec.Number(state.Owner))
		inst:SetAttribute("GridX", gx); inst:SetAttribute("GridZ", gz)
		inst:SetAttribute("BuildType", state.Type)
		inst:SetAttribute("MapMarkerType", "PlayerBuiltStructure")
		inst:SetAttribute("MapMarkerLabel", state.Type)
		applyDurability(inst)
		inst.Durability.Value = SnapshotCodec.Number(state.Durability, 0, 1e6)
		inst:SetAttribute("DurabilityMax", SnapshotCodec.Number(state.DurabilityMax, 1, 1e6))
		if WorkbenchConfig.STATIONS[state.Type] then setupWorkbenchInteraction(inst, state.Type) end
		if state.Chest then LootService:RestoreChestState(inst, state.Chest) end
		table.insert(prepared, inst)
	end
	for _, inst in ipairs(CollectionService:GetTagged("Structure")) do
		if inst:IsDescendantOf(workspace) and inst:GetAttribute("BuildType") then inst:Destroy() end
	end
	GridService:Clear()
	for _, inst in ipairs(prepared) do
		inst.Parent = workspace
		CollectionService:AddTag(inst, "Structure")
		if inst:GetAttribute("BuildType") == "Chest" then setupChestInteraction(inst) end
		assert(GridService:Reserve(inst:GetAttribute("GridX"), inst:GetAttribute("GridZ"), inst:GetAttribute("OwnerUserId"), inst), "Saved structure grid conflict")
	end
end

function BuildService:Bind()
	if self._bound then return end
	if not self._remoteBuild then
		warn("[BuildService] Missing build remote:", Config.RemoteNames.Build)
		return
	end
	self._bound = true
	self._remoteBuild.OnServerEvent:Connect(function(plr, action, payload)
		if type(action) ~= "string" then return end
		if type(payload) ~= "table" then
			self._remoteBuild:FireClient(plr, "Result", { Action = action, Success = false, Reason = "InvalidPayload" })
			return
		end
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
				return BuildService:Place(plr, buildType, pos, payload.Rotation)
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
