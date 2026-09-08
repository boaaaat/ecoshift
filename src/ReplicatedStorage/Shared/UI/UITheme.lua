-- EcoShift's expedition field kit: charcoal cases, paper records, amber instruments.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Theme = {}
local common = {
	Accent = Color3.fromRGB(65, 97, 59),
	Paper = Color3.fromRGB(245, 239, 218), Moss = Color3.fromRGB(67, 88, 55),
	Amber = Color3.fromRGB(226, 177, 82), Night = Color3.fromRGB(22, 31, 27),
	Sage = Color3.fromRGB(170, 185, 143), Cold = Color3.fromRGB(129, 179, 189),
	ValidPlacement = Color3.fromRGB(114, 173, 93), InvalidPlacement = Color3.fromRGB(205, 85, 64),
	SuccessFill = Color3.fromRGB(70, 107, 57), DangerFill = Color3.fromRGB(170, 65, 48),
}
local palettes = {
	Dark = {
		Background = Color3.fromRGB(25, 33, 29), Panel = Color3.fromRGB(34, 43, 37),
		SlotEmpty = Color3.fromRGB(40, 49, 41), SlotFilled = Color3.fromRGB(47, 57, 46),
		SlotHover = Color3.fromRGB(59, 73, 53), SlotSelected = Color3.fromRGB(73, 91, 60),
		Border = Color3.fromRGB(94, 108, 80), Text = Color3.fromRGB(235, 233, 211),
		TextMuted = Color3.fromRGB(167, 180, 149), Success = Color3.fromRGB(167, 204, 126),
		Warning = Color3.fromRGB(231, 185, 105), Danger = Color3.fromRGB(246, 143, 119),
		Tier1 = Color3.fromRGB(176, 186, 152), Tier2 = Color3.fromRGB(135, 195, 194),
		Tier3 = Color3.fromRGB(230, 181, 101), Special = Color3.fromRGB(204, 169, 211),
	},
	Light = {
		Background = Color3.fromRGB(224, 217, 195), Panel = Color3.fromRGB(244, 238, 216),
		SlotEmpty = Color3.fromRGB(226, 223, 204), SlotFilled = Color3.fromRGB(235, 231, 209),
		SlotHover = Color3.fromRGB(218, 225, 194), SlotSelected = Color3.fromRGB(191, 209, 161),
		Border = Color3.fromRGB(163, 166, 133), Text = Color3.fromRGB(37, 53, 39),
		TextMuted = Color3.fromRGB(98, 107, 83),
		Success = Color3.fromRGB(69, 108, 58), Warning = Color3.fromRGB(156, 97, 33),
		Danger = Color3.fromRGB(171, 66, 49), Tier1 = Color3.fromRGB(101, 111, 86),
		Tier2 = Color3.fromRGB(67, 109, 109), Tier3 = Color3.fromRGB(159, 109, 42),
		Special = Color3.fromRGB(120, 87, 128),
	},
}
for _, palette in pairs(palettes) do
	for key, value in pairs(common) do palette[key] = value end
end

local player = Players.LocalPlayer
Theme.Mode = player and player:GetAttribute("UITheme") == "Light" and "Light" or "Dark"
-- Never replace this table: existing inventory and crafting controllers retain it.
Theme.Colors = table.clone(palettes[Theme.Mode])
local changed = Instance.new("BindableEvent")
Theme.Changed = changed.Event
local roots = setmetatable({}, { __mode = "k" })
local bindings = setmetatable({}, { __mode = "k" })
local revision = 0

local function colorProperties(object)
	if object:IsA("UIStroke") then return { "Color" } end
	if not object:IsA("GuiObject") then return {} end
	local properties = { "BackgroundColor3", "BorderColor3" }
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		table.insert(properties, "TextColor3")
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then table.insert(properties, "ImageColor3") end
	if object:IsA("ScrollingFrame") then table.insert(properties, "ScrollBarImageColor3") end
	return properties
end

-- Old controllers assign palette colors directly. Adapt their existing controls
-- in place, preserving selected recipes, drag state, text input and scroll offsets.
-- Fixed illustration previews can opt out with a ThemeFixed attribute.
local function recolor(object, previous)
	if object:GetAttribute("ThemeFixed") then return end
	local explicit = bindings[object]
	for _, property in ipairs(colorProperties(object)) do
		local token = explicit and explicit[property]
		if token then
			object[property] = Theme.Colors[token]
		else
			local current = object[property]
			for key, color in pairs(previous) do
				if current == color and color ~= Theme.Colors[key] then
					object[property] = Theme.Colors[key]
					break
				end
			end
		end
	end
	for _, child in ipairs(object:GetChildren()) do recolor(child, previous) end
end

function Theme.TrackRoot(root)
	roots[root] = true
end

