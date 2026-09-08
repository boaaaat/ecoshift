-- Check the final, scaled prefab footprint rather than just its placement pivot.
-- A world-axis bounding rectangle is conservative for rotated decoration and
-- includes off-center model pivots, overhangs, and nested chest sockets.
local CenterClearance = {}

function CenterClearance.Overlaps(instance, radius)
	if radius <= 0 then return false end
	local cf, size
	if instance:IsA("Model") then
		cf, size = instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		cf, size = instance.CFrame, instance.Size
	else
		for _, child in ipairs(instance:GetChildren()) do
			if CenterClearance.Overlaps(child, radius) then return true end
		end
		return false
	end
	local half = size * 0.5
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	local halfX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
	local halfZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	local nearestX = math.max(0, math.abs(cf.Position.X) - halfX)
	local nearestZ = math.max(0, math.abs(cf.Position.Z) - halfZ)
	return nearestX * nearestX + nearestZ * nearestZ <= radius * radius
end

return CenterClearance
