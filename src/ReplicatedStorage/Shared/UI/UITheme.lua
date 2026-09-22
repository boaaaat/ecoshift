-- EcoShift's expedition field kit: charcoal cases, paper records, amber instruments.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = {}
function Theme.IsMobile()
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

-- These dimensions are Roblox UI pixels, not the device's physical resolution.
-- Use the ScreenGui's safe area so phones, iPads and rotated tablets agree.
function Theme.MobileMetrics(available)
	local portrait = available.X < available.Y
	local tablet = math.min(available.X, available.Y) >= 600
	local button = tablet and 48 or 44
	local hotbarScale = math.min(tablet and .95 or .8, (available.X - 24) / 422)
	local hotbarBottom = portrait and 104 or 8
	return {
		Portrait = portrait, Tablet = tablet, Button = button, Gap = 8,
		HUDScale = tablet and 1 or .9,
		MapSize = tablet and 136 or (portrait and 108 or 92),
		HotbarScale = hotbarScale, HotbarBottom = hotbarBottom,
		HotbarTop = hotbarBottom + 72 * hotbarScale,
		ActionRight = tablet and 156 or 118,
		ActionBottom = tablet and 48 or 24,
	}
end

-- Pack and chest must compute the same rectangles, including in portrait.
-- Their grids scroll at native size instead of shrinking both inventories.
function Theme.MobileInventoryLayout(available, chestOpen)
	local metrics = Theme.MobileMetrics(available)
	local width = math.min(available.X - 16, metrics.Tablet and 920 or 740)
	local height = math.min(available.Y - metrics.HotbarTop - 20, metrics.Tablet and 600 or 520)
	local left, top = (available.X - width) / 2, 8
	local gap, chestWidth, chestHeight = 12, 0, 0
	local packWidth, packHeight = width, height
	local sideBySide = chestOpen and not metrics.Portrait
	if chestOpen then
		if sideBySide then
			chestWidth = math.floor((width - gap) * .44)
			packWidth, chestHeight = width - gap - chestWidth, height
		else
			chestWidth, chestHeight = width, math.floor((height - gap) * .34)
			packHeight = height - gap - chestHeight
		end
	end
	return {
		PackSize = Vector2.new(packWidth, packHeight),
		PackPosition = Vector2.new(left + (sideBySide and chestWidth + gap or 0), top + (chestOpen and not sideBySide and chestHeight + gap or 0)),
		ChestSize = Vector2.new(chestWidth, chestHeight), ChestPosition = Vector2.new(left, top),
		Cell = metrics.Tablet and 60 or 52,
	}
end