-- Prefer explicit tokens in new UI; legacy direct assignments remain supported.
function Theme.Bind(object, property, token)
	assert(Theme.Colors[token], "Unknown EcoShift theme token: " .. tostring(token))
	bindings[object] = bindings[object] or {}
	bindings[object][property] = token
	object[property] = Theme.Colors[token]
	return object
end

function Theme.SetMode(mode)
	mode = mode == "Light" and "Light" or "Dark"
	if Theme.Mode == mode then return end
	local previous = table.clone(Theme.Colors)
	Theme.Mode = mode
	for key, value in pairs(palettes[mode]) do Theme.Colors[key] = value end
	revision += 1
	local currentRevision = revision
	for root in pairs(roots) do recolor(root, previous) end
	changed:Fire(mode)
	-- An in-flight hover tween may finish with its old endpoint after this switch.
	task.delay(0.35, function()
		if revision ~= currentRevision then return end
		for root in pairs(roots) do recolor(root, previous) end
	end)
end

function Theme.Palette(mode)
	return table.clone(palettes[mode == "Light" and "Light" or "Dark"])
end

function Theme.Tween(object, properties, duration)
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

function Theme.Corner(object, radius)
	local corner = object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = object
	return corner
end

function Theme.Panel(frame, dark)
	local c = Theme.Colors
	frame.BackgroundColor3 = dark and c.Night or c.Panel
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	Theme.Corner(frame, 10)
	local stroke = frame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = dark and c.Moss or c.Border
	stroke.Transparency = 0.2
	stroke.Thickness = 1
	stroke.Parent = frame
	local gradient = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(233, 236, 221))
	gradient.Rotation = 90
	gradient.Parent = frame
	if not frame:FindFirstChild("FieldTab") then
		local tab = Instance.new("Frame")
		tab.Name = "FieldTab"
		tab.Size = UDim2.fromOffset(38, 3)
		tab.Position = UDim2.fromOffset(16, 0)
		tab.BackgroundColor3 = c.Amber
		tab.BorderSizePixel = 0
		tab.ZIndex = frame.ZIndex + 1
		tab.Parent = frame
	end
	return frame
end

function Theme.Label(parent, text, size, position, textSize, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Text = text
	label.TextSize = textSize or 12
	label.TextColor3 = color or Theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = parent.ZIndex + 1
	label.Parent = parent
	return label
end

function Theme.Button(button, primary)
	if button:GetAttribute("FieldButton") then return button end
	button:SetAttribute("FieldButton", true)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	if primary ~= nil then
		button.BackgroundColor3 = primary and Theme.Colors.Moss or Theme.Colors.SlotEmpty
		if button:IsA("TextButton") then button.TextColor3 = primary and Theme.Colors.Paper or Theme.Colors.Text end
	end
	Theme.Corner(button, 6)
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonMotion"
	scale.Parent = button
	button.MouseEnter:Connect(function() Theme.Tween(scale, { Scale = 1.025 }, 0.12) end)
	button.MouseLeave:Connect(function() Theme.Tween(scale, { Scale = 1 }, 0.15) end)
	button.MouseButton1Down:Connect(function() Theme.Tween(scale, { Scale = 0.96 }, 0.08) end)
	button.MouseButton1Up:Connect(function() Theme.Tween(scale, { Scale = 1 }, 0.12) end)
	return button
end

-- Keep fixed design dimensions readable without letting panels leave small viewports.
function Theme.Fit(frame, width, height, maximum, scaleEdgeOffsets)
	local designPosition = frame.Position
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = frame
	local cameraConnection
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		-- Scale the field kit with desktop resolution, including 1440p/4K.
		-- Small screens still fit within their available width and height.
		local desktopScale = math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 1, 2.5)
		scale.Scale = math.min(maximum or desktopScale, math.max(0.1, (viewport.X - 40) / width), math.max(0.1, (viewport.Y - 90) / height))
		scale:SetAttribute("TargetScale", scale.Scale)
		if scaleEdgeOffsets then
			frame.Position = UDim2.new(designPosition.X.Scale, designPosition.X.Offset * scale.Scale,
				designPosition.Y.Scale, designPosition.Y.Offset * scale.Scale)
		end
	end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if Workspace.CurrentCamera then
			cameraConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	local changed = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	frame.Destroying:Connect(function()
		changed:Disconnect()
		if cameraConnection then cameraConnection:Disconnect() end
	end)
	bindCamera()
	return scale
end

function Theme.AnimatePanel(frame)
	local scale = frame:FindFirstChild("ViewportScale") or Instance.new("UIScale")
	if not scale.Parent then scale.Name = "PanelMotion"; scale.Parent = frame end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			local target = scale:GetAttribute("TargetScale") or scale.Scale
			scale.Scale = target * 0.96
			Theme.Tween(scale, { Scale = target }, 0.24)
		end
	end)
end

return Theme
