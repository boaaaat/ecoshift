-- Self-contained native Roblox art: available before Shared modules or assets load.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local View = {}
local C = {
	Night = Color3.fromRGB(16, 25, 22), Case = Color3.fromRGB(28, 39, 31),
	Moss = Color3.fromRGB(64, 87, 56), Sage = Color3.fromRGB(170, 190, 143),
	Paper = Color3.fromRGB(235, 233, 211), Amber = Color3.fromRGB(226, 177, 82),
	Line = Color3.fromRGB(64, 77, 57), Muted = Color3.fromRGB(145, 162, 132),
	Danger = Color3.fromRGB(246, 143, 119),
}
local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props) do object[key] = value end
	object.Parent = parent
	return object
end
local function frame(parent, name, x, y, w, h, color)
	return make("Frame", parent, { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, BorderSizePixel = 0 })
end
local function text(parent, name, value, x, y, w, h, size, color, font)
	return make("TextLabel", parent, { Name = name, Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
		TextColor3 = color or C.Paper, Font = font or Enum.Font.Code, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center })
end
local function ring(parent, diameter, color, thickness)
	local circle = make("Frame", parent, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(242, 242), Size = UDim2.fromOffset(diameter, diameter), BackgroundTransparency = 1 })
	make("UICorner", circle, { CornerRadius = UDim.new(1, 0) })
	make("UIStroke", circle, { Color = color, Thickness = thickness or 1, Transparency = .3 })
	return circle
end
local function solid(parent, name, size, cf, color, class)
	return make(class or "Part", parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CastShadow = false })
end
local function scenery(parent)
	local viewport = make("ViewportFrame", parent, { Name = "ExpeditionDiorama", Position = UDim2.fromOffset(52, 60), Size = UDim2.fromOffset(380, 370),
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 170, 136), LightColor = C.Paper, LightDirection = Vector3.new(-1, -1, -1) })
	local world = Instance.new("WorldModel"); world.Parent = viewport
	local camera = Instance.new("Camera"); camera.FieldOfView = 36; camera.CFrame = CFrame.lookAt(Vector3.new(24, 20, 29), Vector3.new(0, 3, 0)); camera.Parent = viewport; viewport.CurrentCamera = camera
	local V, CF = Vector3.new, CFrame.new
	solid(world, "FloatingBedrock", V(18, 2.3, 13), CF(0, -.9, 0) * CFrame.Angles(0, .08, 0), Color3.fromRGB(65, 76, 66))
	solid(world, "MossShelf", V(18.3, .55, 13.2), CF(0, .5, 0) * CFrame.Angles(0, .08, 0), C.Moss)
	for i, position in ipairs({ V(-7, 0, -4), V(-4, 0, -5), V(5, 0, -4), V(7, 0, 0), V(-7, 0, 2) }) do
		local height = 4 + (i % 3)
		solid(world, "PineTrunk", V(.45, height, .45), CF(position + V(0, height / 2, 0)), Color3.fromRGB(99, 79, 49))
		for level = 1, 3 do
			local width = 3.7 - level * .65
			for side = 0, 1 do
				solid(world, "PineBough", V(width, 2.7, width), CF(position + V(0, 1.8 + level * 1.2, 0)) * CFrame.Angles(0, side * math.pi, 0), i % 2 == 0 and C.Moss or Color3.fromRGB(82, 110, 71), "WedgePart")
			end
		end
	end
	for i = 1, 6 do
		solid(world, "TrailStone", V(1.3, .18, .8), CF(-2.5 + i * .45, .91, 6 - i * 1.15) * CFrame.Angles(0, i * .7, 0), Color3.fromRGB(164, 163, 130))
	end
	local crystal = Instance.new("Model"); crystal.Name = "ShiftCrystal"; crystal.Parent = world
	for side = 0, 3 do
		local shard = solid(crystal, "Facet", V(1.65, 4.6, 1.65), CF(0, 5, 0) * CFrame.Angles(0, side * math.pi / 2, 0), side % 2 == 0 and C.Amber or Color3.fromRGB(167, 120, 53), "WedgePart")
		shard.Material = Enum.Material.Neon
	end
	crystal.WorldPivot = CF(0, 5, 0)
	solid(world, "SurveyPlinth", V(3.1, 1.2, 3.1), CF(0, 1.3, 0) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(112, 120, 99))
	return crystal
