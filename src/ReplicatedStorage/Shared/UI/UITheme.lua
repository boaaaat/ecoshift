-- EcoShift's expedition field kit: paper records, moss cases, amber instruments.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = {}
Theme.Colors = {
	Background = Color3.fromRGB(224, 217, 195), Panel = Color3.fromRGB(245, 239, 218),
	SlotEmpty = Color3.fromRGB(226, 223, 204), SlotFilled = Color3.fromRGB(235, 231, 209),
	SlotHover = Color3.fromRGB(218, 225, 194), SlotSelected = Color3.fromRGB(191, 209, 161),
	Border = Color3.fromRGB(163, 166, 133), Text = Color3.fromRGB(37, 53, 39),
	TextMuted = Color3.fromRGB(98, 107, 83), Accent = Color3.fromRGB(65, 97, 59),
	Success = Color3.fromRGB(69, 108, 58), Warning = Color3.fromRGB(156, 97, 33),
	Danger = Color3.fromRGB(171, 66, 49), Paper = Color3.fromRGB(245, 239, 218),
	Moss = Color3.fromRGB(67, 88, 55), Amber = Color3.fromRGB(226, 177, 82),
	Night = Color3.fromRGB(29, 43, 34), Sage = Color3.fromRGB(170, 185, 143),
	Cold = Color3.fromRGB(129, 179, 189), ValidPlacement = Color3.fromRGB(114, 173, 93),
	InvalidPlacement = Color3.fromRGB(205, 85, 64), Tier1 = Color3.fromRGB(101, 111, 86),
	Tier2 = Color3.fromRGB(67, 109, 109), Tier3 = Color3.fromRGB(159, 109, 42),
	Special = Color3.fromRGB(120, 87, 128),
}

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
		button.TextColor3 = primary and Theme.Colors.Paper or Theme.Colors.Text
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
function Theme.Fit(frame, width, height, maximum)
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = frame
	local cameraConnection
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		scale.Scale = math.min(maximum or 1, math.max(0.35, (viewport.X - 40) / width), math.max(0.35, (viewport.Y - 90) / height))
		scale:SetAttribute("TargetScale", scale.Scale)
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
