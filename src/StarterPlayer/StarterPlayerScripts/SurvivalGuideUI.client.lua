local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode() ~= "Expedition" then return end
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Theme = require(Shared.UI.UITheme)
local Settings = require(Shared.ClientSettings)
local Guide = require(Shared.SurvivalGuide)
local Biomes = require(Shared.BiomeConfig)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SurvivalGuideUI", false, 115
gui.ZIndexBehavior, gui.Parent = Enum.ZIndexBehavior.Sibling, player:WaitForChild("PlayerGui")
local function button(parent, name, text, x, y, width, height)
	local b = Instance.new("TextButton")
	b.Name, b.Text = name, text
	b.Size, b.Position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
	b.Font, b.TextSize, b.Parent = Enum.Font.GothamBold, Theme.IsMobile() and 15 or 12, parent
	Theme.Button(b, false)
	return b
end
local function panel(name, width, height)
	local f = Instance.new("Frame")
	f.Name, f.Size = name, UDim2.fromOffset(width, height)
	f.AnchorPoint, f.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	f.Visible, f.Parent = false, gui
	Theme.Panel(f); Theme.CaptureCursor(f); Theme.AnimatePanel(f)
	return f
end
local function label(parent, text, y, height, size, bold)
	local l = Theme.Label(parent, text, UDim2.new(1, -44, 0, height), UDim2.fromOffset(22, y), size or 12, nil, bold)
	l.TextWrapped, l.TextTruncate, l.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
	return l
end
local field = panel("SurvivalFieldGuide", 620, 590)
label(field, "SURVIVAL FIELD GUIDE", 16, 20, 11, true)
local title = label(field, "Surveying world...", 42, 36, 24, true)
title.Size = UDim2.new(1, -90, 0, 36)
local close = button(field, "CloseGuide", "X", 568, 16, 30, 30)
local biomeTab = button(field, "BiomeTab", "Biome", 22, 86, 280, 32)
local conditionTab = button(field, "ConditionsTab", "Conditions", 312, 86, 286, 32)
local scroll = Instance.new("ScrollingFrame")
scroll.Name, scroll.Size, scroll.Position = "Advice", UDim2.fromOffset(576, 404), UDim2.fromOffset(22, 130)
scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 5
scroll.AutomaticCanvasSize, scroll.CanvasSize, scroll.Parent = Enum.AutomaticSize.Y, UDim2.new(), field
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, scroll
label(field, "Gear reduces exposure; it does not guarantee safety. Regions and events can add hazards.", 549, 32, 11)
local state, tab, signature, order = {}, "Biome", nil, 0
local function row(text, heading)
	local l = Theme.Label(scroll, text, UDim2.new(1, -14, 0, 0), UDim2.new(), heading and 16 or (Theme.IsMobile() and 15 or 12), nil, heading)
	l.AutomaticSize, l.TextWrapped, l.TextTruncate = Enum.AutomaticSize.Y, true, Enum.TextTruncate.None
	l.TextYAlignment = Enum.TextYAlignment.Top
	order += 1; l.LayoutOrder = order
	return l
end
local function openRecipe(id)
	field.Visible = false
	require(Shared.UI.RecipeGuideUI).Open(id)