end

local function meter(parent, y, index, name, color)
	local row = make("Frame", parent, { Name = name .. "Meter", Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(486, 115), BackgroundTransparency = 1 })
	text(row, name .. "Index", index, 0, 0, 32, 26, 14, color)
	text(row, name .. "Label", name, 40, 0, 330, 26, 20, C.Paper, Enum.Font.GothamBold)
	local percent = text(row, name .. "Percent", "0%", 386, -3, 100, 32, 27, color)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(row, name .. "Track", 0, 37, 486, 20, C.Case)
	local fill = frame(track, "Fill", 0, 0, 0, 20, color)
	for i = 1, 23 do frame(track, "Division", i * 486 / 24 - 1, 0, 2, 20, C.Night) end
	local status = text(row, name .. "Stage", "Awaiting signal", 0, 65, 486, 28, 18, C.Muted)
	local marks = text(row, name .. "Marks", "", 0, 97, 486, 18, 12, C.Muted)
	return { Row = row, Fill = fill, Percent = percent, Status = status, Marks = marks, Color = color, Value = 0, Target = 0 }
end

function View.Create(parent)
	local self = setmetatable({}, { __index = View })
	self.Gui = make("ScreenGui", parent, { Name = "ExpeditionLoading", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	self.Background = make("TextButton", self.Gui, { Name = "InputCurtain", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false,
		BackgroundColor3 = C.Night, BorderSizePixel = 0, Active = true, Modal = true, Selectable = false })
	make("UIGradient", self.Background, { Rotation = 28, Color = ColorSequence.new(C.Case, C.Night) })
	-- Sparse etched grid stays behind the illustration; no external texture requests.
	for i = 0, 24 do
		make("Frame", self.Background, { Position = UDim2.fromScale(i / 24, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.Line, BackgroundTransparency = .85, BorderSizePixel = 0 })
	end
	for i = 0, 14 do
		make("Frame", self.Background, { Position = UDim2.fromScale(0, i / 14), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Line, BackgroundTransparency = .88, BorderSizePixel = 0 })
	end
	local body = make("Frame", self.Background, { Name = "FieldInstrument", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(1120, 650), BackgroundTransparency = 1 })
	self.Body = body
	local scale = make("UIScale", body, { Scale = 1 })
	self.Scale = scale
	local function resize()
		local size = self.Background.AbsoluteSize
		if size.X > 1 and size.Y > 1 then self:SetViewportSize(size) end
	end
	self.SizeConnection = self.Background:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	for _, corner in ipairs({ {0, 0, 1, 1}, {1120, 0, -1, 1}, {0, 650, 1, -1}, {1120, 650, -1, -1} }) do
		local x, y, dx, dy = table.unpack(corner)
		local horizontal = frame(body, "BrassCorner", 0, 0, 24, 2, C.Amber)
		horizontal.Position = UDim2.new(x == 0 and 0 or 1, dx < 0 and -24 or 0, y == 0 and 0 or 1, 0)
		local vertical = frame(body, "BrassCorner", 0, 0, 2, 24, C.Amber)
		vertical.Position = UDim2.new(x == 0 and 0 or 1, 0, y == 0 and 0 or 1, dy < 0 and -24 or 0)
	end
	text(body, "Brand", "E C O S H I F T", 30, 18, 400, 32, 23, C.Paper, Enum.Font.GothamBlack)
	self.Signal = text(body, "Signal", "EXPEDITION  /  ESTABLISHING SIGNAL", 540, 22, 550, 26, 14, C.Amber)
	frame(body, "HeaderRule", 30, 66, 1060, 1, C.Line).Size = UDim2.new(1, -60, 0, 1)
	local instrument = make("Frame", body, { Name = "Compass", Position = UDim2.fromOffset(10, 78), Size = UDim2.fromOffset(484, 484), BackgroundTransparency = 1 })
	self.Instrument = instrument
	self.InstrumentScale = make("UIScale", instrument, { Scale = 1 })
	ring(instrument, 438, C.Moss); ring(instrument, 410, C.Amber); ring(instrument, 392, C.Line)
	for i = 0, 59 do
		local angle = math.rad(i * 6)
		local tick = frame(instrument, "Bearing", 242 + math.sin(angle) * 212, 242 - math.cos(angle) * 212, i % 5 == 0 and 2 or 1, i % 5 == 0 and 12 or 5, i % 5 == 0 and C.Amber or C.Moss)
		tick.AnchorPoint = Vector2.new(.5, .5); tick.Rotation = i * 6
	end
	for _, bearing in ipairs({ {"N", 232, 3}, {"S", 232, 457}, {"W", 0, 230}, {"E", 466, 230} }) do
		text(instrument, "Bearing" .. bearing[1], bearing[1], bearing[2], bearing[3], 20, 24, 17, C.Amber)
	end
	self.Crystal = scenery(instrument)
	self.Needle = frame(instrument, "SurveyNeedle", 242, 37, 9, 9, C.Amber); self.Needle.Rotation = 45
	self.Caption = text(body, "IllustrationCaption", "THE WORLD SHIFTS. YOUR JOURNEY CONTINUES.", 30, 566, 475, 22, 12, C.Muted)
	local panel = make("Frame", body, { Name = "LoadingReadout", Position = UDim2.fromOffset(574, 94), Size = UDim2.fromOffset(486, 460), BackgroundTransparency = 1 })
	self.Panel = panel
	text(panel, "Eyebrow", "PREPARE FOR THE UNKNOWN", 0, 0, 486, 24, 13, C.Amber)
	self.Heading = text(panel, "Heading", "THE WILDS\nARE WAKING", 0, 35, 486, 112, 44, C.Paper, Enum.Font.GothamBlack)
	self.Heading.TextYAlignment = Enum.TextYAlignment.Top
	self.World = meter(panel, 173, "01", "WORLD", C.Amber)
	self.Player = meter(panel, 310, "02", "EXPLORER", C.Sage)
	self.World.Marks.Text = "RECORDS  /  TERRAIN  /  CAMP"
	self.Player.Marks.Text = "PROFILE  /  FIELD KIT  /  ARRIVAL"
	local footerRule = frame(body, "FooterRule", 30, 600, 1060, 1, C.Line)
	footerRule.Position = UDim2.new(0, 30, 1, -50); footerRule.Size = UDim2.new(1, -60, 0, 1)
	self.Footer = text(body, "FieldNote", "FIELD NOTE   A torch lights the trail, but offers no heat protection.", 30, 612, 960, 25, 13, C.Muted)
	self.Footer.Position = UDim2.new(0, 30, 1, -38); self.Footer.Size = UDim2.new(1, -160, 0, 25)
	self.Clock = text(body, "Elapsed", "00:00", 1000, 612, 90, 25, 14, C.Amber); self.Clock.TextXAlignment = Enum.TextXAlignment.Right
	self.Clock.Position = UDim2.new(1, -120, 1, -38)
	self.Dismiss = make("TextButton", body, { Name = "ShowLobby", Position = UDim2.fromOffset(574, 557), Size = UDim2.fromOffset(486, 34),
		Text = "SHOW LOBBY  /  TRAVEL WILL KEEP RETRYING", Font = Enum.Font.Code, TextSize = 13, TextColor3 = C.Amber,
		BackgroundColor3 = C.Case, BorderSizePixel = 0, Visible = false })
	self.StartedAt = os.clock()
	self.LayoutReady = true
	resize()
	return self
end

function View:SetViewportSize(size)
	local compact = size.Y < 600 or size.X < 900
	local width, height = compact and 1000 or 1120, compact and 490 or 650
	self.Scale.Scale = math.max(.1, math.min((size.X - 60) / width, (size.Y - 40) / height, 1.7))
	if not self.LayoutReady then return end
	self.Body.Size = UDim2.fromOffset(width, height)
	self.Instrument.Position = UDim2.fromOffset(compact and 34 or 10, compact and 85 or 78)
	self.InstrumentScale.Scale = compact and .72 or 1
	self.Caption.Visible = not compact
	self.Panel.Position = UDim2.fromOffset(compact and 454 or 574, compact and 76 or 94)
	self.Heading.TextSize = compact and 26 or 44
	self.Heading.Size = UDim2.fromOffset(486, compact and 65 or 112)
	self.World.Row.Position = UDim2.fromOffset(0, compact and 108 or 173)
	self.Player.Row.Position = UDim2.fromOffset(0, compact and 225 or 310)
	self.World.Marks.Visible = not compact; self.Player.Marks.Visible = not compact
	self.Signal.Position = UDim2.fromOffset(compact and 454 or 540, 22)
	self.Signal.TextSize = compact and 12 or 14
	self.Dismiss.Position = UDim2.fromOffset(compact and 454 or 574, compact and 405 or 557)
	self.Dismiss.Size = UDim2.fromOffset(486, compact and 28 or 34)
end

function View:SetDismiss(visible, callback)
	self.Dismiss.Visible = visible
	if self.DismissConnection then self.DismissConnection:Disconnect(); self.DismissConnection = nil end
	if callback then self.DismissConnection = self.Dismiss.Activated:Connect(callback) end
end

function View:SetProgress(world, worldStage, player, playerStage)
	for _, entry in ipairs({ {self.World, world, worldStage}, {self.Player, player, playerStage} }) do
		local meterView, value, stage = entry[1], entry[2], entry[3]
		meterView.Target = value and math.clamp(value, 0, 1) or nil
		meterView.Status.Text = stage
		if value == nil then meterView.Percent.Text = "--"; meterView.Fill.Size = UDim2.fromOffset(0, 20); meterView.Value = 0 end
	end
end

function View:Animate()
	if self.Animation then return end
	self.Animation = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - self.StartedAt
		local reduced = self.ReducedMotion == true
		self.Clock.Text = string.format("%02d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60))
		for _, meterView in ipairs({self.World, self.Player}) do
			if meterView.Target then
				meterView.Value += (meterView.Target - meterView.Value) * (reduced and 1 or math.min(1, dt * 9))
				if math.abs(meterView.Target - meterView.Value) < .001 then meterView.Value = meterView.Target end
				meterView.Fill.Size = UDim2.fromOffset(486 * meterView.Value, 20)
				meterView.Percent.Text = string.format("%d%%", math.floor(meterView.Value * 100 + .001))
			end
		end
		if not reduced then
			self.Crystal:PivotTo(CFrame.new(0, 5 + math.sin(elapsed * 1.2) * .25, 0) * CFrame.Angles(0, elapsed * .22, 0))
			local angle = elapsed * .28
			self.Needle.Position = UDim2.fromOffset(238 + math.sin(angle) * 200, 238 - math.cos(angle) * 200)
			self.Needle.Rotation = math.deg(angle) + 45
		end
	end)
end

function View:Error(message)
	self.Signal.Text = "EXPEDITION  /  SIGNAL INTERRUPTED"
	self.Signal.TextColor3 = C.Danger
	self.Heading.Text = "THE TRAIL\nIS ON HOLD"
	self.Footer.Text = message
	self.Footer.TextColor3 = C.Danger
end

function View:Destroy()
	if self.DismissConnection then self.DismissConnection:Disconnect(); self.DismissConnection = nil end
	if self.Animation then self.Animation:Disconnect(); self.Animation = nil end
	if self.SizeConnection then self.SizeConnection:Disconnect(); self.SizeConnection = nil end
	self.Gui:Destroy()
end

function View:Finish(reduced)
	self.Signal.Text = "EXPEDITION  /  SIGNAL ESTABLISHED"
	self.Heading.Text = "THE WILDS\nAWAIT YOU"
	self:SetProgress(1, "World ready", 1, "Explorer ready")
	task.wait(reduced and .1 or .65)
	-- A short black dissolve avoids CanvasGroup texture-size limits on large screens.
	local veil = make("Frame", self.Gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Night, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10 })
	local fade = TweenService:Create(veil, TweenInfo.new(reduced and 0 or .2), { BackgroundTransparency = 0 }); fade:Play(); fade.Completed:Wait()
	self.Background.Visible = false
	local reveal = TweenService:Create(veil, TweenInfo.new(reduced and 0 or .4), { BackgroundTransparency = 1 }); reveal:Play(); reveal.Completed:Wait()
	self:Destroy()
end

return View
