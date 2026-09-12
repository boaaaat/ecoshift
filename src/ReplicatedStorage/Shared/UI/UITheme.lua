-- EcoShift's expedition field kit: charcoal cases, paper records, amber instruments.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = {}
function Theme.IsMobile()
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

-- Observe the usable ScreenGui area, including device notches and Roblox insets.
function Theme.BindResponsive(root, callback)
	local connections, cameraConnection = {}, nil
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local gui = root:IsA("ScreenGui") and root or root:FindFirstAncestorOfClass("ScreenGui")
		local size = gui and gui.AbsoluteSize or camera.ViewportSize
		if size.X <= 1 or size.Y <= 1 then return end
		callback(Theme.IsMobile(), size)
	end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if Workspace.CurrentCamera then cameraConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
		update()
	end
	table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(connections, UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(update))
	local gui = root:IsA("ScreenGui") and root or root:FindFirstAncestorOfClass("ScreenGui")
	if gui then table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)) end
	root.Destroying:Connect(function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if cameraConnection then cameraConnection:Disconnect() end
	end)
	bindCamera()
	return update
end
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
	local seconds = player and player:GetAttribute("ReducedMotion") and 0 or (duration or 0.18)
	local tween = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
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
	label.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 1
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

-- Mobile menus keep readable native text and scroll instead of shrinking to
-- fit a short landscape screen. Desktop keeps its original centered layout.
function Theme.FitMenu(frame, width, height, options)
	options = options or {}
	local parent, position, anchor, size = frame.Parent, frame.Position, frame.AnchorPoint, frame.Size
	local scale = frame:FindFirstChild("ViewportScale") or frame:FindFirstChild("PanelMotion") or Instance.new("UIScale")
	scale.Name, scale.Parent = "ViewportScale", frame
	local host = Instance.new("ScrollingFrame")
	host.Name = frame.Name .. "MobileViewport"
	host.Position, host.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16)
	host.BackgroundTransparency, host.BorderSizePixel = 1, 0
	host.ScrollBarThickness = 6
	host.ScrollingDirection, host.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.WhenScrollable
	host.ZIndex, host.Visible, host.Parent = frame.ZIndex, false, parent
	local close = Instance.new("TextButton")
	close.Name, close.Text = frame.Name .. "MobileClose", "×"
	close.Size, close.AnchorPoint = UDim2.fromOffset(44, 44), Vector2.new(1, 0)
	close.Position, close.TextSize, close.Font = UDim2.new(1, -16, 0, 12), 26, Enum.Font.GothamBold
	close.ZIndex, close.Visible, close.Parent = frame.ZIndex + 50, false, parent
	Theme.Button(close, false)
	close.Activated:Connect(function()
		if options.OnClose then options.OnClose() else frame.Visible = false end
	end)
	local mobile = false
	local geometry = setmetatable({}, {__mode="k"})
	local lastLayout
	local function rememberGeometry()
		for _, object in ipairs(frame:GetDescendants()) do
			if object:IsA("GuiObject") then
				local record={Position=object.Position,Size=object.Size,AnchorPoint=object.AnchorPoint}
				if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
					record.TextSize,record.TextWrapped,record.TextTruncate=object.TextSize,object.TextWrapped,object.TextTruncate
					record.TextXAlignment,record.TextYAlignment=object.TextXAlignment,object.TextYAlignment
				end
				geometry[object]=record
			end
		end
	end
	local function restoreGeometry()
		for object, record in pairs(geometry) do
			if object.Parent then for property, value in pairs(record) do object[property]=value end end
		end
		table.clear(geometry)
	end
	local function visibility()
		host.Visible, close.Visible = mobile and frame.Visible, mobile and frame.Visible and not options.HideClose
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(visibility)
	Theme.BindResponsive(frame, function(touch, available)
		if touch and not mobile then rememberGeometry() elseif mobile and not touch then restoreGeometry() end
		mobile = touch
		if touch then
			local availableWidth = math.max(1, available.X - 16)
			local contentWidth = math.max(options.MobileWidth or math.min(width, 360), availableWidth)
			local factor = math.min(1, availableWidth / contentWidth)
			local contentHeight = math.max(options.MobileHeight or height, (available.Y - 16) / factor)
			frame.Parent, frame.AnchorPoint, frame.Position = host, Vector2.zero, UDim2.fromOffset(0, 0)
			frame.Size = UDim2.fromOffset(contentWidth, contentHeight)
			scale.Scale = factor
			host.CanvasSize = UDim2.fromOffset(0, contentHeight * factor)
			local layout="touch:" .. contentWidth .. ":" .. contentHeight
			if options.OnResize and layout~=lastLayout then options.OnResize(contentWidth, contentHeight, true) end
			lastLayout=layout
		else
			frame.Parent, frame.AnchorPoint, frame.Position, frame.Size = parent, anchor, position, size
			local factor = math.clamp(math.min(available.X / 1280, available.Y / 800), 1.1, 2.5)
			scale.Scale = math.min(factor, math.max(.1, (available.X - 32) / width), math.max(.1, (available.Y - 24) / height))
			if options.OnResize and lastLayout~="desktop" then options.OnResize(width, height, false) end
			lastLayout="desktop"
		end
		scale:SetAttribute("TargetScale", scale.Scale)
		visibility()
	end)
	frame.Destroying:Connect(function() close:Destroy(); task.defer(function() host:Destroy() end) end)
	return scale
end

function Theme.CaptureCursor(frame)
	require(script.Parent.MenuCursor).Bind(frame)
end