end
local function render()
	if not field.Visible then return end
	for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	order = 0
	Theme.Bind(biomeTab, "BackgroundColor3", tab == "Biome" and "SlotSelected" or "SlotEmpty")
	Theme.Bind(conditionTab, "BackgroundColor3", tab == "Conditions" and "SlotSelected" or "SlotEmpty")
	local biome, weatherId = state.Biome, state.WeatherId
	local info = Guide.Biomes[biome]
	if not info then title.Text = "Surveying world..."; row("Waiting for current expedition conditions."); return end
	local weather = Guide.Weather(biome, weatherId)
	local biomeName = state.BiomeDisplayName or Biomes.biome_metadata[biome].DisplayName
	title.Text = tab == "Biome" and biomeName or (weather and weather.Name or "Conditions updating...")
	row(tab == "Biome" and info.Summary or (biomeName .. " + " .. (weather and weather.Name or "current weather")))
	if tab == "Conditions" and weather then
		local changes = {}
		if weather.Temp > 0 then table.insert(changes, "adds heat") elseif weather.Temp < 0 then table.insert(changes, "adds cold") end
		if weather.Toxin > 0 then table.insert(changes, "adds toxins") end
		if weather.Wet > 0 then table.insert(changes, "adds wetness") end
		row(#changes > 0 and ("This weather " .. table.concat(changes, ", ") .. ".") or "This weather adds no extra exposure. The biome's hazards still apply.")
	end
	row("CURRENT COMBINED HAZARDS", true)
	row(Guide.Hazards(Guide.Exposure(biome, weatherId)))
	local equipped = player:GetAttribute("EquippedArmor")
	row("YOUR ARMOR: " .. (equipped and Guide.Name(equipped) or "None"), true)
	row(Guide.ArmorText(equipped))
	local armor, tools = Guide.Recommendations(biome, weatherId, tab == "Conditions")
	local function equipment(heading, ids)
		row(heading, true)
		for _, id in ipairs(ids) do
			local b = button(scroll, id, Guide.Name(id) .. (equipped == id and "  /  EQUIPPED" or "  /  RECIPE >"), 0, 0, 554, 36)
			b.Size = UDim2.new(1, -14, 0, Theme.IsMobile() and 48 or 36)
			order += 1; b.LayoutOrder = order
			b.Activated:Connect(function() openRecipe(id) end)
			row(heading == "ARMOR OPTIONS" and Guide.ArmorText(id) or "Optional support. Open for materials and crafting stations.")
		end
	end
	equipment("ARMOR OPTIONS", armor)
	equipment("TOOLS & SUPPLIES", tools)
	row("Equip one armor item in your Pack's armor slot. Carrying it in storage gives no protection. Gathering tools help collect materials; they do not protect against weather.")
	if state.UpcomingBiome then row("Forecast: " .. (Biomes.biome_metadata[state.UpcomingBiome] and Biomes.biome_metadata[state.UpcomingBiome].DisplayName or state.UpcomingBiome)) end
	if state.UpcomingWeather then row("Next conditions: " .. state.UpcomingWeather) end
end
local tutorial = panel("StartingTutorial", 540, 380)
label(tutorial, "FIRST EXPEDITION  /  THE ESSENTIALS", 18, 20, 11, true)
local stepTitle = label(tutorial, "", 50, 60, 23, true)
local stepBody = label(tutorial, "", 114, 130, 14)
local stepCount = label(tutorial, "", 256, 24, 11)
local back = button(tutorial, "PreviousStep", "Back", 22, 291, 90, 34)
local recipe = button(tutorial, "SunwrapRecipe", "Sunwrap recipe", 122, 291, 174, 34)
local nextStep = button(tutorial, "NextStep", "Next", 306, 291, 212, 34)
local dismiss = button(tutorial, "SkipTutorial", "Skip", 442, 14, 76, 28)
local disable = button(tutorial, "DisableStartingTutorial", "Don't show at start again", 22, 338, 300, 26)
local step = 1
local function renderTutorial()
	local entries = {
		{ "1. Gather while the Forest is mild", "Walk up to resources and hold the on-screen gather prompt. Collect Reed Fiber, Moss Bloom and Sap Resin for your first heat armor. Keep food and Bandages ready." },
		{ "2. Make a Reed Sunwrap", Guide.RecipeText("ReedSunwrap") .. ".\n" .. (Theme.IsMobile() and "Tap Craft, craft by hand, then tap Pack and equip it in the armor slot." or "Open Craft (" .. Settings.Key("Craft").Name .. "), craft by hand, then open Pack (" .. Settings.Key("Pack").Name .. ") and equip it in the armor slot.") .. " It reduces heat exposure by 70%. Desert is an early possible shift; prepare before it arrives." },
		{ "3. Watch food and exposure", "Eat before Hunger reaches zero. Extreme hot or cold exposure damages health. Sprint uses energy; stop to recover. Click the biome or conditions on your HUD for protection advice. A Field Clock reveals shift timing; stronger weather may need better gear." },
	}
	stepTitle.Text, stepBody.Text = entries[step][1], entries[step][2]
	stepCount.Text = step .. " / 3  ·  The world keeps running while you read."
	back.Visible, recipe.Visible = step > 1, step == 2
	nextStep.Text = step == 3 and "Ready to survive" or "Next"
end
local function showTutorial()
	field.Visible = false; step = 1; renderTutorial(); tutorial.Visible = true
end
local function showGuide(which)
	tutorial.Visible = false; tab = which; scroll.CanvasPosition = Vector2.zero; field.Visible = true; render()
end
biomeTab.Activated:Connect(function() showGuide("Biome") end)
conditionTab.Activated:Connect(function() showGuide("Conditions") end)
close.Activated:Connect(function() field.Visible = false end)
back.Activated:Connect(function() step = math.max(1, step - 1); renderTutorial() end)
nextStep.Activated:Connect(function() if step == 3 then tutorial.Visible = false else step += 1; renderTutorial() end end)
dismiss.Activated:Connect(function() tutorial.Visible = false end)
disable.Activated:Connect(function() Settings.Set("StartingTutorial", false); Settings.Save(); tutorial.Visible = false end)
recipe.Activated:Connect(function() tutorial.Visible = false; openRecipe("ReedSunwrap") end)
player:GetAttributeChangedSignal("FieldGuideBiome"):Connect(function() showGuide("Biome") end)
player:GetAttributeChangedSignal("FieldGuideConditions"):Connect(function() showGuide("Conditions") end)
player:GetAttributeChangedSignal("ReplaySurvivalTutorial"):Connect(showTutorial)
player:GetAttributeChangedSignal("EquippedArmor"):Connect(render)
Settings.Changed:Connect(function() if tutorial.Visible then renderTutorial() end end)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and Settings.CanInput() and input.KeyCode == Enum.KeyCode.Escape then field.Visible = false; tutorial.Visible = false end
end)
player:GetAttributeChangedSignal("IsDead"):Connect(function()
	if player:GetAttribute("IsDead") then field.Visible = false; tutorial.Visible = false end
end)
local started = false
local function tryStart()
	if started or not state.Biome then return end
	if player:GetAttribute("ProfileLoaded") ~= true and player:GetAttribute("ProfileStatus") ~= "Unavailable" then return end
	if player:GetAttribute("ProfileLoaded") == true and player:GetAttribute("PersonalSettings") == nil then return end
	if player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") or RS:GetAttribute("WorldRestoring") then return end
	if player:GetAttribute("IsDead") or not player.Character then return end
	started = true
	if Settings.Get("StartingTutorial") then showTutorial() end
