local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Shared = RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode() ~= "Expedition" then return end

local Theme = require(Shared.UI.UITheme)
local UIFactory = require(Shared.UI.UIFactory)
local RemoteRequest = require(Shared.UI.RemoteRequest)
local Items = require(Shared.Items.ItemDatabase)
local Guide = require(Shared.UI.RecipeGuideUI)
local CampaignConfig = require(Shared.CampaignConfig)
local remote = RS:WaitForChild("Remotes"):WaitForChild("Campaign", 120)
if not remote then return end

local colors = Theme.Colors
local player = Players.LocalPlayer
local make = UIFactory.Create
local function bind(object, property, token)
	Theme.Bind(object, property, token)
	return object
end
local function label(parent, text, size, position, textSize, token, bold)
	local object = Theme.Label(parent, text, size, position, textSize or 16, nil, bold)
	object.TextWrapped = true
	object.TextTruncate = Enum.TextTruncate.None
	bind(object, "TextColor3", token or "Text")
	return object
end

local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "CampaignUI", ResetOnSpawn = false, Enabled = false, DisplayOrder = 65,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
Theme.TrackRoot(gui)

local defenseGui = make("ScreenGui", player.PlayerGui, {
	Name = "CampaignDefenseHUD", ResetOnSpawn = false, DisplayOrder = 58,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})
Theme.TrackRoot(defenseGui)
local defenseCard = make("CanvasGroup", defenseGui, {
	Name = "DefenseStatus", Size = UDim2.fromOffset(460, 116), Position = UDim2.new(.5, 0, 0, 132),
	AnchorPoint = Vector2.new(.5, 0), BackgroundColor3 = colors.Night, BorderSizePixel = 0,
	Visible = false,
})
Theme.Panel(defenseCard, true)
local defenseIcon = make("Frame", defenseCard, {
	Name = "Icon", Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(16, 14),
	BackgroundColor3 = colors.Moss, BackgroundTransparency = .08, BorderSizePixel = 0,
})
Theme.Corner(defenseIcon, 10)
Theme.Icon(defenseIcon, "Shield", 27)
local defenseEyebrow = label(defenseCard, "PROJECT DEFENSE STARTED",
	UDim2.new(1, -184, 0, 18), UDim2.fromOffset(70, 11), 11, "Amber", true)
defenseEyebrow.TextWrapped = false
local defenseTitle = label(defenseCard, "Defend the project",
	UDim2.new(1, -184, 0, 27), UDim2.fromOffset(70, 29), 17, "Text", true)
defenseTitle.TextWrapped = false
defenseTitle.TextTruncate = Enum.TextTruncate.AtEnd
local defenseProgress = label(defenseCard, "0 / 0 SEC",
	UDim2.fromOffset(106, 24), UDim2.new(1, -122, 0, 24), 12, "Amber", true)
defenseProgress.TextXAlignment = Enum.TextXAlignment.Right
defenseProgress.TextWrapped = false
local defenseBar = make("Frame", defenseCard, {
	Name = "Progress", Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -32, 0, 10),
	BackgroundColor3 = colors.Background, BackgroundTransparency = .12, BorderSizePixel = 0,
})
Theme.Corner(defenseBar, 5)
local defenseFill = make("Frame", defenseBar, {
	Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.Amber, BorderSizePixel = 0,
})
Theme.Corner(defenseFill, 5)
local defenseHint = label(defenseCard, "Stay within 70 studs of the project site to advance",
	UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 84), 11, "TextMuted")
defenseHint.TextWrapped = false
defenseHint.TextTruncate = Enum.TextTruncate.AtEnd

Theme.BindResponsive(defenseGui, function(isMobile, available)
	defenseCard.Size = UDim2.fromOffset(math.min(isMobile and 330 or 460, available.X - 20), isMobile and 108 or 116)
	defenseCard.Position = UDim2.new(.5, 0, 0, isMobile and 124 or 132)
	defenseIcon.Size = UDim2.fromOffset(isMobile and 36 or 42, isMobile and 36 or 42)
	defenseTitle.TextSize = isMobile and 14 or 17
	defenseProgress.TextSize = isMobile and 10 or 12
	defenseHint.TextSize = isMobile and 10 or 11
end)

