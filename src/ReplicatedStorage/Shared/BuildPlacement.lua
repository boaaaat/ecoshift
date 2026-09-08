local Players = game:GetService("Players")
local Config = require(script.Parent.Config)
local Placement = {}

function Placement.WithinCamp(position)
	local radius = Config.BUILD.CampRadius
	return position.X * position.X + position.Z * position.Z <= radius * radius
end

-- Positions represent the supporting surface, never a preview cube's center.
function Placement.Surface(position, ignored)
	local size = Config.GRID.Size
	local x = math.floor(position.X / size + .5) * size
	local z = math.floor(position.Z / size + .5) * size
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