end
player:GetAttributeChangedSignal("ProfileLoaded"):Connect(tryStart)
player:GetAttributeChangedSignal("ProfileStatus"):Connect(tryStart)
Settings.Changed:Connect(tryStart)
player.CharacterAdded:Connect(function() task.defer(tryStart) end)
local remote = RS:WaitForChild("Remotes"):WaitForChild("GameStateUpdate")
remote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	state = payload
	local nextSignature = table.concat({ state.Biome or "", state.WeatherId or "", state.UpcomingBiome or "", state.UpcomingWeather or "" }, ":")
	if nextSignature ~= signature then signature = nextSignature; render() end
	tryStart()
end)
remote:FireServer("RequestState")

Theme.FitMenu(field,620,590,{MobileWidth=360,OnResize=function(width,_,mobile)
	close.Visible = not mobile
	if not mobile then return end
	close.Position=UDim2.new(1,-62,0,12); close.Size=UDim2.fromOffset(44,44)
	biomeTab.Size=UDim2.new(.5,-27,0,44)
	conditionTab.Position=UDim2.new(.5,5,0,86); conditionTab.Size=UDim2.new(.5,-27,0,44)
	scroll.Position=UDim2.fromOffset(22,142); scroll.Size=UDim2.new(1,-44,0,390)
	for _,child in ipairs(field:GetChildren()) do
		if child:IsA("TextLabel") and child.Position.Y.Offset==549 then child.TextSize=14; child.Size=UDim2.new(1,-44,0,40) end
	end
end})
Theme.FitMenu(tutorial,540,380,{MobileWidth=360,MobileHeight=590,OnResize=function(width,_,mobile)
	dismiss.Visible = not mobile
	if not mobile then return end
	dismiss.Position=UDim2.new(1,-98,0,12); dismiss.Size=UDim2.fromOffset(76,44)
	stepTitle.Position=UDim2.fromOffset(22,70); stepTitle.Size=UDim2.new(1,-44,0,66)
	stepBody.Position=UDim2.fromOffset(22,144); stepBody.Size=UDim2.new(1,-44,0,250); stepBody.TextSize=16
	stepCount.Position=UDim2.fromOffset(22,400); stepCount.Size=UDim2.new(1,-44,0,42); stepCount.TextSize=14
	back.Position=UDim2.fromOffset(22,448); back.Size=UDim2.new(.3,-27,0,46)
	recipe.Position=UDim2.new(.3,0,0,448); recipe.Size=UDim2.new(.7,-22,0,46)
	nextStep.Position=UDim2.fromOffset(22,502); nextStep.Size=UDim2.new(1,-44,0,46)
	disable.Position=UDim2.fromOffset(22,550); disable.Size=UDim2.new(1,-44,0,36)
	for _,child in ipairs(tutorial:GetChildren()) do
		if child:IsA("TextLabel") and child.Position.Y.Offset==18 then child.Size=UDim2.new(1,-130,0,38); child.TextSize=14 end
	end
end})