local backdrop = make("TextButton", gui, {
	Name = "RelayBackdrop", Text = "", AutoButtonColor = false, Modal = true, Active = true,
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 13, 11),
	BackgroundTransparency = .28, BorderSizePixel = 0, ZIndex = 1,
})
local panel = make("CanvasGroup", gui, {
	Name = "FieldRelay", Size = UDim2.fromOffset(900, 720), Position = UDim2.fromScale(.5, .5),
	AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = colors.Panel, BorderSizePixel = 0,
	Active = true, ZIndex = 2,
})
local responsiveScale = make("UIScale", panel, {Name = "ViewportScale", Scale = 1})
Theme.Panel(panel, true)
Theme.CaptureCursor(panel)
Theme.AnimatePanel(panel)

local headerIcon = make("Frame", panel, {
	Name = "RelayIcon", Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(20, 16),
	BackgroundColor3 = colors.Moss, BackgroundTransparency = .08, BorderSizePixel = 0,
})
Theme.Corner(headerIcon, 12)
Theme.Icon(headerIcon, "Survey", 30)
local eyebrow = label(panel, "EXPEDITION PROJECT", UDim2.fromOffset(400, 18), UDim2.fromOffset(88, 14), 12, "Amber", true)
local title = label(panel, "FIELD RELAY", UDim2.new(1, -220, 0, 34), UDim2.fromOffset(88, 31), 26, "Text", true)
title.TextWrapped = false
local tierBadge = make("TextLabel", panel, {
	Name = "TierBadge", Size = UDim2.fromOffset(92, 34), Position = UDim2.new(1, -154, 0, 24),
	Text = "TIER 1", Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0,
	BackgroundColor3 = colors.Amber, TextColor3 = colors.Night,
})
Theme.Corner(tierBadge, 8)
local close = make("TextButton", panel, {
	Name = "Close", Position = UDim2.new(1, -56, 0, 18), Size = UDim2.fromOffset(42, 42),
	Text = "", BackgroundColor3 = colors.SlotEmpty, TextColor3 = colors.Text, BorderSizePixel = 0,
})
Theme.Button(close)
Theme.Icon(close, "Close", 22)

local headerRule = make("Frame", panel, {
	Name = "HeaderRule", Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 1),
	BorderSizePixel = 0, BackgroundColor3 = colors.Border, BackgroundTransparency = .35,
})
local list = make("ScrollingFrame", panel, {
	Name = "ProjectContents", Position = UDim2.fromOffset(18, 94), Size = UDim2.new(1, -36, 1, -166),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
	ScrollBarImageColor3 = colors.Amber, ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIListLayout", list, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
make("UIPadding", list, {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)})

local statusCard = make("Frame", panel, {
	Name = "StatusCard", Position = UDim2.new(0, 18, 1, -60), Size = UDim2.new(1, -36, 0, 44),
	BackgroundColor3 = colors.SlotEmpty, BackgroundTransparency = .1, BorderSizePixel = 0,
})
Theme.Corner(statusCard, 8)
local statusDot = make("Frame", statusCard, {
	Name = "StatusDot", Position = UDim2.fromOffset(14, 17), Size = UDim2.fromOffset(10, 10),
	BackgroundColor3 = colors.Amber, BorderSizePixel = 0,
})
Theme.Corner(statusDot, 5)
local status = label(statusCard, "Contributions and discoveries are shared with the whole crew.",
	UDim2.new(1, -46, 1, 0), UDim2.fromOffset(34, 0), 14, "TextMuted")
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None
status.TextYAlignment = Enum.TextYAlignment.Center

local state, signature
local defenseWasActive = false
local requests = RemoteRequest.new(remote)
local mobile = false
local function updateDefenseHUD(nextState)
	local milestone = nextState and nextState.Milestone
	local target = milestone and tonumber(milestone.Defense)
	local activeDefense = nextState and nextState.Started and target and target > 0
	if not activeDefense then
		defenseCard.Visible = false
		defenseFill.Size = UDim2.fromScale(0, 1)
		defenseWasActive = false
		return
	end
	local elapsed = math.clamp(tonumber(nextState.Defense) or 0, 0, target)
	local progress = elapsed / target
	defenseTitle.Text = "Defend the " .. (milestone.Name or "project")
	defenseProgress.Text = string.format("%d / %d SEC", math.floor(elapsed), target)
	if not defenseWasActive then
		defenseCard.GroupTransparency = 1
		defenseCard.Visible = true
		Theme.Tween(defenseCard, {GroupTransparency = 0}, .25)
	end
	Theme.Tween(defenseFill, {Size = UDim2.fromScale(progress, 1)}, .3)
	defenseWasActive = true
end
local function setStatus(text, token)
	status.Text = text
	bind(status, "TextColor3", token or "TextMuted")
	bind(statusDot, "BackgroundColor3", token or "Amber")
end
local function setOpen(open)
	gui.Enabled = open
	if open then
		panel.Visible = false
		panel.Visible = true
	end
end
local function closeUI() setOpen(false) end
close.Activated:Connect(closeUI)
backdrop.Activated:Connect(closeUI)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and gui.Enabled and input.KeyCode == Enum.KeyCode.Escape then closeUI() end
end)

