-- Authored detail culling only. Silhouettes, collisions and interactions stay intact.
-- Mesh normals and RenderFidelity are authored in Studio; RenderFidelity is protected
-- from client writes. This setting does not change Roblox's engine graphics slider.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientSettings"))

local distances = { Low = 60, Medium = 130, High = 260, Ultra = 450 }
local details = {}
local quality, shadows
local elapsed = 0

local function equipped(part)
	local ancestor = part.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Tool") then
			local character = ancestor.Parent
			return character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid") ~= nil
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function apply(part, state, cameraPosition)
	-- A producer must opt in only non-interactive surface detail, never a collider.
	local visible = true
	if not part.CanCollide and not equipped(part) and cameraPosition then
		local radius = distances[quality] * state.DistanceScale
		-- Hysteresis avoids detail flickering when the camera sits at the boundary.
		if state.Visible then radius += 12 end
		visible = (part.Position - cameraPosition).Magnitude <= radius
	end
	state.Visible = visible
	part.LocalTransparencyModifier = visible and state.Transparency or 1
	part.CastShadow = visible and shadows and quality ~= "Low" and state.Shadow
end

local function refresh()
	local camera = workspace.CurrentCamera
	local position = camera and camera.CFrame.Position
	for part, state in pairs(details) do apply(part, state, position) end
end

local function register(part)
	if not part:IsA("BasePart") or details[part] or not part:IsDescendantOf(workspace) then return end
	local detail = part:GetAttribute("ArtDetail")
	if detail ~= true and type(detail) ~= "number" then return end
	local state = {
		Transparency = part.LocalTransparencyModifier,
		Shadow = part.CastShadow,
		DistanceScale = type(detail) == "number" and math.clamp(detail, .25, 2) or 1,
		Visible = true,
	}
	details[part] = state
	local camera = workspace.CurrentCamera
	apply(part, state, camera and camera.CFrame.Position)
end

local function unregister(part)
	local state = details[part]
	if not state then return end
	details[part] = nil
	part.LocalTransparencyModifier = state.Transparency
	part.CastShadow = state.Shadow
end

local function settingsChanged(key)
	if key and key ~= "GraphicsQuality" and key ~= "Shadows" then return end
	quality = Settings.Get("GraphicsQuality")
	shadows = Settings.Get("Shadows") == true
	refresh()
end

settingsChanged()
Settings.Changed:Connect(settingsChanged)
-- Defer registration so synchronous model construction can assign its art metadata.
workspace.DescendantAdded:Connect(function(part) task.defer(register, part) end)
workspace.DescendantRemoving:Connect(unregister)
for _, part in ipairs(workspace:GetDescendants()) do register(part) end
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < .35 then return end
	elapsed = 0
	refresh()
end)
