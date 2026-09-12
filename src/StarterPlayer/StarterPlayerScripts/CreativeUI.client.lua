-- Creative-world field console. Every command is authorized by the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Theme = require(RS:WaitForChild("Shared").UI.UITheme)
local Items = require(RS.Shared.Items.ItemDatabase)
if require(RS.Shared.SessionConfig).GetMode() ~= "Expedition" then return end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CreativeUI"
gui.ResetOnSpawn = false
-- Keep the mode switch reachable above death/spectator overlays.
gui.DisplayOrder = 125
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
Theme.TrackRoot(gui)

local function button(parent, text, size, position, callback, primary)
	local b = Instance.new("TextButton")
	b.Name = text
	b.Text, b.Font, b.TextSize = text, Enum.Font.GothamBold, 15
	b.Size, b.Position = size, position or UDim2.new()
	b.Parent = parent
	Theme.Button(b, primary == true)
	if callback then b.Activated:Connect(callback) end
	return b
end
local function box(parent, placeholder, value, size, position)
	local input = Instance.new("TextBox")
	input.Size, input.Position = size, position or UDim2.new()
	input.Text, input.PlaceholderText = value or "", placeholder
	input.ClearTextOnFocus, input.TextSize, input.Font = false, 16, Enum.Font.Gotham
	input.BorderSizePixel = 0
	Theme.Bind(input, "BackgroundColor3", "SlotEmpty")
	Theme.Bind(input, "TextColor3", "Text")
	Theme.Bind(input, "PlaceholderColor3", "TextMuted")
	Theme.Corner(input, 6)
	input.Parent = parent
	return input
end
local panel = Instance.new("Frame")
panel.Name = "CreativeConsole"
panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
panel.Visible = false
panel.Parent = gui
Theme.Panel(panel)
Theme.CaptureCursor(panel)
local title = Theme.Label(panel, "CREATIVE FIELD KIT", UDim2.new(1,-220,0,28), UDim2.fromOffset(16,12), 21,nil,true)
local modeButton
local close = button(panel,"×",UDim2.fromOffset(44,44),UDim2.new(1,-52,0,6),function() panel.Visible=false end)
close.TextSize = 28
local notice = Theme.Label(panel,"No class XP or Field Marks in this world.",UDim2.new(1,-32,0,28),UDim2.new(0,16,1,-32),14)
notice.TextWrapped, notice.TextTruncate = true, Enum.TextTruncate.None
local content = Instance.new("Frame")
content.Name, content.BackgroundTransparency = "Content", 1
content.Position, content.Size = UDim2.fromOffset(16,104), UDim2.new(1,-32,1,-146)
content.Parent = panel

local state, pending = {}, false
local requestSerial = 0
local refreshWorld, renderItems, showPage
local function message(text, success)
	notice.Text = text
	Theme.Bind(notice,"TextColor3",success == false and "Danger" or "TextMuted")
end
local function request(action, payload, source, after)
	if pending then message("Please wait for the current action to finish.");return end
	local remote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("CreativeAction")
	if not remote then message("Creative controls are still loading. Try again shortly.",false);return end
	pending = true
	requestSerial += 1
	local serial = requestSerial
	local previous = source and source.Text
	if source then source.Text="…" end
	message(action == "State" and "Loading world controls…" or "Applying…")
	task.delay(10,function()
		if pending and requestSerial==serial then message("Still waiting for the server. You can close this menu while it finishes.") end
	end)
	-- RemoteFunction requests run off the input callback so menus remain responsive.
	task.spawn(function()
		local ok, result = pcall(function() return remote:InvokeServer(action,payload or {}) end)
		pending = false
		if source and source.Parent then source.Text=previous end
		if not ok or type(result) ~= "table" then message("The server could not confirm this action. Try again.",false);return end
		if type(result.State) == "table" then state=result.State end
		modeButton.Text = (state.Mode or (player:GetAttribute("CreativeMode") and "Creative" or "Survival")) .. " ↔"
		if refreshWorld then refreshWorld() end
		message(result.Message or (result.Success and "Done." or "Unable to apply this action."),result.Success)
		if after then after(result) end
	end)