local function sectionHeading(text, iconKind, order)
	local row = make("Frame", list, {
		Name = text:gsub("%W", "") .. "Heading", Size = UDim2.new(1, -4, 0, 30),
		BackgroundTransparency = 1, LayoutOrder = order,
	})
	local icon = make("Frame", row, {Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(2, 1), BackgroundTransparency = 1})
	Theme.Icon(icon, iconKind, 22)
	local heading = label(row, text, UDim2.new(1, -38, 1, 0), UDim2.fromOffset(36, 0), mobile and 15 or 17, "Text", true)
	heading.TextYAlignment = Enum.TextYAlignment.Center
	return row
end

local function card(parent, name, height, order, accentToken)
	local frame = make("Frame", parent, {
		Name = name, Size = UDim2.new(1, -6, 0, height), BackgroundColor3 = colors.SlotEmpty,
		BackgroundTransparency = .06, BorderSizePixel = 0, LayoutOrder = order,
	})
	Theme.Corner(frame, 10)
	local stroke = make("UIStroke", frame, {Thickness = 1, Transparency = .55})
	bind(stroke, "Color", accentToken or "Border")
	local tab = make("Frame", frame, {
		Name = "Accent", Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(4, height - 20),
		BorderSizePixel = 0,
	})
	bind(tab, "BackgroundColor3", accentToken or "Amber")
	Theme.Corner(tab, 3)
	return frame
end

local function milestoneCopy(milestone)
	if milestone.Boss then return "Find the route, prepare the crew, and enter the encounter together." end
	if milestone.Interior then return "Recover the route and finish the expedition records inside the archive." end
	if milestone.Instruments then return "Recover instruments from different regions and rebuild the weather network." end
	return "Recover the missing parts, contribute materials, then defend the project site."
end

local function itemGlyph(item, id)
	if item and item.HasTag then
		if item:HasTag("Plant") or item:HasTag("Wood") then return "Leaf" end
		if item:HasTag("Mineral") or item:HasTag("Ore") then return "Mineral" end
		if item:HasTag("Food") then return "Food" end
	end
	local key = string.lower(id or "")
	if key:find("wood") or key:find("plank") or key:find("fiber") then return "Leaf" end
	if key:find("ore") or key:find("bar") or key:find("metal") or key:find("stone") or key:find("glass") or key:find("crystal") then return "Mineral" end
	if key:find("cloth") then return "Armor" end
	return "Craft"