-- A scrolled-off slot is not a valid touch/drop target even if its rectangle
-- extends behind another panel. Points use the same coordinates as AbsolutePosition.
function Theme.IsPointVisible(object, point)
	local current = object
	while current do
		if current:IsA("GuiObject") then
			if not current.Visible then return false end
			if current == object or current.ClipsDescendants then
				local position, size = current.AbsolutePosition, current.AbsoluteSize
				if point.X < position.X or point.Y < position.Y or point.X > position.X + size.X or point.Y > position.Y + size.Y then return false end
			end
		elseif current:IsA("ScreenGui") then return current.Enabled end
		current = current.Parent
	end
	return false
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
		scale.Scale = math.min(Theme.IsMobile() and math.min(maximum or 1, 1) or (maximum or desktopScale), math.max(0.1, (viewport.X - 40) / width), math.max(0.1, (viewport.Y - 90) / height))
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
	local inputChanged = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(update)
	frame.Destroying:Connect(function()
		changed:Disconnect()
		inputChanged:Disconnect()
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
			local metrics = Theme.MobileMetrics(available)
			local contentWidth = math.min(availableWidth, math.max(options.MobileWidth or 360, options.MobileMaxWidth or (metrics.Tablet and 760 or 680)))
			local factor = 1
			local viewportHeight = math.min(available.Y - 16, options.MobileMaxHeight or 760)
			local contentHeight = options.MobileFitHeight and viewportHeight or math.max(options.MobileHeight or height, viewportHeight)
			host.Position = UDim2.fromOffset((available.X - contentWidth) / 2, (available.Y - viewportHeight) / 2)
			host.Size = UDim2.fromOffset(contentWidth, viewportHeight)
			host.ScrollingEnabled = not options.MobileFitHeight
			close.Position = UDim2.fromOffset((available.X + contentWidth) / 2 - 8, (available.Y - viewportHeight) / 2 + 4)
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
	return require(script.Parent.MenuCursor).Bind(frame)
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
		Waypoint={{{12,22},{6,14},{4,10},{4,7},{6,3},{9,1},{12,1},{15,1},{18,3},{20,7},{20,10},{18,14},{12,22}},{{12,5},{15,6},{16,9},{15,12},{12,13},{9,12},{8,9},{9,6},{12,5}}},
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
		Trash={{{4,6},{20,6}},{{9,6},{9,3},{15,3},{15,6}},{{6,7},{7,21},{17,21},{18,7}},{{10,10},{10,17}},{{14,10},{14,17}}},
		Rotate={{{5,8},{9,3},{17,4},{21,10},{19,17},{12,21},{5,18}},{{5,3},{5,8},{10,8}}},
		Place={{{3,12},{9,19},{21,5}}},
		Flame={{{12,2},{13,8},{17,6},{21,13},{20,18},{16,22},{8,22},{4,18},{3,13},{8,7},{8,12},{12,2}},{{12,13},{16,18},{12,21},{9,18},{12,13}}},
		Pot={{{4,10},{20,10},{19,19},{16,22},{8,22},{5,19},{4,10}},{{2,10},{22,10}},{{6,7},{18,7}},{{9,4},{9,2}},{{15,4},{15,2}}},
		Clock={{{12,2},{19,5},{22,12},{19,19},{12,22},{5,19},{2,12},{5,5},{12,2}},{{12,6},{12,12},{16,15}}},
		Collect={{{3,15},{3,21},{21,21},{21,15}},{{12,2},{12,16}},{{7,11},{12,16},{17,11}}},
		Queue={{{4,5},{6,5}},{{10,5},{21,5}},{{4,12},{6,12}},{{10,12},{21,12}},{{4,19},{6,19}},{{10,19},{21,19}}},
		Pause={{{6,3},{9,3},{9,21},{6,21},{6,3}},{{15,3},{18,3},{18,21},{15,21},{15,3}}},
		Play={{{6,3},{21,12},{6,21},{6,3}}},
		Upgrade={{{5,11},{12,4},{19,11}},{{12,4},{12,21}},{{4,21},{20,21}}},
		Search={{{10,3},{15,5},{17,10},{15,15},{10,17},{5,15},{3,10},{5,5},{10,3}},{{15,15},{22,22}}},
		Back={{{14,4},{6,12},{14,20}},{{6,12},{22,12}}},
		Bottle={{{9,2},{15,2},{15,7},{19,12},{19,22},{5,22},{5,12},{9,7},{9,2}},{{5,15},{19,15}}},
		Seasoning={{{8,3},{16,3},{17,7},{7,7},{8,3}},{{7,7},{4,20},{8,22},{16,22},{20,20},{17,7}},{{9,12},{9,14}},{{15,16},{15,18}}},
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

-- Real generated item artwork. Atlases keep the catalog compact; source colors
-- are never tinted by the UI theme. Reuse unchanged art during inventory refresh.
function Theme.ItemIcon(parent, item, size, options)
	options = options or {}
	local name = options.Name or "ItemArt"
	local pixels = size or 40
	local z = options.ZIndex or ((parent:IsA("GuiObject") and parent.ZIndex or 0) + 2)
	local signature = item and table.concat({item.Id or "", item.Icon or "", tostring(item.IconRectOffset),
		tostring(item.IconOverlayRectOffset), item.IconOverlay or "", tostring(item.IconRank or "")}, "|") or ""
	local old = parent:FindFirstChild(name)
	if old and old:GetAttribute("ArtSignature") == signature then
		old.Size = UDim2.fromOffset(pixels, pixels)
		old.ZIndex = z
		for _, child in ipairs(old:GetChildren()) do
			if child:IsA("GuiObject") then child.ZIndex = z + (child.Name == "UploadedArt" and 0 or 1) end
		end
		return old
	end
	if old then old:Destroy() end
	local root = Instance.new("Frame")
	root.Name, root.Size = name, UDim2.fromOffset(pixels, pixels)
	root.AnchorPoint, root.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	root.BackgroundTransparency, root.BorderSizePixel, root.ZIndex = 1, 0, z
	root:SetAttribute("ThemeFixed", true)
	root:SetAttribute("ArtSignature", signature)
	root.Parent = parent
	if not item or not item.Icon then return root end

	local function artwork(childName, asset, offset, rectSize)
		local image = Instance.new("ImageLabel")
		image.Name, image.Size = childName, UDim2.fromScale(1, 1)
		image.BackgroundTransparency, image.Image = 1, asset
		image.ImageRectOffset, image.ImageRectSize = offset, rectSize
		image.ImageColor3 = Color3.new(1, 1, 1)
		image.ScaleType, image.ZIndex = Enum.ScaleType.Fit, z
		image:SetAttribute("ThemeFixed", true)
		image.Parent = root
		return image
	end
	artwork("UploadedArt", item.Icon, item.IconRectOffset, item.IconRectSize)
	if item.IconOverlay then
		local overlay = artwork("IngredientArt", item.IconOverlay, item.IconOverlayRectOffset, item.IconRectSize)
		overlay.Size, overlay.Position = UDim2.fromScale(.44, .44), UDim2.fromScale(.6, .57)
		overlay.ZIndex = z + 1
	end
	if item.IconRank then
		local rank = Instance.new("TextLabel")
		rank.Name, rank.Size = "Rank", UDim2.fromScale(.34, .32)
		rank.Position, rank.BackgroundTransparency = UDim2.fromScale(0, .67), 1
		rank.Text, rank.TextScaled, rank.Font = tostring(item.IconRank), true, Enum.Font.GothamBold
		rank.TextColor3, rank.TextStrokeColor3 = Color3.fromRGB(255, 243, 210), Color3.fromRGB(27, 34, 30)
		rank.TextStrokeTransparency, rank.ZIndex = .15, z + 1
		rank:SetAttribute("ThemeFixed", true)
		rank.Parent = root
	end
	return root
end

-- Station controls share readable paper glyphs and distinct action colors.
function Theme.StationStyle(button, icon, role, iconOnly)
	local tones = {Craft=Color3.fromRGB(61,100,66), Fuel=Color3.fromRGB(112,76,39), Collect=Color3.fromRGB(40,89,98), Special=Color3.fromRGB(88,67,110), Danger=Color3.fromRGB(126,59,48), Neutral=Color3.fromRGB(48,61,57)}
	button:SetAttribute("ThemeFixed", true)
	button.BackgroundColor3 = tones[role] or tones.Neutral
	button.TextColor3 = Theme.Colors.Paper
	button.Font = Enum.Font.GothamMedium
	Theme.Button(button)
	local padding = button:FindFirstChild("ActionPadding") or Instance.new("UIPadding")
	padding.Name = "ActionPadding"
	padding.PaddingLeft = UDim.new(0, iconOnly and 0 or icon and 44 or 10)
	padding.PaddingRight = UDim.new(0, iconOnly and 0 or 10)
	padding.PaddingTop = UDim.new(0, 0)
	padding.Parent = button
	button.TextXAlignment = icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	local old = button:FindFirstChild("ActionIcon")
	if icon then
		if not old then
			old = Instance.new("Frame"); old.Name = "ActionIcon"; old.BackgroundTransparency = 1
			old.Size = UDim2.fromOffset(28,28); old.AnchorPoint = Vector2.new(0,.5)
			old.Position = UDim2.new(0,-36,.5,0); old.Parent = button
		end
		old.AnchorPoint = iconOnly and Vector2.new(.5,.5) or Vector2.new(0,.5)
		old.ZIndex = button.ZIndex+1
		old.Position = iconOnly and UDim2.fromScale(.5,.5) or UDim2.new(0,-36,.5,0)
		local glyph = old:FindFirstChild("Glyph")
		if not glyph or glyph:GetAttribute("IconKind") ~= icon then Theme.Icon(old,icon,24) end
	elseif old then old:Destroy() end
	return button
end

function Theme.StationTile(button,icon,role)
	Theme.StationStyle(button,nil,role)
	local padding=button.ActionPadding
	padding.PaddingLeft=UDim.new(0,4);padding.PaddingRight=UDim.new(0,4);padding.PaddingTop=UDim.new(0,32)
	local glyph=Theme.Icon(button,icon,22)
	glyph.Position=UDim2.new(.5,0,0,-16)
	button.TextSize=14
	return button
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
