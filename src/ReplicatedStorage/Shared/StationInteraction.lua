local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WorkbenchConfig = require(script.Parent.WorkbenchConfig)

local StationInteraction = {}
StationInteraction.Range = 15
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local filteredCharacter

local CHEST_TAGS = { "Common_Chest", "Rare_Chest", "Legendary_Chest", "Celestial_Chest" }

local function isChest(instance)
	for _, tag in ipairs(CHEST_TAGS) do
		if CollectionService:HasTag(instance, tag) then return true end
	end
	return false
end

local function interactionFromInstance(instance)
	local node = instance
	while node and node ~= Workspace do
		if isChest(node) then return node, nil, "Chest" end
		local stationType = node:GetAttribute("StationType")
		if stationType and WorkbenchConfig.STATIONS[stationType]
			and CollectionService:HasTag(node, "CraftingStation") then
			return node, stationType, "Station"
		end
		node = node.Parent
	end
	return nil, nil, nil
end

local function inRange(player, target, stationType)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local targetPosition
	if target:IsA("Model") then
		targetPosition = target:GetPivot().Position
	elseif target:IsA("BasePart") then
		targetPosition = target.Position
	end
	if not targetPosition then return false end

	local stationDef = WorkbenchConfig.STATIONS[stationType]
	local radius = stationDef and stationDef.InteractRadius or StationInteraction.Range
	return (root.Position - targetPosition).Magnitude <= radius
end

function StationInteraction.FromRay(player, ray)
	if not player or not ray then return nil, nil, nil end
	if player.Character ~= filteredCharacter then
		filteredCharacter = player.Character
		raycastParams.FilterDescendantsInstances = filteredCharacter and { filteredCharacter } or {}
	end

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 256, raycastParams)
	local target, stationType, interactionType = interactionFromInstance(result and result.Instance)
	if not target or not inRange(player, target, stationType) then return nil, nil, nil end
	return target, stationType, interactionType
end

function StationInteraction.FromMouse(player)
	return StationInteraction.FromRay(player, player:GetMouse().UnitRay)
end

function StationInteraction.FromScreenPoint(player, point)
	local camera = Workspace.CurrentCamera
	if not camera then return nil, nil, nil end
	point = point or camera.ViewportSize * 0.5
	return StationInteraction.FromRay(player, camera:ViewportPointToRay(point.X, point.Y))
end

return StationInteraction
