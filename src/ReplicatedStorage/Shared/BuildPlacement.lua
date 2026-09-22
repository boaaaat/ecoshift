local Players = game:GetService("Players")
local Config = require(script.Parent.Config)
local Placement = {}
local EDGE_TYPES = {Wall = true, Door = true, Gate = true}

local function snap(value, spacing, offset)
	offset = offset or 0
	return math.floor((value - offset) / spacing + .5) * spacing + offset
end

-- Full-size structures use tile centers. Thin wall modules use the nearest
-- tile boundary so they can share a tile with its floor without intersecting it.
function Placement.Snap(position, buildType, rotation)
	local size = Config.GRID.Size
	local xOffset, zOffset = 0, 0
	if EDGE_TYPES[buildType] then
		if (rotation or 0) % 180 == 0 then zOffset = size * .5 else xOffset = size * .5 end
	end
	return Vector3.new(snap(position.X, size, xOffset), position.Y, snap(position.Z, size, zOffset))
end

function Placement.WithinCamp(position)
	local radius = Config.BUILD.CampRadius
	return position.X * position.X + position.Z * position.Z <= radius * radius
end

-- Positions represent the supporting surface, shared by previews and placed builds.
function Placement.Surface(position, ignored, buildType, rotation)
	local size = Config.GRID.Size
	local snapped = Placement.Snap(position, buildType, rotation)
	local x, z = snapped.X, snapped.Z
	local exclude = table.clone(ignored or {})
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, position.Y + size, z), Vector3.new(0, -size * 3, 0), params)
	if not hit or hit.Normal.Y < .5 then return nil end
	return Vector3.new(x, hit.Position.Y, z)
end

function Placement.Bottom(instance)
	local cf, size
	if instance:IsA("Model") then cf, size = instance:GetBoundingBox()
	else cf, size = instance.CFrame, instance.Size end
	local halfHeight = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z) * .5
	return cf.Position.Y - halfHeight
end

function Placement.PutOnSurface(instance, cf)
	instance:PivotTo(cf)
	instance:PivotTo(instance:GetPivot() + Vector3.new(0, cf.Position.Y - Placement.Bottom(instance), 0))
end

return Placement