end
modeButton = button(panel,"Creative ↔",UDim2.fromOffset(130,44),UDim2.new(1,-190,0,6),function()
	local creative = player:GetAttribute("CreativeMode") == true
	request("SetMode",{Mode=creative and "Survival" or "Creative"},modeButton)
end,true)

local itemsPage = Instance.new("Frame")
itemsPage.Name, itemsPage.Size, itemsPage.BackgroundTransparency = "Items", UDim2.fromScale(1,1),1
itemsPage.Parent = content
local worldPage = Instance.new("ScrollingFrame")
worldPage.Name = "World"
worldPage.Size, worldPage.BackgroundTransparency = UDim2.fromScale(1,1),1
worldPage.BorderSizePixel, worldPage.ScrollBarThickness = 0,5
worldPage.CanvasSize, worldPage.AutomaticCanvasSize = UDim2.new(),Enum.AutomaticSize.Y
worldPage.ScrollingDirection = Enum.ScrollingDirection.Y
worldPage.Visible = false
worldPage.Parent = content
local worldLayout=Instance.new("UIListLayout")
worldLayout.Padding, worldLayout.SortOrder = UDim.new(0,10),Enum.SortOrder.LayoutOrder
worldLayout.Parent=worldPage

local itemsTab, worldTab
itemsTab=button(panel,"ITEMS",UDim2.new(.5,-20,0,40),UDim2.fromOffset(16,56),function() showPage("Items") end,true)
worldTab=button(panel,"WORLD CONTROLS",UDim2.new(.5,-20,0,40),UDim2.new(.5,4,0,56),function() showPage("World") end)
local category="All"
local categories={"All","Resources","Tools","Weapons","Armor","Food","Medical","Stations & builds","Other"}
local categoryRules={Resources={"Resource"},Tools={"Tool"},Weapons={"Weapon"},Armor={"Armor"},Food={"Food"},Medical={"Medical","Healing"},["Stations & builds"]={"Placeable"}}
local categoryGlyph={All="Pack",Resources="Mineral",Tools="Harvest",Weapons="Attack",Armor="Shield",Food="Food",Medical="Health",["Stations & builds"]="Build",Other="Survey"}
local function matchesCategory(item, selected)
	if selected=="All" then return true end
	if selected=="Other" then
		for _,tags in pairs(categoryRules) do for _,tag in ipairs(tags) do if item:HasTag(tag) then return false end end end
		return true
	end
	for _,tag in ipairs(categoryRules[selected] or {}) do if item:HasTag(tag) then return true end end
	return false
end
local search=box(itemsPage,"Search items…","",UDim2.new(.62,-4,0,40))
local categoryButton
local categoryPicker=Instance.new("ScrollingFrame")
categoryPicker.Name="Categories"
categoryPicker.BackgroundTransparency=0
categoryPicker.BorderSizePixel=0
categoryPicker.ScrollBarThickness=5
categoryPicker.Size,categoryPicker.Position=UDim2.fromScale(1,1),UDim2.new()
categoryPicker.CanvasSize,categoryPicker.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.Y
categoryPicker.ScrollingDirection=Enum.ScrollingDirection.Y
categoryPicker.ZIndex,categoryPicker.Visible=10,false
categoryPicker.Parent=content
Theme.Bind(categoryPicker,"BackgroundColor3","Panel")
Theme.Corner(categoryPicker,8)
local categoryLayout=Instance.new("UIListLayout")
categoryLayout.Padding,categoryLayout.SortOrder=UDim.new(0,6),Enum.SortOrder.LayoutOrder
categoryLayout.Parent=categoryPicker
categoryButton=button(itemsPage,"All ▾",UDim2.new(.38,-4,0,40),UDim2.new(.62,4,0,0),function() categoryPicker.Visible=true end)
for i,name in ipairs(categories) do
	local b=button(categoryPicker,name,UDim2.new(1,-8,0,44),nil,function()
		category=name;categoryButton.Text=name.." ▾";categoryPicker.Visible=false;renderItems()
	end)
	b.LayoutOrder,b.ZIndex=i,11
end