end
local function materialRow(id, paid, required, order)
	local item = Items:Get(id)
	local row = make("TextButton", list, {
		Name = "Material_" .. id, Size = UDim2.new(1, -6, 0, mobile and 66 or 76),
		Text = "", AutoButtonColor = false, BackgroundColor3 = colors.SlotEmpty,
		BackgroundTransparency = .02, BorderSizePixel = 0, LayoutOrder = order,
	})
	Theme.Button(row)
	local stroke = make("UIStroke", row, {Thickness = 1, Transparency = .56})
	bind(stroke, "Color", paid >= required and "Success" or "Border")
	local glyphKind = itemGlyph(item, id)
	local tint = item and item.IconColor or (glyphKind == "Mineral" and colors.Cold or glyphKind == "Armor" and colors.Sage or colors.Moss)
	local wellSize = mobile and 48 or 56
	local well = make("Frame", row, {
		Name = "MaterialIconWell", Size = UDim2.fromOffset(wellSize, wellSize),
		Position = UDim2.fromOffset(10, mobile and 9 or 10), BackgroundColor3 = tint,
		BackgroundTransparency = .12, BorderSizePixel = 0,
	})
	well:SetAttribute("ThemeFixed", true)
	Theme.Corner(well, 9)
	-- ItemIcons/<item id> can supply this image later without changing this UI.
	local iconAsset = item and type(item.Icon) == "string" and item.Icon or ""
	local art = make("ImageLabel", well, {
		Name = "MaterialArt", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1, Image = iconAsset, ScaleType = Enum.ScaleType.Fit,
		Visible = iconAsset ~= "", ZIndex = row.ZIndex + 2,
	})
	if not art.Visible then Theme.Icon(well, glyphKind, mobile and 25 or 29) end
	local textX = 22 + wellSize
	local name = label(row, item and item.Name or id, UDim2.new(1, -textX - 142, 0, 26),
		UDim2.fromOffset(textX, mobile and 8 or 10), mobile and 15 or 17, "Text", true)
	name.TextWrapped = false; name.TextTruncate = Enum.TextTruncate.AtEnd
	local count = label(row, string.format("%d / %d", paid, required), UDim2.fromOffset(112, 28),
		UDim2.new(1, -128, 0, mobile and 8 or 10), mobile and 15 or 17, paid >= required and "Success" or "Amber", true)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local progress = math.clamp(paid / math.max(required, 1), 0, 1)
	local bar = make("Frame", row, {
		Name = "Progress", Position = UDim2.fromOffset(textX, mobile and 40 or 48),
		Size = UDim2.new(1, -textX - 18, 0, mobile and 8 or 10), BackgroundColor3 = colors.Background,
		BackgroundTransparency = .12, BorderSizePixel = 0,
	})
	Theme.Corner(bar, 5)
	local fill = make("Frame", bar, {Size = UDim2.fromScale(progress, 1), BorderSizePixel = 0})
	bind(fill, "BackgroundColor3", paid >= required and "Success" or "Amber")
	Theme.Corner(fill, 5)
	row.Activated:Connect(function() Guide.Open(id) end)
	return row
end

local function actionButton(text, icon, role, callback, order)
	local button = make("TextButton", list, {
		Name = text:gsub("%W", "") .. "Button", Size = UDim2.new(1, -6, 0, mobile and 46 or 52),
		Text = text, TextWrapped = true, TextSize = mobile and 14 or 16,
		Font = Enum.Font.GothamBold, BorderSizePixel = 0, LayoutOrder = order,
	})
	Theme.StationStyle(button, icon, role)
	button.Activated:Connect(callback)
	return button
end

local function request(action)
	requests:Send(action, nil, {
		AddRequestId = false,
		Timeout = 5,
		OnStart = function() setStatus("Sending request…", "Amber") end,
		OnTimeout = function() setStatus("No response yet. Close and reopen the relay to refresh.", "Warning") end,
	})
end

