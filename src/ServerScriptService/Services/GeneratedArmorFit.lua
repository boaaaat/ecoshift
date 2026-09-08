-- Roblox scales an Accessory's Handle. Our welded decorative parts must follow it.
local Fit = {}

function Fit.Bind(accessory)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end
	local originalSize = handle.Size
	local parts, joints = {}, {}
	for _, object in ipairs(accessory:GetDescendants()) do
		if object:IsA("BasePart") and object ~= handle then
			table.insert(parts, { Part = object, Size = object.Size, Offset = handle.CFrame:ToObjectSpace(object.CFrame) })
		elseif object:IsA("WeldConstraint") then
			table.insert(joints, object)
		end
	end
	local alive, queued = true, false
	local function refresh()
		queued = false
		if not alive or not handle.Parent then return end
		local scale = handle.Size / originalSize
		local enabled = {}
		for _, joint in ipairs(joints) do
			if joint.Parent then enabled[joint] = joint.Enabled; joint.Enabled = false end
		end
		for _, record in ipairs(parts) do
			local part, offset = record.Part, record.Offset
			if part.Parent then
				-- Project axis scaling onto each rotated part's local axes. This keeps
				-- angled straps proportional without accumulating scale on re-equip.
				local axes = Vector3.new((offset.RightVector * scale).Magnitude,
					(offset.UpVector * scale).Magnitude, (offset.LookVector * scale).Magnitude)
				part.Size = record.Size * axes
				part.CFrame = handle.CFrame * CFrame.new(offset.Position * scale) * offset.Rotation
			end
		end
		for joint, wasEnabled in pairs(enabled) do if joint.Parent then joint.Enabled = wasEnabled end end
	end
	local connection = handle:GetPropertyChangedSignal("Size"):Connect(function()
		if queued or not alive then return end
		queued = true
		task.defer(refresh)
	end)
	return function()
		alive = false
		connection:Disconnect()
	end
end

return Fit