-- Small, resolution-independent expedition glyphs. No font/asset loading dependency.
function Theme.Icon(parent, kind, size)
	local old=parent:FindFirstChild("Glyph")
	if old then old:Destroy() end
	local paths={
		Leaf={{{4,20},{4,10},{9,4},{21,3},{20,14},{14,20},{4,20}},{{4,20},{16,8}},{{8,15},{8,9}},{{12,12},{18,12}}},
		Mineral={{{5,8},{10,2},{16,3},{21,10},{17,21},{7,22},{3,15},{5,8}},{{10,2},{9,13},{7,22}},{{16,3},{15,13},{17,21}},{{9,13},{15,13},{21,10}}},
		Pack={{{7,6},{7,3},{17,3},{17,6}},{{5,6},{19,6},{20,21},{4,21},{5,6}},{{7,13},{17,13},{17,18},{7,18},{7,13}}},
		Craft={{{5,4},{20,19}},{{3,7},{8,2},{12,6},{7,11},{3,7}},{{4,20},{18,6}},{{16,3},{21,3},{21,8}}},
		Build={{{3,11},{12,3},{21,11}},{{6,10},{6,21},{18,21},{18,10}},{{10,21},{10,14},{14,14},{14,21}}},
		Survey={{{12,2},{21,12},{12,22},{3,12},{12,2}},{{15,8},{13,14},{9,16},{11,10},{15,8}}},
		Crew={{{8,4},{11,6},{11,9},{8,11},{5,9},{5,6},{8,4}},{{3,21},{3,16},{8,13},{13,16},{13,21}},{{16,5},{19,7},{19,10},{16,12}},{{17,14},{21,17},{21,21}}},
		Sprint={{{14,3},{16,3},{16,5},{14,5},{14,3}},{{5,9},{10,8},{15,11},{19,10}},{{13,7},{10,14},{15,17},{13,22}},{{10,14},{7,18},{2,18}}},
		Harvest={{{5,21},{17,5}},{{8,5},{13,3},{18,5},{21,10}}},
		Attack={{{5,21},{19,3},{21,3},{21,6},{6,21}},{{3,14},{11,21}}},
		Bow={{{6,3},{14,7},{17,12},{14,17},{6,21},{6,3}},{{3,12},{22,12}},{{18,8},{22,12},{18,16}}},
		Shield={{{12,2},{21,6},{19,16},{12,22},{5,16},{3,6},{12,2}},{{12,7},{12,16}}},
		Armor={{{12,2},{21,6},{19,16},{12,22},{5,16},{3,6},{12,2}}},
		Health={{{12,21},{3,12},{3,7},{7,4},{12,8},{17,4},{21,7},{21,12},{12,21}}},
		Energy={{{14,2},{5,14},{11,14},{9,22},{20,9},{13,9},{14,2}}},
		Food={{{5,19},{5,9},{9,4},{18,3},{21,7},{20,14},{16,19},{5,19}},{{5,19},{16,8}}},
		Exposure={{{10,14},{10,4},{12,2},{14,4},{14,14},{17,17},{17,20},{14,23},{10,23},{7,20},{7,17},{10,14}},{{12,8},{12,18}}},
		Chevron={{{8,5},{15,12},{8,19}}},
		Close={{{5,5},{19,19}},{{19,5},{5,19}}},
		Rotate={{{5,8},{9,3},{17,4},{21,10},{19,17},{12,21},{5,18}},{{5,3},{5,8},{10,8}}},
		Place={{{3,12},{9,19},{21,5}}},
	}
	local root=Instance.new("Frame");root.Name="Glyph";root.BackgroundTransparency=1
	root.Size=UDim2.fromOffset(size or 24,size or 24);root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5)
	root.ZIndex=parent:IsA("GuiObject") and parent.ZIndex+1 or 1;root.Parent=parent
	root:SetAttribute("IconKind",kind)
	for _,points in ipairs(paths[kind] or paths.Survey) do
		for i=2,#points do
			local a,b=Vector2.new(unpack(points[i-1])),Vector2.new(unpack(points[i]));local delta=b-a
			local line=Instance.new("Frame");line.BorderSizePixel=0;line.AnchorPoint=Vector2.new(.5,.5)
			line.Size=UDim2.new(delta.Magnitude/24,1,0,1.7);line.Position=UDim2.fromScale((a.X+b.X)/48,(a.Y+b.Y)/48)
			line.Rotation=math.deg(math.atan2(delta.Y,delta.X));line.BackgroundTransparency=.12;line.ZIndex=root.ZIndex;line.Parent=root
			Theme.Bind(line,"BackgroundColor3","Paper");Theme.Corner(line,2)
		end
	end
	return root
end

function Theme.TouchIcon(button,kind,size)
	button.Text="";button:SetAttribute("ActionLabel",kind)
	local glyph=Theme.Icon(button,kind,size or 24)
	button.BackgroundTransparency=.48
	local stroke=button:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Thickness=1;stroke.Transparency=.6;stroke.Parent=button;Theme.Bind(stroke,"Color","Sage")
	button.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch then Theme.Tween(button,{BackgroundTransparency=.15},.1);Theme.Bind(stroke,"Color","Amber") end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch then Theme.Tween(button,{BackgroundTransparency=.48},.2);Theme.Bind(stroke,"Color","Sage") end
	end)
	return glyph
end

function Theme.AnimatePanel(frame)
	local scale = frame:FindFirstChild("ViewportScale") or frame:FindFirstChild("PanelMotion") or Instance.new("UIScale")
	if not scale.Parent then scale.Name = "PanelMotion"; scale.Parent = frame end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible and not (player and player:GetAttribute("ReducedMotion")) then
			local target = scale:GetAttribute("TargetScale") or scale.Scale
			scale.Scale = target * 0.96
			Theme.Tween(scale, { Scale = target }, 0.24)
		end
	end)
end

return Theme