local function render(force)
	if not state or not gui.Enabled then return end
	local nextSignature = HttpService:JSONEncode({
		state.Tier, state.Facts, state.Paid, state.Cost, state.Instruments, state.Started,
		math.floor(state.Defense or 0), state.Endurance, state.CompleteAt, state.Ready, state.CreativeWorld, mobile,
	})
	if not force and signature == nextSignature then return end
	signature = nextSignature
	local scrollY = list.CanvasPosition.Y
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local milestone = state.Milestone
	title.Text = string.upper(milestone.Name or "EXPEDITION PROJECT")
	tierBadge.Text = "TIER " .. tostring(state.Tier or 1)

	sectionHeading("CURRENT OBJECTIVE", "Survey", 10)
	local objective = card(list, "Objective", mobile and 96 or 112, 20, state.Ready and "Success" or "Amber")
	local stateText = state.Started and "ACTIVE" or state.Ready and "READY" or "PREPARING"
	local objectiveTitle = label(objective, milestone.Name, UDim2.new(1, -136, 0, 30), UDim2.fromOffset(18, 12), mobile and 18 or 22, "Text", true)
	objectiveTitle.TextWrapped = false; objectiveTitle.TextTruncate = Enum.TextTruncate.AtEnd
	local badge = make("TextLabel", objective, {
		Size = UDim2.fromOffset(104, 28), Position = UDim2.new(1, -120, 0, 10), Text = stateText,
		Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0,
		BackgroundColor3 = state.Ready and colors.SuccessFill or colors.Moss, TextColor3 = colors.Paper,
	})
	badge:SetAttribute("ThemeFixed", true); Theme.Corner(badge, 7)
	label(objective, milestoneCopy(milestone), UDim2.new(1, -36, 0, mobile and 42 or 48),
		UDim2.fromOffset(18, mobile and 45 or 51), mobile and 13 or 15, "TextMuted")

	if state.CompleteAt then
		local complete = card(list, "CampaignComplete", mobile and 84 or 98, 30, "Success")
		label(complete, "EXPEDITION CAMPAIGN COMPLETE", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(18, 12), mobile and 17 or 20, "Success", true)
		label(complete, "Your crew can continue exploring with endurance scaling.", UDim2.new(1, -32, 0, 35), UDim2.fromOffset(18, 43), mobile and 13 or 15, "TextMuted")
		actionButton(state.Endurance and "ENDURANCE ENABLED" or "ENABLE ENDURANCE", "Upgrade", "Special", function() request("Endurance") end, 40)
	else
		local facts = {}
		for fact in pairs(milestone.Facts or {}) do table.insert(facts, fact) end
		table.sort(facts)
		if #facts > 0 or milestone.Instruments then
			sectionHeading("DISCOVERIES", "Search", 30)
		end
		local order = 40
		for _, fact in ipairs(facts) do
			local recovered = state.Facts[fact] == true
			local clue = card(list, "Clue_" .. fact, mobile and 46 or 52, order, recovered and "Success" or "Border")
			local marker = make("Frame", clue, {
				Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(12, mobile and 9 or 12),
				BackgroundColor3 = recovered and colors.SuccessFill or colors.Background, BorderSizePixel = 0,
			})
			marker:SetAttribute("ThemeFixed", true); Theme.Corner(marker, 14)
			label(marker, recovered and "✓" or "·", UDim2.fromScale(1, 1), UDim2.new(), 16, "Text", true).TextXAlignment = Enum.TextXAlignment.Center
			local clueName = fact:gsub("(%l)(%u)", "%1 %2")
			local text = label(clue, clueName, UDim2.new(1, -142, 1, 0), UDim2.fromOffset(52, 0), mobile and 14 or 16, recovered and "Success" or "Text")
			text.TextYAlignment = Enum.TextYAlignment.Center
			local tag = label(clue, recovered and "RECOVERED" or "FIND  ›", UDim2.fromOffset(98, 30), UDim2.new(1, -112, .5, -15), 11, recovered and "Success" or "Amber", true)
			tag.TextXAlignment = Enum.TextXAlignment.Right; tag.TextYAlignment = Enum.TextYAlignment.Center
			local discoveryButton = make("TextButton", clue, {
				Name = "DiscoveryHelp", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = "", AutoButtonColor = false, ZIndex = 8,
			})
			discoveryButton.Activated:Connect(function()
				local hint = CampaignConfig.DiscoveryHints[fact] or "Explore matching landmarks to recover this discovery."
				setStatus((recovered and "Recovered. " or "How to find it: ") .. hint, recovered and "Success" or "Amber")
			end)
			order += 1
		end
		if milestone.Instruments then
			local instrumentCount = 0
			for _ in pairs(state.Instruments or {}) do instrumentCount += 1 end
			local instrument = card(list, "CalibratedInstruments", mobile and 52 or 58, order, instrumentCount >= 3 and "Success" or "Cold")
			label(instrument, "Calibrated instruments", UDim2.new(1, -150, 1, 0), UDim2.fromOffset(18, 0), mobile and 14 or 16, "Text", true).TextYAlignment = Enum.TextYAlignment.Center
			local number = label(instrument, tostring(instrumentCount) .. " / 3  ·  FIND ›", UDim2.fromOffset(140, 30), UDim2.new(1, -156, .5, -15), 12, instrumentCount >= 3 and "Success" or "Cold", true)
			number.TextXAlignment = Enum.TextXAlignment.Right; number.TextYAlignment = Enum.TextYAlignment.Center
			local discoveryButton = make("TextButton", instrument, {
				Name = "DiscoveryHelp", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = "", AutoButtonColor = false, ZIndex = 8,
			})
			discoveryButton.Activated:Connect(function()
				setStatus("How to find it: " .. CampaignConfig.DiscoveryHints.CalibratedInstrument, instrumentCount >= 3 and "Success" or "Amber")
			end)
			order += 1
		end

		local ids = {}
		for id in pairs(state.Cost or {}) do table.insert(ids, id) end
		table.sort(ids)
		if #ids > 0 then sectionHeading("PROJECT MATERIALS", "Pack", 100) end
		for index, id in ipairs(ids) do
			materialRow(id, state.Paid[id] or 0, state.Cost[id], 110 + index)
		end
		if #ids > 0 then
			actionButton("CONTRIBUTE FROM FIELD PACK", "Collect", "Collect", function() request("Contribute") end, 150)
		end
		if state.CreativeWorld and not state.Ready then
			actionButton("CREATIVE: FIND MATERIALS + DISCOVERIES", "Search", "Special", function() request("CreativePrepare") end, 155)
		end
		if state.Started and milestone.Defense then
			sectionHeading("PROJECT DEFENSE", "Shield", 160)
			local defense = card(list, "Defense", mobile and 68 or 78, 170, "Amber")
			local seconds = math.floor(state.Defense or 0)
			local target = milestone.Defense
			label(defense, "Hold the project site", UDim2.new(1, -150, 0, 25), UDim2.fromOffset(18, 10), mobile and 14 or 16, "Text", true)
			local duration = label(defense, string.format("%d / %ds", seconds, target), UDim2.fromOffset(116, 25), UDim2.new(1, -134, 0, 10), mobile and 13 or 15, "Amber", true)
			duration.TextXAlignment = Enum.TextXAlignment.Right
			local bar = make("Frame", defense, {Position = UDim2.fromOffset(18, mobile and 43 or 49), Size = UDim2.new(1, -36, 0, 10), BackgroundColor3 = colors.Background, BorderSizePixel = 0})
			Theme.Corner(bar, 5)
			local fill = make("Frame", bar, {Size = UDim2.fromScale(math.clamp(seconds / target, 0, 1), 1), BackgroundColor3 = colors.Amber, BorderSizePixel = 0})
			Theme.Corner(fill, 5)
		else
			local actionText = milestone.Boss and "ENTER ENCOUNTER" or milestone.Interior and "ENTER ARCHIVE" or "BEGIN PROJECT DEFENSE"
			local icon = milestone.Boss and "Attack" or milestone.Interior and "Search" or "Shield"
			actionButton(actionText, icon, "Special", function() request("Begin") end, 170)
		end
	end
	task.defer(function()
		list.CanvasPosition = Vector2.new(0, math.min(scrollY, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y)))
	end)