local catalog=Instance.new("ScrollingFrame")
catalog.Name="Catalog"
catalog.Position,catalog.Size=UDim2.fromOffset(0,48),UDim2.new(1,0,1,-98)
catalog.BackgroundTransparency,catalog.BorderSizePixel,catalog.ScrollBarThickness=1,0,5
catalog.CanvasSize,catalog.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.Y
catalog.ScrollingDirection=Enum.ScrollingDirection.Y
catalog.Parent=itemsPage
local grid=Instance.new("UIGridLayout")
grid.CellPadding,grid.SortOrder=UDim2.fromOffset(8,8),Enum.SortOrder.LayoutOrder
grid.Parent=catalog
local empty=Theme.Label(itemsPage,"No matching items",UDim2.new(1,0,0,40),UDim2.fromOffset(0,65),18)
empty.TextXAlignment,empty.Visible=Enum.TextXAlignment.Center,false
local quantityLabel=Theme.Label(itemsPage,"QUANTITY",UDim2.fromOffset(92,40),UDim2.new(0,0,1,-42),13,nil,true)
local quantity=box(itemsPage,"1–999","1",UDim2.fromOffset(80,40),UDim2.new(0,92,1,-42))
local giveHint=Theme.Label(itemsPage,"Tap an item to add it to your pack.",UDim2.new(1,-190,0,40),UDim2.new(0,184,1,-42),14)
giveHint.TextWrapped=true
local allItems=Items:All()
table.sort(allItems,function(a,b) return a.Name<b.Name end)
renderItems=function()
	for _,child in ipairs(catalog:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	local query=string.lower(search.Text)
	local count=0
	for _,item in ipairs(allItems) do
		if matchesCategory(item,category) and (query=="" or string.find(string.lower(item.Name.." "..item.Id.." "..table.concat(item.Tags," ")),query,1,true)) then
			count+=1
			local card
			card=button(catalog,"",UDim2.new(),nil,function()
				local amount=tonumber(quantity.Text)
				if not amount or amount%1~=0 or amount<1 or amount>999 then message("Choose a whole quantity from 1 to 999.",false);return end
				request("GiveItem",{Id=item.Id,Quantity=amount},nil,function(result)
					if result.Success then message(result.Message or ("Added "..amount.." × "..item.Name)) end
				end)
			end)
			card.Name,card.LayoutOrder=item.Id,count
			if item.Icon and item.Icon~="" then
				local image=Instance.new("ImageLabel");image.BackgroundTransparency=1;image.Size=UDim2.fromOffset(36,36);image.AnchorPoint=Vector2.new(.5,0);image.Position=UDim2.new(.5,0,0,9);image.Image=item.Icon;image.ScaleType=Enum.ScaleType.Fit;image.Parent=card
			else
				local glyph="Pack"
				for _,name in ipairs(categories) do if name~="All" and matchesCategory(item,name) then glyph=categoryGlyph[name];break end end
				local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Size=UDim2.fromOffset(36,36);holder.AnchorPoint=Vector2.new(.5,0);holder.Position=UDim2.new(.5,0,0,8);holder.Parent=card;Theme.Icon(holder,glyph,30)
			end
			local label=Theme.Label(card,item.Name,UDim2.new(1,-12,1,-48),UDim2.fromOffset(6,46),14,nil,true)
			label.TextWrapped,label.TextTruncate,label.TextXAlignment=true,Enum.TextTruncate.None,Enum.TextXAlignment.Center
		end
	end
	empty.Visible=count==0
	catalog.CanvasPosition=Vector2.zero
end
search:GetPropertyChangedSignal("Text"):Connect(function() if renderItems then renderItems() end end)

-- Selectors use a separate page, never a scroll box nested inside another.
local selection=Instance.new("ScrollingFrame")
selection.Name,selection.BackgroundTransparency="Selector",0
selection.BorderSizePixel,selection.ScrollBarThickness=0,5
selection.Size,selection.CanvasSize,selection.AutomaticCanvasSize=UDim2.fromScale(1,1),UDim2.new(),Enum.AutomaticSize.Y
selection.ScrollingDirection,selection.ZIndex,selection.Visible=Enum.ScrollingDirection.Y,10,false
selection.Parent=content
Theme.Bind(selection,"BackgroundColor3","Panel")
local selectLayout=Instance.new("UIListLayout");selectLayout.Padding=UDim.new(0,6);selectLayout.SortOrder=Enum.SortOrder.LayoutOrder;selectLayout.Parent=selection
local function selectFrom(entries, callback)
	for _,child in ipairs(selection:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	local back=button(selection,"‹ BACK",UDim2.new(1,-8,0,44),nil,function() selection.Visible=false end);back.ZIndex=11;back.LayoutOrder=0
	for i,entry in ipairs(entries or {}) do
		local b=button(selection,entry.Name or entry.Id,UDim2.new(1,-8,0,44),nil,function() selection.Visible=false;callback(entry) end)
		b.ZIndex,b.LayoutOrder=11,i
	end
	selection.CanvasPosition=Vector2.zero;selection.Visible=true
end
local rowIndex=0
local function worldRow(name, height)
	rowIndex+=1
	local row=Instance.new("Frame");row.Name=name;row.BackgroundTransparency=1;row.Size=UDim2.new(1,-10,0,height or 86);row.LayoutOrder=rowIndex;row.Parent=worldPage
	Theme.Label(row,name,UDim2.new(1,0,0,26),UDim2.new(),16,nil,true)
	return row
end
local biomeRow=worldRow("BIOME / WEATHER")
local biomeButton,weatherButton
biomeButton=button(biomeRow,"Choose biome",UDim2.new(.5,-4,0,44),UDim2.fromOffset(0,32),function()
	selectFrom(state.Biomes,function(entry) request("SetBiome",{Id=entry.Id},biomeButton) end)
end)
weatherButton=button(biomeRow,"Choose weather",UDim2.new(.5,-4,0,44),UDim2.new(.5,4,0,32),function()
	selectFrom(state.Weather,function(entry) request("SetWeather",{Id=entry.Id},weatherButton) end)
end)
local function numberRow(name,defaultValue,placeholder,action,key)
	local row=worldRow(name)
	local input=box(row,placeholder,defaultValue,UDim2.new(.65,-4,0,44),UDim2.fromOffset(0,32))
	local apply
	apply=button(row,"APPLY",UDim2.new(.35,-4,0,44),UDim2.new(.65,4,0,32),function()
		local value=tonumber(input.Text)
		if not value then message("Enter a valid number.",false);return end
		request(action,{[key]=value},apply)
	end,true)
	return input
end
local clockInput=numberRow("TIME OF DAY · 0–24 HOURS","12","Hour","SetTime","Hour")
local shiftInput=numberRow("NEXT SHIFT · 5–3600 SECONDS","300","Seconds","SetShiftTimer","Seconds")
local vitalsRow=worldRow("VITALS")
local invincibleButton,restoreButton
invincibleButton=button(vitalsRow,"Invincible: ON",UDim2.new(.5,-4,0,44),UDim2.fromOffset(0,32),function()
	request("SetInvincible",{Enabled=player:GetAttribute("CreativeInvincible")~=true},invincibleButton)
end)
restoreButton=button(vitalsRow,"RESTORE VITALS",UDim2.new(.5,-4,0,44),UDim2.new(.5,4,0,32),function() request("RestoreVitals",{},restoreButton) end,true)
local monsterRow=worldRow("MONSTERS · COUNT / LEVEL",144)
local selectedMonster,monsterButton
monsterButton=button(monsterRow,"Choose monster",UDim2.new(1,0,0,44),UDim2.fromOffset(0,32),function()
	selectFrom(state.Monsters,function(entry) selectedMonster=entry.Id;monsterButton.Text=entry.Name or entry.Id end)
end)
local monsterCount=box(monsterRow,"Count 1–10","1",UDim2.new(.25,-4,0,44),UDim2.fromOffset(0,84))
local monsterLevel=box(monsterRow,"Level 1–25","1",UDim2.new(.25,-4,0,44),UDim2.new(.25,4,0,84))
local spawnButton
spawnButton=button(monsterRow,"SPAWN",UDim2.new(.5,-12,0,44),UDim2.new(.5,12,0,84),function()
	if not selectedMonster then message("Choose a monster first.",false);return end
	local count,level=tonumber(monsterCount.Text),tonumber(monsterLevel.Text)
	if not count or not level or count%1~=0 or level%1~=0 or count<1 or count>10 or level<1 or level>25 then message("Use a count of 1–10 and a level of 1–25.",false);return end
	request("SpawnMonster",{Id=selectedMonster,Count=count,Level=level},spawnButton)
end,true)
local travelRow=worldRow("WORLD UTILITIES")
local clearButton,travelButton
clearButton=button(travelRow,"CLEAR MONSTERS",UDim2.new(.5,-4,0,44),UDim2.fromOffset(0,32),function() request("ClearMonsters",{},clearButton) end)
travelButton=button(travelRow,"RETURN TO SPAWN",UDim2.new(.5,-4,0,44),UDim2.new(.5,4,0,32),function() request("TeleportSpawn",{},travelButton) end)
refreshWorld=function()
	invincibleButton.Text="Invincible: "..(player:GetAttribute("CreativeInvincible") and "ON" or "OFF")
	for _,entry in ipairs(state.Biomes or {}) do if entry.Id==state.Biome then biomeButton.Text=entry.Name.." ▾";break end end
	for _,entry in ipairs(state.Weather or {}) do if entry.Id==state.CurrentWeather then weatherButton.Text=entry.Name.." ▾";break end end
	if state.Time and not clockInput:IsFocused() then clockInput.PlaceholderText=string.format("Now %.1f",state.Time) end
	if state.ShiftSeconds and not shiftInput:IsFocused() then shiftInput.PlaceholderText="Now "..math.ceil(state.ShiftSeconds).."s" end
end
showPage=function(page)
	categoryPicker.Visible,selection.Visible=false,false
	itemsPage.Visible,worldPage.Visible=page=="Items",page=="World"
	Theme.Bind(itemsTab,"BackgroundColor3",page=="Items" and "Moss" or "SlotEmpty")
	Theme.Bind(worldTab,"BackgroundColor3",page=="World" and "Moss" or "SlotEmpty")
end

local trigger=button(gui,"",UDim2.fromOffset(46,46),UDim2.new(.5,0,0,8),function()
	panel.Visible=not panel.Visible
	if panel.Visible then request("State",{}) end
end)
trigger.Name="OpenCreativeConsole"
Theme.TouchIcon(trigger,"Build",29)
local triggerLabel=Theme.Label(trigger,"CREATIVE",UDim2.fromOffset(86,18),UDim2.new(.5,-43,1,2),10,nil,true)
triggerLabel.TextXAlignment=Enum.TextXAlignment.Center
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	trigger.Visible=not panel.Visible
end)
local function eligibility()
	gui.Enabled=workspace:GetAttribute("WorldType")=="Creative"
	if not gui.Enabled then panel.Visible=false end
	modeButton.Text=(player:GetAttribute("CreativeMode") and "Creative" or "Survival").." ↔"
	refreshWorld()
end
workspace:GetAttributeChangedSignal("WorldType"):Connect(eligibility)
player:GetAttributeChangedSignal("CreativeMode"):Connect(eligibility)
player:GetAttributeChangedSignal("CreativeInvincible"):Connect(refreshWorld)
UIS.InputBegan:Connect(function(input,processed)
	if not processed and panel.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then
		if selection.Visible then selection.Visible=false elseif categoryPicker.Visible then categoryPicker.Visible=false else panel.Visible=false end
	end
end)
Theme.BindResponsive(gui,function(mobile,viewport)
	local width=math.min(1040,viewport.X-24)
	local height=math.min(760,viewport.Y-20)
	panel.Size=UDim2.fromOffset(width,height)
	title.TextSize=width<560 and 16 or 21
	title.Text=width<500 and "CREATIVE KIT" or "CREATIVE FIELD KIT"
	local columns=math.max(2,math.floor((width-40)/132))
	grid.CellSize=UDim2.new(1/columns,-(8+(5/columns)),0,mobile and 100 or 112)
	trigger.AnchorPoint=Vector2.new(1,0)
	trigger.Position=UDim2.new(1,-12,0,mobile and 122 or 10)
	giveHint.TextSize=width<500 and 12 or 14
end)
eligibility()
renderItems()
