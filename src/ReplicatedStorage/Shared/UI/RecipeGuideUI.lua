-- Client-only recursive recipe book, shared by hand crafting and station panels.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.UITheme)
local Resolver = require(script.Parent.Parent:WaitForChild("RecipeGuide"))
local Recipes = require(script.Parent.Parent.WorkbenchConfig)
local Items = require(script.Parent.Parent.Items.ItemDatabase)
local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Util)
local Messages = require(script.Parent.Parent.ResultMessages).Craft
local player = Players.LocalPlayer
local colors = Theme.Colors
local remoteFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local craftRemote = remoteFolder and Util.GetRemote(remoteFolder, Config.RemoteNames.Craft)
local inventoryRemote = remoteFolder and Util.GetRemote(remoteFolder, Config.RemoteNames.InventoryUpdate)
local Guide = {}
local stack, inventory, materialRows, stationRows = {}, nil, {}, {}
local preferredStation, activeCraft, render, refresh
local statusRevision = 0
local syncingInput = false

local function create(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function label(parent, text, height, size)
	return create("TextLabel", parent, {
		Size=UDim2.new(1,0,0,height), BackgroundTransparency=1, Text=text,
		TextColor3=colors.Text, TextSize=size or 15, Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, ZIndex=4,
	})
end
local function button(parent, name, text, height)
	local result=create("TextButton",parent,{
		Name=name, Size=UDim2.new(1,0,0,height or 42), BackgroundColor3=colors.SlotEmpty,
		Text=text, TextColor3=colors.Text, TextSize=15, Font=Enum.Font.GothamBold,
		TextWrapped=true, ZIndex=5,
	})
	Theme.Button(result)
	return result
end
local gui=create("ScreenGui",player:WaitForChild("PlayerGui"),{
	Name="RecipeGuideUI",ResetOnSpawn=false,DisplayOrder=70,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Enabled=false,
})
Theme.TrackRoot(gui)
local shade=create("TextButton",gui,{
	Name="Backdrop",Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,
	BackgroundColor3=colors.Night,BackgroundTransparency=.25,BorderSizePixel=0,ZIndex=1,
})
local panel=create("Frame",gui,{
	Name="MainPanel",Size=UDim2.fromOffset(620,670),Position=UDim2.fromScale(.5,.5),
	AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=colors.Panel,ZIndex=2,Active=true,
})
Theme.Panel(panel); Theme.Fit(panel,620,670)
local back=button(panel,"Back","‹ Back",34)
back.Position=UDim2.fromOffset(16,12); back.Size=UDim2.fromOffset(76,34)
local title=label(panel,"Recipe field guide",34,20)
title.Position=UDim2.fromOffset(108,12); title.Size=UDim2.new(1,-174,0,34); title.Font=Enum.Font.GothamBold
local close=button(panel,"Close","×",34)
close.Position=UDim2.new(1,-50,0,12); close.Size=UDim2.fromOffset(34,34)
local trail=create("ScrollingFrame",panel,{
	Name="Breadcrumbs",Position=UDim2.fromOffset(16,54),Size=UDim2.new(1,-32,0,28),
	BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),
	AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ZIndex=4,
})
local trailLayout=create("UIListLayout",trail,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
local search=create("TextBox",panel,{
	Name="RecipeSearch",Position=UDim2.fromOffset(16,88),Size=UDim2.new(1,-32,0,34),
	BackgroundColor3=colors.Background,BorderSizePixel=0,Text="",PlaceholderText="Search recipes, items, or stations",
	TextColor3=colors.Text,PlaceholderColor3=colors.TextMuted,TextSize=16,Font=Enum.Font.Gotham,
	ClearTextOnFocus=false,ZIndex=5,Visible=false,
})
Theme.Corner(search,6)
create("UIPadding",search,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
local content=create("ScrollingFrame",panel,{
	Name="Details",Position=UDim2.fromOffset(16,90),Size=UDim2.new(1,-32,1,-274),
	BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=colors.Border,
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=3,
})
local contentLayout=create("UIListLayout",content,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
create("UIPadding",content,{PaddingRight=UDim.new(0,6),PaddingBottom=UDim.new(0,6)})
local controls=create("Frame",panel,{
	Name="QuantityControls",Position=UDim2.new(0,16,1,-172),Size=UDim2.new(1,-32,0,38),BackgroundTransparency=1,ZIndex=4,
})
local batchCaption=label(controls,"Batches",38,15); batchCaption.Size=UDim2.fromOffset(78,38)
local minus=button(controls,"DecreaseQuantity","−",38); minus.Position=UDim2.fromOffset(82,0); minus.Size=UDim2.fromOffset(38,38)
local quantity=create("TextBox",controls,{
	Name="QuantityInput",Position=UDim2.fromOffset(128,0),Size=UDim2.fromOffset(66,38),BackgroundColor3=colors.Background,
	BorderSizePixel=0,Text="1",TextColor3=colors.Text,TextSize=17,Font=Enum.Font.GothamBold,ClearTextOnFocus=false,ZIndex=5,
})
Theme.Corner(quantity,6)
local plus=button(controls,"IncreaseQuantity","+",38); plus.Position=UDim2.fromOffset(202,0); plus.Size=UDim2.fromOffset(38,38)
local maximum=button(controls,"MaxQuantity","Max (0)",38); maximum.Position=UDim2.fromOffset(250,0); maximum.Size=UDim2.new(1,-250,0,38)
local summary=label(panel,"",20,15); summary.Name="BatchSummary"; summary.Position=UDim2.new(0,16,1,-126); summary.Size=UDim2.new(1,-32,0,20); summary.Font=Enum.Font.GothamBold
local timing=label(panel,"",20,13); timing.Name="BatchTime"; timing.Position=UDim2.new(0,16,1,-104); timing.Size=UDim2.new(1,-32,0,20); timing.TextColor3=colors.TextMuted
local craft=button(panel,"CraftButton","Choose a recipe",48); craft.Position=UDim2.new(0,16,1,-80); craft.Size=UDim2.new(1,-32,0,48)
local progress=create("Frame",craft,{
	Name="CraftProgress",Position=UDim2.new(0,8,1,-8),Size=UDim2.new(1,-16,0,4),BackgroundColor3=colors.Night,
	BorderSizePixel=0,Visible=false,ZIndex=6,
})
Theme.Corner(progress,2)
local fill=create("Frame",progress,{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=colors.Paper,BorderSizePixel=0,ZIndex=7})
Theme.Corner(fill,2)
local status=label(panel,"",20,13); status.Name="Status"; status.Position=UDim2.new(0,16,1,-26); status.Size=UDim2.new(1,-32,0,20)

local function current() return stack[#stack] end
local function itemName(id) local item=Items:Get(id); return item and item.Name or tostring(id) end
local function count(id)
	local n=0
	for _, section in ipairs({"Hotbar","Storage"}) do
		for _, slot in pairs(inventory and inventory[section] or {}) do
			if slot and slot.Id==id then n+=tonumber(slot.N) or 0 end
		end
	end
	return n
end
local function perBatch(ingredient)
	return math.max(1,math.floor((ingredient.N or 1)/math.max(.1,tonumber(player:GetAttribute("Role_Craft")) or 1)))
end
local function costMap(recipe)
	local costs={}
	for _, ingredient in ipairs(recipe.Ingredients or {}) do costs[ingredient.Id]=(costs[ingredient.Id] or 0)+perBatch(ingredient) end
	return costs
end
local function affordable(recipe)
	if not inventory then return 0 end
	local n=99
	for id,needed in pairs(costMap(recipe)) do n=math.min(n,math.floor(count(id)/needed)) end
	return n
end
local function parsedQuantity()
	local n=tonumber(current() and current().QuantityText or "")
	return n and n>=1 and n<=99 and n%1==0 and n or nil
end
local function duration(recipe,station,n)
	local multiplier=Recipes:GetEffectiveStationModifiers(recipe,station)
	return math.max(.05,(tonumber(recipe.BaseCraftTime) or 0)*multiplier)*n
end
local function timeText(seconds)
	if seconds<60 then return string.format("%.1fs",seconds) end
	local n=math.floor(seconds+.5); return string.format("%dm %02ds",math.floor(n/60),n%60)
end
local function outputText(recipe,n)
	local output=recipe.Output
	return string.format("%d × %s",(output.N or 1)*n,itemName(output.Id))
end
local function setEnabled(control,enabled)
	control.Active=enabled; control.Selectable=enabled
	control.TextColor3=enabled and colors.Text or colors.TextMuted
	control.BackgroundTransparency=enabled and 0 or .5
end
local function feedback(message,good)
	statusRevision+=1; local token=statusRevision
	status.Text=message or ""; status.TextColor3=good and colors.Success or colors.Warning
	task.delay(4,function() if token==statusRevision then status.Text="" end end)
end
local function saveScroll()
	local node=current(); if node then node.Scroll=content.CanvasPosition.Y end
end
local function push(itemId,recipeId)
	saveScroll()
	table.insert(stack,{ItemId=itemId,RecipeId=recipeId,QuantityText="1",Scroll=0})
	render()
end
local function goBack()
	if #stack<=1 then gui.Enabled=false; return end
	saveScroll(); table.remove(stack); render()
end

local function updateProgress()
	if not activeCraft then return end
	local elapsed=activeCraft.Confirmed and math.max(0,os.clock()-activeCraft.StartedAt) or 0
	fill.Size=UDim2.fromScale(math.clamp(elapsed/math.max(.05,activeCraft.Duration),0,1),1)
	timing.Text=timeText(math.min(elapsed,activeCraft.Duration)).." / "..timeText(activeCraft.Duration).." total"
end

local function armCraftTimeout(request)
	request.TimeoutToken=(request.TimeoutToken or 0)+1
	local token=request.TimeoutToken
	task.delay(math.max(8,request.Duration+8),function()
		if activeCraft~=request or request.TimeoutToken~=token then return end
		activeCraft=nil
		feedback("Craft request timed out.",false)
		if gui.Enabled then refresh() end
	end)
end

refresh=function()
	local node=current(); if not node then return end
	local recipe=node.RecipeId and Recipes.RECIPES[node.RecipeId]
	local n=parsedQuantity()
	local allowed=recipe and Resolver.GetStations(node.RecipeId,player) or {}
	local station=recipe and Resolver.GetUsableStation(node.RecipeId,player,preferredStation)
	local byId={}; for _, record in ipairs(allowed) do byId[record.Id]=record end
	for _, row in ipairs(stationRows) do
		local info=byId[row.Id]
		if info then
			row.Button.Text=info.Name.." · "..(info.Id=="Hand" and "ALWAYS AVAILABLE" or (info.Nearby and "NEARBY" or "NOT NEARBY"))
				.."\n"..timeText(duration(recipe,info.Id,n or 1)).." total"
				..(info.BuildItemId and " · How to craft this station →" or "")
			row.Button.TextColor3=info.Nearby and colors.Success or colors.Warning
		end
	end
	for _, row in ipairs(materialRows) do
		local needed=row.Cost*(n or 1); local have=count(row.Id)
		row.Button.Text=string.format("%s\n%d owned / %d needed    ·    %s →",itemName(row.Id),have,needed,row.Craftable and "View recipe" or "Where to gather")
		row.Button.TextColor3=have>=needed and colors.Text or colors.Warning
	end
	local max=recipe and affordable(recipe) or 0
	local editable=recipe~=nil and activeCraft==nil
	controls.Visible=recipe~=nil
	quantity.TextEditable=editable
	setEnabled(minus,editable and (not n or n>1))
	setEnabled(plus,editable and n~=nil and n<max)
	setEnabled(maximum,editable and max>0); maximum.Text="Max ("..max..")"
	setEnabled(craft,false)
	progress.Visible=activeCraft~=nil
	if activeCraft then
		local activeRecipe=Recipes.RECIPES[activeCraft.RecipeId]
		summary.Text=(activeRecipe and outputText(activeRecipe,activeCraft.Quantity) or "Current craft").." · in progress"
		craft.Text=activeCraft.Confirmed and "Crafting…" or "Preparing…"
		craft.BackgroundColor3=colors.Accent; craft.TextColor3=colors.Paper
		updateProgress()
		return
	end
	fill.Size=UDim2.fromScale(0,1)
	if not recipe then
		summary.Text=node.Library and "Explore any recipe before building its station" or "Gather this resource in the world"
		timing.Text=""; craft.Text=node.Library and "Choose a recipe above" or "No crafting recipe"
		craft.BackgroundColor3=colors.SlotEmpty
		return
	end
	if not n then
		summary.Text="Enter a whole batch quantity from 1 to 99"; timing.Text=""; craft.Text="Invalid batch quantity"
		craft.BackgroundColor3=colors.SlotEmpty
		return
	end
	summary.Text="Output: "..outputText(recipe,n)
	if station then
		local _,bonus=Recipes:GetEffectiveStationModifiers(recipe,station)
		timing.Text=string.format("%d %s · %s total at %s%s",n,n==1 and "batch" or "batches",
			timeText(duration(recipe,station,n)),Recipes.STATIONS[station].Name,bonus>0 and " · bonus possible" or "")
	else
		timing.Text="Station times: see the allowed stations above"
	end
	local canCraft=station~=nil and n<=max
	setEnabled(craft,canCraft); craft.BackgroundColor3=canCraft and colors.SuccessFill or colors.SlotEmpty
	craft.Text=not station and "Required station not nearby" or (n>max and "Missing materials" or ("Craft "..outputText(recipe,n).." · "..Recipes.STATIONS[station].Name))
	if canCraft then craft.TextColor3=colors.Paper end
end

render=function()
	local node=current(); if not node then return end
	for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	for _,child in ipairs(trail:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	materialRows={}; stationRows={}
	if not node.Library then
		local entry=Resolver.GetEntry(node.ItemId)
		node.RecipeId=node.RecipeId or entry.RecipeId
	end
	for index,crumb in ipairs(stack) do
		local b=button(trail,"Step"..index,(index>1 and "› " or "")..(crumb.Library and "Recipe book" or itemName(crumb.ItemId)),25)
		b.TextSize=13; b.TextWrapped=false; b.LayoutOrder=index
		b.Size=UDim2.fromOffset(math.ceil(TextService:GetTextSize(b.Text,13,b.Font,Vector2.new(2000,25)).X)+16,25)
		create("UIPadding",b,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})
		b.Activated:Connect(function()
			saveScroll(); while #stack>index do table.remove(stack) end; render()
		end)
	end
	back.Text=#stack>1 and "‹ Back" or "‹ Close"
	search.Visible=node.Library==true
	content.Position=UDim2.fromOffset(16,node.Library and 130 or 90)
	content.Size=UDim2.new(1,-32,1,node.Library and -314 or -274)
	syncingInput=true
	quantity.Text=node.QuantityText or "1"
	if node.Library then search.Text=node.Query or "" end
	syncingInput=false
	if node.Library then
		title.Text="Recipe book"
		local ids={}; for id in pairs(Recipes.RECIPES) do table.insert(ids,id) end
		table.sort(ids,function(a,b) local an=itemName(Recipes.RECIPES[a].Output.Id); local bn=itemName(Recipes.RECIPES[b].Output.Id); return an==bn and a<b or an<bn end)
		local query=string.lower(node.Query or ""); local shown=0
		for _,id in ipairs(ids) do
			local recipe=Recipes.RECIPES[id]
			local stationNames={}; for _,s in ipairs(Resolver.GetStations(id,player)) do table.insert(stationNames,s.Name) end
			local text=itemName(recipe.Output.Id).."\n"..table.concat(stationNames," / ")
			if query=="" or string.find(string.lower(text.." "..id),query,1,true) then
				local b=button(content,id,text,54); b.LayoutOrder=shown; shown+=1
				b.Activated:Connect(function() push(recipe.Output.Id,id) end)
			end
		end
		if shown==0 then label(content,"No recipes match this search.",44) end
	else
		local entry=Resolver.GetEntry(node.ItemId)
		title.Text=entry.Name or itemName(node.ItemId)
		local item=Items:Get(node.ItemId)
		if item and item.Description then
			local description=label(content,item.Description,40,15)
			description.AutomaticSize=Enum.AutomaticSize.Y
			description.LayoutOrder=-1
			description.TextColor3=colors.TextMuted
		end
		local recipe=node.RecipeId and Recipes.RECIPES[node.RecipeId]
		if recipe then
			local heading=label(content,"CRAFTING STATION · click to see how to make it",24,14); heading.LayoutOrder=0; heading.TextColor3=colors.TextMuted
			for index,station in ipairs(Resolver.GetStations(node.RecipeId,player)) do
				local b=button(content,"Station_"..station.Id,station.Name,58); b.LayoutOrder=index
				table.insert(stationRows,{Id=station.Id,Button=b})
				if station.BuildItemId then b.Activated:Connect(function() push(station.BuildItemId,station.RecipeId) end) end
			end
			local materialHeading=label(content,"MATERIALS · follow each ingredient to its source",24,14)
			materialHeading.LayoutOrder=100; materialHeading.TextColor3=colors.TextMuted
			local ids={}; local costs=costMap(recipe); for id in pairs(costs) do table.insert(ids,id) end; table.sort(ids)
			for index,id in ipairs(ids) do
				local b=button(content,"Material_"..id,"",60); b.LayoutOrder=100+index
				table.insert(materialRows,{Id=id,Cost=costs[id],Button=b,Craftable=Resolver.GetEntry(id).RecipeId~=nil})
				b.Activated:Connect(function() push(id) end)
			end
		else
			local heading=label(content,"FIELD SOURCE · this material is gathered, not crafted",44,16); heading.LayoutOrder=0; heading.Font=Enum.Font.GothamBold
			for index,source in ipairs(entry.Sources or {}) do
				local row=label(content,type(source)=="string" and source or tostring(source.Text),60,16); row.LayoutOrder=index
				row.AutomaticSize=Enum.AutomaticSize.Y
			end
			if not entry.Sources or #entry.Sources==0 then label(content,"No verified gathering source is recorded for this item.",60,16).LayoutOrder=1 end
		end
	end
	refresh()
	task.defer(function()
		if current()~=node then return end
		content.CanvasPosition=Vector2.new(0,node.Scroll or 0)
		trail.CanvasPosition=Vector2.new(math.max(0,trailLayout.AbsoluteContentSize.X-trail.AbsoluteSize.X),0)
	end)
end

function Guide.Open(itemId,options)
	options=options or {}; preferredStation=options.PreferredStationType
	stack={}
	local rootRecipe=options.RootRecipeId and Recipes.RECIPES[options.RootRecipeId]
	if rootRecipe then
		table.insert(stack,{ItemId=rootRecipe.Output.Id,RecipeId=options.RootRecipeId,QuantityText=tostring(options.RootQuantity or 1)})
	end
	if not rootRecipe or rootRecipe.Output.Id~=itemId then table.insert(stack,{ItemId=itemId,QuantityText="1"}) end
	gui.Enabled=true; render()
end
function Guide.OpenBook(options)
	preferredStation=options and options.PreferredStationType
	stack={{Library=true,Query="",Scroll=0}}; gui.Enabled=true; render()
	search:CaptureFocus()
end
local function hide() gui.Enabled=false; search:ReleaseFocus(); quantity:ReleaseFocus() end
close.Activated:Connect(hide); shade.Activated:Connect(hide); back.Activated:Connect(goBack)
UIS.InputBegan:Connect(function(input,processed)
	if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then hide() end
end)
search:GetPropertyChangedSignal("Text"):Connect(function()
	if syncingInput or not current() or not current().Library then return end
	current().Query=search.Text; current().Scroll=0; render()
end)
quantity:GetPropertyChangedSignal("Text"):Connect(function()
	if syncingInput or not current() then return end
	current().QuantityText=quantity.Text; refresh()
end)
local function setQuantity(value)
	if not current() or activeCraft then return end
	quantity.Text=tostring(math.clamp(value,1,99))
end
minus.Activated:Connect(function() if minus.Active then setQuantity((parsedQuantity() or 2)-1) end end)
plus.Activated:Connect(function() if plus.Active then setQuantity((parsedQuantity() or 1)+1) end end)
maximum.Activated:Connect(function()
	local node=current(); local recipe=node and node.RecipeId and Recipes.RECIPES[node.RecipeId]
	if maximum.Active and recipe then setQuantity(affordable(recipe)) end
end)
craft.Activated:Connect(function()
	local node=current(); local recipe=node and node.RecipeId and Recipes.RECIPES[node.RecipeId]
	local n=parsedQuantity()
	if activeCraft or not recipe or not n or n>affordable(recipe) or not craftRemote then return end
	local station=Resolver.GetUsableStation(node.RecipeId,player,preferredStation)
	if not station then refresh(); feedback("Move closer to one of the listed stations.",false); return end
	activeCraft={RecipeId=node.RecipeId,StationType=station,Quantity=n,Duration=duration(recipe,station,n),StartedAt=os.clock(),Confirmed=false}
	local request=activeCraft
	refresh(); feedback("Preparing craft…",true)
	craftRemote:FireServer(node.RecipeId,station,n)
	armCraftTimeout(request)
end)
if craftRemote then
	craftRemote.OnClientEvent:Connect(function(kind,payload)
		if type(payload)~="table" then return end
		if kind=="Started" then
			if activeCraft and (activeCraft.RecipeId~=payload.RecipeId or activeCraft.StationType~=payload.StationType) then return end
			activeCraft=activeCraft or {}
			activeCraft.RecipeId=payload.RecipeId; activeCraft.StationType=payload.StationType
			activeCraft.Quantity=payload.Quantity or 1; activeCraft.Duration=payload.Duration or .05
			activeCraft.StartedAt=os.clock(); activeCraft.Confirmed=true
			armCraftTimeout(activeCraft)
		elseif kind=="Result" then
			if not activeCraft or activeCraft.RecipeId~=payload.RecipeId or activeCraft.StationType~=payload.StationType then return end
			-- Another panel may have tried the same recipe while this craft was active.
			if payload.Reason=="CraftInProgress" and activeCraft.Confirmed then return end
			activeCraft=nil
			local extra=payload.Extra
			if payload.Success and type(extra)=="table" and extra.OutputCount then
				feedback("Crafted "..extra.OutputCount.." × "..itemName(extra.OutputId),true)
			else feedback(Messages[payload.Reason] or "Crafting could not complete.",payload.Success==true) end
		else return end
		if gui.Enabled then refresh() end
	end)
end
if inventoryRemote then
	inventoryRemote.OnClientEvent:Connect(function(kind,payload)
		if kind=="Snapshot" and type(payload)=="table" then inventory=payload; if gui.Enabled then refresh() end end
	end)
	task.defer(function() inventoryRemote:FireServer("RequestSnapshot") end)
end
local accumulator=0
local progressAccumulator=0
RunService.Heartbeat:Connect(function(delta)
	if not gui.Enabled then return end
	accumulator+=delta
	progressAccumulator+=delta
	if progressAccumulator>=.05 then progressAccumulator=0; updateProgress() end
	if accumulator>=.5 then accumulator=0; refresh() end
end)
player:GetAttributeChangedSignal("Role_Craft"):Connect(function() if gui.Enabled then refresh() end end)
return Guide