end

Theme.BindResponsive(gui, function(isMobile, available)
	mobile = isMobile
	if mobile then
		responsiveScale.Scale = 1
		panel.Size = UDim2.fromOffset(math.max(320, available.X - 12), math.max(260, available.Y - 12))
		headerIcon.Size = UDim2.fromOffset(42, 42); headerIcon.Position = UDim2.fromOffset(12, 10)
		eyebrow.Position = UDim2.fromOffset(64, 7); eyebrow.TextSize = 10
		title.Position = UDim2.fromOffset(64, 22); title.Size = UDim2.new(1, -220, 0, 28); title.TextSize = 20
		tierBadge.Position = UDim2.new(1, -132, 0, 13); tierBadge.Size = UDim2.fromOffset(76, 30); tierBadge.TextSize = 11
		close.Position = UDim2.new(1, -48, 0, 7); close.Size = UDim2.fromOffset(40, 40)
		headerRule.Position = UDim2.fromOffset(12, 60); headerRule.Size = UDim2.new(1, -24, 0, 1)
		list.Position = UDim2.fromOffset(10, 70); list.Size = UDim2.new(1, -20, 1, -134)
		statusCard.Position = UDim2.new(0, 10, 1, -56); statusCard.Size = UDim2.new(1, -20, 0, 48)
		statusDot.Position = UDim2.fromOffset(11, 19); status.Size = UDim2.new(1, -38, 1, -4); status.Position = UDim2.fromOffset(29, 2); status.TextSize = 12
	else
		panel.Size = UDim2.fromOffset(900, 720)
		responsiveScale.Scale = math.min(math.clamp(math.min(available.X / 1280, available.Y / 800), 1.05, 2.2), (available.X - 34) / 900, (available.Y - 28) / 720)
		headerIcon.Size = UDim2.fromOffset(52, 52); headerIcon.Position = UDim2.fromOffset(20, 16)
		eyebrow.Position = UDim2.fromOffset(88, 14); eyebrow.TextSize = 12
		title.Position = UDim2.fromOffset(88, 31); title.Size = UDim2.new(1, -220, 0, 34); title.TextSize = 26
		tierBadge.Position = UDim2.new(1, -154, 0, 24); tierBadge.Size = UDim2.fromOffset(92, 34); tierBadge.TextSize = 13
		close.Position = UDim2.new(1, -56, 0, 18); close.Size = UDim2.fromOffset(42, 42)
		headerRule.Position = UDim2.fromOffset(20, 80); headerRule.Size = UDim2.new(1, -40, 0, 1)
		list.Position = UDim2.fromOffset(18, 94); list.Size = UDim2.new(1, -36, 1, -176)
		statusCard.Position = UDim2.new(0, 18, 1, -70); statusCard.Size = UDim2.new(1, -36, 0, 54)
		statusDot.Position = UDim2.fromOffset(14, 22); status.Size = UDim2.new(1, -46, 1, -4); status.Position = UDim2.fromOffset(34, 2); status.TextSize = 13
	end
	responsiveScale:SetAttribute("TargetScale", responsiveScale.Scale)
	render(true)
end)

remote.OnClientEvent:Connect(function(action, first, second)
	if action == "State" or action == "Open" then
		state = first
		updateDefenseHUD(state)
		if action == "Open" then setOpen(true) end
		render(action == "Open")
	elseif action == "Result" then
		requests:Resolve()
		setStatus(second or (first and "Project records updated." or "That action is not available yet."), first and "Success" or "Danger")
	end
end)
remote:FireServer("State")
