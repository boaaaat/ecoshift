-- Shared cooking station: one scrolling page, no nested mobile scroll surfaces.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
if require(Shared:WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
local Theme = require(Shared.UI.UITheme)
local UIFactory = require(Shared.UI.UIFactory)
local RemoteRequest = require(Shared.UI.RemoteRequest)
local Catalog = require(Shared:WaitForChild("CookingConfig"))
local Biomes = require(Shared.BiomeConfig)
local Items = require(Shared.Items.ItemDatabase)
local Guide = require(Shared.UI.RecipeGuideUI)
local SearchRank = require(Shared.UI.SearchRank)
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = Util.WaitForDescendant(Config.Paths.Remotes, 20)
if not remotes then return end
local remote = remotes:WaitForChild("Cooking", 30)
if not remote then return end
local inventoryRemote = remotes:WaitForChild(Config.RemoteNames.InventoryUpdate)
local colors = Theme.Colors
local state, inventory = nil, {}
local page, recipeId, seasoningId, quantity = "Meals", nil, nil, 1
local rowCallbacks = {}
local receivedAt, signature = 0, ""
local searchQuery = ""
local render
local go
local pageSearch = {}
local make = UIFactory.Create
local requests = RemoteRequest.new(remote)
local gui = make("ScreenGui", playerGui, {Name="CookingUI",ResetOnSpawn=false,DisplayOrder=65,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local backdrop = make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=colors.Night,BackgroundTransparency=.35,BorderSizePixel=0,Active=true})
local panel = make("CanvasGroup",gui,{Name="Kitchen",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-24,1,-24),BackgroundColor3=colors.Panel,BorderSizePixel=0})
Theme.Panel(panel); Theme.CaptureCursor(panel); Theme.TrackRoot(gui)
local function text(parent, value, height, size)
 return make("TextLabel",parent,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 36),Text=value,TextSize=size or 16,Font=Enum.Font.Gotham,TextColor3=colors.Text,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(parent, value, callback, height, icon, role)
 local b = make("TextButton",parent,{Size=UDim2.new(1,0,0,height or 48),Text=value,TextSize=16,Font=Enum.Font.GothamMedium,TextColor3=colors.Text,BackgroundColor3=colors.SlotEmpty,TextWrapped=true,AutoButtonColor=false})
 Theme.StationStyle(b,icon,role)
 b.Activated:Connect(callback)
 return b
end
local title=text(panel,"Camp kitchen",40,22)
title.Position=UDim2.fromOffset(16,8);title.Size=UDim2.new(1,-78,0,40);title.Font=Enum.Font.GothamBold
local close
local function hide()
 gui.Enabled=false
 remote:FireServer("Close",{RequestId=HttpService:GenerateGUID(false)})
end
close=button(panel,"",hide,44);close.Position=UDim2.new(1,-58,0,8);close.Size=UDim2.fromOffset(44,44);Theme.Icon(close,"Close",22);close:SetAttribute("ActionLabel","Close")
local tabs=make("Frame",panel,{BackgroundTransparency=1,Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,0,44)})
local mealsTab=button(tabs,"Meals",function() go("Meals") end,44,"Pot","Craft")
mealsTab.Size=UDim2.new(1/3,-5,1,0)
local kitchenTab=button(tabs,"Ready",function() go("Kitchen") end,44,"Collect","Collect")
kitchenTab.Position=UDim2.new(1/3,2,0,0);kitchenTab.Size=UDim2.new(1/3,-5,1,0)
local fuelTab=button(tabs,"Fuel",function() go("Fuel") end,44,"Flame","Fuel")
fuelTab.Position=UDim2.new(2/3,4,0,0);fuelTab.Size=UDim2.new(1/3,-4,1,0)
local readyBadge=text(tabs,"",20,13);readyBadge.Position=UDim2.new(2/3,-28,0,2);readyBadge.Size=UDim2.fromOffset(24,20);readyBadge.TextColor3=colors.Amber;readyBadge.ZIndex=5
local search=make("TextBox",panel,{Name="ItemSearch",BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,0,40),Text="",PlaceholderText="Search meals, ingredients, or seasonings",PlaceholderColor3=colors.TextMuted,TextColor3=colors.Text,TextSize=15,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Visible=false})
Theme.Corner(search,8)
make("UIPadding",search,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
local content=make("ScrollingFrame",panel,{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,1,-210),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5,ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.WhenScrollable})
make("UIListLayout",content,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",content,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
local upgrade=button(panel,"",function()
 if not state then return end
 local stationRemote=remotes:FindFirstChild("Station")
 if stationRemote then stationRemote:FireServer("Open",{Station=state.Station,RequestId=HttpService:GenerateGUID(false)}) end
end,44)
upgrade.Position=UDim2.new(1,-110,0,8);upgrade.Size=UDim2.fromOffset(44,44);Theme.Icon(upgrade,"Upgrade",22);upgrade:SetAttribute("ActionLabel","Upgrade station")
title.Size=UDim2.new(1,-136,0,40)
local jobLabel=text(panel,"No meals queued",32,14);jobLabel.Position=UDim2.fromOffset(16,108);jobLabel.Size=UDim2.new(.68,-24,0,32);jobLabel.TextTruncate=Enum.TextTruncate.AtEnd;jobLabel.TextWrapped=false
local fuelSummary=text(panel,"",32,14);fuelSummary.Position=UDim2.new(.68,0,0,108);fuelSummary.Size=UDim2.new(.32,-16,0,32);fuelSummary.TextXAlignment=Enum.TextXAlignment.Right;fuelSummary.TextColor3=colors.Amber
local track=make("Frame",panel,{Position=UDim2.fromOffset(16,145),Size=UDim2.new(1,-32,0,7),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0})
Theme.Corner(track,4)
local fill=make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.Amber,BorderSizePixel=0});Theme.Corner(fill,4)
local status=text(panel,"Choose a meal to prepare.",36,14);status.Position=UDim2.new(0,16,1,-44);status.Size=UDim2.new(1,-32,0,36)
local actions=make("Frame",panel,{Name="MealActions",Position=UDim2.fromOffset(16,160),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1,Visible=false})
local minus=button(actions,"−",function()quantity=math.max(1,quantity-1);render()end,44)
minus.Size=UDim2.fromOffset(40,44)
local quantityBox=make("TextBox",actions,{Position=UDim2.fromOffset(44,0),Size=UDim2.fromOffset(44,44),BackgroundColor3=colors.Background,TextColor3=colors.Text,Text="1",ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextSize=18})
Theme.Corner(quantityBox,8)
local plus=button(actions,"+",function()quantity=math.min(20,quantity+1);render()end,44)
plus.Position=UDim2.fromOffset(92,0);plus.Size=UDim2.fromOffset(40,44)
local queue=button(actions,"Cook",function()end,44,"Pot","Craft")
queue.Position=UDim2.fromOffset(140,0);queue.Size=UDim2.new(1,-140,1,0)
local function name(id) local item=Items:Get(id);return item and item.Name or tostring(id) end
local function count(id)
 local n=0
 for _,section in ipairs({"Hotbar","Storage"}) do
  for _,stack in pairs(inventory[section] or {}) do if type(stack)=="table" and stack.Id==id then n+=stack.N or 0 end end
 end
 return n
end
local function seconds(n)
 n=math.max(0,math.ceil(tonumber(n) or 0))
 return string.format("%d:%02d",math.floor(n/60),n%60)
end
local function request(action,payload)
 if not state or not state.Station then return end
 payload=payload or {};payload.Station=state.Station
 requests:Send(action,payload,{
  Timeout=10,
  OnBusy=function()status.Text="Waiting for the station…" end,
  OnStart=function()status.Text="Sending…";status.TextColor3=colors.Amber end,
  OnTimeout=function()status.Text="No response yet. Reopen the station to refresh.";status.TextColor3=colors.Warning end,
 })
end
go=function(nextPage)
 pageSearch[page]=searchQuery
 page=nextPage;searchQuery=pageSearch[page] or "";search.Text=searchQuery
 render(true)
end
local function source(id)
 Guide.Open(id,{PreferredStationType=state and state.StationType})
end
local function addText(value,height,size) return text(content,value,height,size) end
local function addButton(value,fn,height,icon,role) return button(content,value,fn,height,icon,role) end
local function biomeName(id)
 local biome=Biomes.biome_metadata and Biomes.biome_metadata[id]
 return biome and biome.DisplayName or tostring(id)
end
local function badge(parent, spice)
 if not spice then return end
 local mark=make("Frame",parent,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(12,12),BackgroundColor3=spice.Color or colors.Sage,BorderSizePixel=0})
 Theme.Corner(mark,6);mark:SetAttribute("ThemeFixed",true)
end
local function recipeWork(recipe) return recipe.WorkSeconds or recipe.Work or 8 end
local function chosenRecipe() return recipeId and Catalog.Recipes[recipeId] end
local function seasoningDescription(seasoning)
 return tostring(seasoning.Effect or seasoning.Description or "").." · 4 min"
end
local function recipeSearchScore(id,recipe)
 local secondary={recipe.Category or ""}
 for _,ingredient in ipairs(recipe.Ingredients or {}) do
  table.insert(secondary,ingredient.Id);table.insert(secondary,name(ingredient.Id))
 end
 return SearchRank.Score(searchQuery,{recipe.Name,id},secondary)
end
local function enoughForMeal(recipe)
 if not recipe or not state or #(state.Jobs or {})>=3 then return false end
 for _,ingredient in ipairs(recipe.Ingredients) do if count(ingredient.Id)<ingredient.N*quantity then return false end end
 return not seasoningId or recipe.Drink or count(seasoningId)>=quantity
end
quantityBox.FocusLost:Connect(function()
 quantity=math.clamp(math.floor(tonumber(quantityBox.Text) or quantity),1,20)
 quantityBox.Text=tostring(quantity)
 render()
end)
queue.Activated:Connect(function()
 local recipe=chosenRecipe()
 if not enoughForMeal(recipe) then status.Text="Missing ingredients or queue full.";return end
 queue.Text="Sending…"
 request("Queue",{RecipeId=recipeId,SeasoningId=not recipe.Drink and seasoningId or nil,Quantity=quantity})
end)
local function renderDetails()
 local recipe=chosenRecipe();if not recipe then go("Meals");return end
 addText(recipe.Name or name(recipeId),36,22).Font=Enum.Font.GothamBold
 local stats=make("Frame",content,{Size=UDim2.new(1,0,0,64),BackgroundTransparency=1})
 for index,stat in ipairs({{"Food",recipe.Hunger or 0,"Fuel"},{"Energy",recipe.Stamina or 0,"Collect"},{"Clock",seconds(recipeWork(recipe)*quantity),"Neutral"}}) do
  local chip=button(stats,tostring(stat[2]),function()end,44,stat[1],stat[3])
  chip.Active=false;chip.Selectable=false;chip.Size=UDim2.new(1/3,-6,1,0);chip.Position=UDim2.new((index-1)/3,0,0,0)
  Theme.StationTile(chip,stat[1],stat[3])
 end
 local effect=""
 if type(recipe.ExposureRelief)=="table" then
  for channel,value in pairs(recipe.ExposureRelief) do effect ..=string.format(" · −%d %s exposure",value,string.lower(channel)) end
 end
 if recipe.Thermal then effect ..=string.format(" · %d%% less %s buildup for %ss",recipe.Thermal.Reduction*100,string.lower(recipe.Thermal.Channel),recipe.Thermal.Duration) end
 if effect~="" then addText(effect,44,14).TextColor3=colors.Cold end
 if not recipe.Drink then
  local spice=seasoningId and Catalog.Seasonings[seasoningId]
  badge(addButton(spice and spice.Name or "Seasoning · optional",function() go("Seasoning") end,44,"Seasoning","Special"),spice)
  if spice then addText(seasoningDescription(spice),44,14) end
 end
 addText("Ingredients · owned / needed",28,14).TextColor3=colors.TextMuted
 for _,ingredient in ipairs(recipe.Ingredients) do
  local id,required=ingredient.Id,ingredient.N*quantity
  addButton(string.format("%s   %d / %d",name(id),count(id),required),function() source(id) end,44,count(id)>=required and "Place" or "Search",count(id)>=required and "Neutral" or "Danger")
 end
 if seasoningId and not recipe.Drink then addText(name(seasoningId).." · "..count(seasoningId).." / "..quantity,30,14) end
end
render=function(resetScroll)
 local oldPosition=content.CanvasPosition
 rowCallbacks={}
 for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 if not state then return end
 search.Visible=page=="Meals" or page=="Seasoning"
 actions.Visible=page=="Detail"
 local compactHeight=panel.Size.Y.Offset>0 and panel.Size.Y.Offset<360
 jobLabel.Visible=not compactHeight;fuelSummary.Visible=not compactHeight;track.Visible=not compactHeight
 local toolbarTop=compactHeight and 110 or 160
 search.Position=UDim2.fromOffset(16,toolbarTop);actions.Position=search.Position
 local contentTop=(search.Visible or actions.Visible) and toolbarTop+52 or toolbarTop
 content.Position=UDim2.fromOffset(16,contentTop)
 content.Size=UDim2.new(1,-32,1,-contentTop-48)
 title.Text=state.StationType or "Kitchen"
 if not quantityBox:IsFocused() then quantityBox.Text=tostring(quantity) end
 local enough=enoughForMeal(chosenRecipe())
 queue.Text=requests:IsPending() and "Sending…" or enough and "Cook" or "Can't cook"
 Theme.StationStyle(queue,"Pot",enough and "Craft" or "Neutral")
 local readyCount=0
 for _,stack in pairs(state.Output or {}) do if type(stack)=="table" and (stack.N or 0)>0 then readyCount+=stack.N end end
 kitchenTab.Text=readyCount>0 and ("Ready "..readyCount) or "Queue"
 local compact=panel.Size.X.Offset>0 and panel.Size.X.Offset<440
 readyBadge.Visible=compact and readyCount>0;readyBadge.Text=tostring(readyCount)
 for _,entry in ipairs({{mealsTab,"Meals","Pot","Craft"},{kitchenTab,kitchenTab.Text,"Collect","Collect"},{fuelTab,"Fuel","Flame","Fuel"}}) do
  entry[1]:SetAttribute("ActionLabel",entry[2]);entry[1].Text=compact and "" or entry[2]
  Theme.StationStyle(entry[1],entry[3],entry[4],compact)
 end
 for _,tab in ipairs({mealsTab,kitchenTab,fuelTab}) do
  local active=(tab==mealsTab and (page=="Meals" or page=="Detail" or page=="Seasoning")) or (tab==kitchenTab and page=="Kitchen") or (tab==fuelTab and page=="Fuel")
  tab.BackgroundTransparency=active and 0 or .45
 end
 local activeSpice=Catalog.Seasonings[player:GetAttribute("FoodSeasoning")]
 if activeSpice and page=="Fuel" then
  local buff=addText("",60,14)
  badge(buff,activeSpice)
  local function updateBuff()
   buff.Text="Active meal: "..activeSpice.Name.." · "..seconds(player:GetAttribute("FoodSeasoningRemaining")).." remaining\n"..activeSpice.Effect
  end
  updateBuff();table.insert(rowCallbacks,updateBuff)
 end
 if page=="Meals" then
  local recipes={}
  for id,recipe in pairs(Catalog.Recipes) do
   local searchScore=recipeSearchScore(id,recipe)
   if recipe.StationType==state.StationType and not recipe.Future and searchScore~=nil then table.insert(recipes,{Id=id,Recipe=recipe,SearchScore=searchScore}) end
  end
  table.sort(recipes,function(a,b)
   return SearchRank.Less(a,b,searchQuery,function(entry)return entry.Recipe.Name end,function(left,right)
    if left.Recipe.Tier~=right.Recipe.Tier then return (left.Recipe.Tier or 1)<(right.Recipe.Tier or 1) end
    return nil
   end)
  end)
  for _,entry in ipairs(recipes) do
   addButton(entry.Recipe.Name..string.format("\n+%d food · +%d energy · %ss",entry.Recipe.Hunger or 0,entry.Recipe.Stamina or 0,recipeWork(entry.Recipe)),function()
    recipeId=entry.Id;seasoningId=nil;quantity=1;go("Detail")
   end,60,entry.Recipe.Drink and "Bottle" or "Pot",entry.Recipe.Drink and "Collect" or "Fuel")
  end
 elseif page=="Detail" then renderDetails()
 elseif page=="Seasoning" then
  addButton("Back to meal",function() go("Detail") end,44,"Back")
  addButton("No seasoning",function() seasoningId=nil;go("Detail") end,44,"Close")
  local spices={}
  for _,spice in pairs(Catalog.Seasonings) do
   local searchScore=SearchRank.Score(searchQuery,{spice.Name,spice.Id},{spice.Effect,spice.Description,biomeName(spice.Biome)})
   if not spice.Future and searchScore~=nil then table.insert(spices,{Definition=spice,Id=spice.Id,SearchScore=searchScore}) end
  end
  table.sort(spices,function(a,b)return SearchRank.Less(a,b,searchQuery,function(entry)return entry.Definition.Name end)end)
  for _,entry in ipairs(spices) do
   local spice=entry.Definition
   local itemId=spice.Id
   badge(addButton(spice.Name.." · "..count(itemId).."\n"..seasoningDescription(spice),function() seasoningId=itemId;go("Detail") end,68,"Seasoning","Special"),spice)
   addButton("Found in "..biomeName(spice.Biome).."  ›",function() source(itemId) end,44)
  end
 elseif page=="Fuel" then
  local fuel=addText("Fuel: "..seconds(state.FuelSeconds).." · "..tostring(state.Status or "Idle"),38)
  table.insert(rowCallbacks,function() fuel.Text="Fuel: "..seconds(state.FuelSeconds).." · "..tostring(state.Status or "Idle") end)
  addButton(state.Enabled==false and "Resume" or "Pause",function() request("SetEnabled",{Enabled=state.Enabled==false}) end,44,state.Enabled==false and "Play" or "Pause","Fuel")
  local fuels=make("Frame",content,{Size=UDim2.new(1,0,0,76),BackgroundTransparency=1})
  for index,id in ipairs({"Wood","Peat","Coal"}) do
   local itemId=id
   local fuelButton=button(fuels,name(id).." +1\n"..count(id).." owned",function() request("Fuel",{ItemId=itemId,Quantity=1}) end,76)
   Theme.StationTile(fuelButton,"Flame","Fuel")
   fuelButton.Size=UDim2.new(1/3,-6,1,0);fuelButton.Position=UDim2.new((index-1)/3,0,0,0);fuelButton.TextSize=14
  end
  if state.StationType=="Campfire" then addButton("Keep warm · "..(state.KeepWarm and "On" or "Off"),function() request("KeepWarm",{Enabled=not state.KeepWarm}) end,44,"Exposure","Fuel") end
  addText("Fuel pauses when idle. Keep warm uses fuel continuously.",36,14)
 else
  addText("Ready to collect",28,18).TextColor3=colors.Cold
  local occupied=0
  for index=1,12 do
   local stack=(state.Output or {})[index] or (state.Output or {})[tostring(index)]
   if type(stack)=="table" and stack.Id and (stack.N or 0)>0 then
    occupied+=1;local slot=index
    local recipe,spice=Catalog.GetMeal(stack.Id)
    addButton((recipe and recipe.Name or name(stack.Id)).." ×"..stack.N..(spice and ("\n"..spice.Name) or ""),function() request("Collect",{Slot=slot,ExpectedId=stack.Id}) end,spice and 60 or 44,"Collect","Collect")
   end
  end
  if occupied==0 then addText("Nothing ready yet.",30,14) end
  addText("Queue · "..#(state.Jobs or {}).." / 3",32,18).TextColor3=colors.Amber
  for index,job in ipairs(state.Jobs or {}) do
   local jobId=job.Id
   local spice=job.SeasoningId and Catalog.Seasonings[job.SeasoningId]
   local recipe=Catalog.Recipes[job.RecipeId]
   addText(string.format("%d. %s ×%d%s",index,recipe and recipe.Name or name(job.RecipeId),job.Remaining or job.Quantity or 1,spice and (" · "..spice.Name) or ""),54)
   addButton("Cancel / refund",function() request("Cancel",{JobId=jobId}) end,44,"Close","Danger")
  end
 end
 content.CanvasPosition=resetScroll and Vector2.zero or oldPosition
end
search:GetPropertyChangedSignal("Text"):Connect(function()
 searchQuery=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
 if gui.Enabled and (page=="Meals" or page=="Seasoning") then render(true) end
end)
local function stateSignature(value)
 local pieces={tostring(value.Enabled),tostring(value.KeepWarm)}
 for _,job in ipairs(value.Jobs or {}) do table.insert(pieces,tostring(job.Id)..":"..tostring(job.Remaining)) end
 for index=1,12 do local stack=(value.Output or {})[index] or (value.Output or {})[tostring(index)];if type(stack)=="table" then table.insert(pieces,index..":"..tostring(stack.Id)..":"..tostring(stack.N)) end end
 return table.concat(pieces,"|")
end
remote.OnClientEvent:Connect(function(kind,payload)
 if type(payload)~="table" then return end
 if kind=="Result" then
  requests:Resolve(payload.RequestId)
  status.Text=payload.Message or (payload.Success and "Done." or "Couldn't complete that action.")
  status.TextColor3=payload.Success and colors.Success or colors.Warning
  if gui.Enabled then render() end
  return
 end
 if kind=="Close" or kind=="Closed" then gui.Enabled=false;state=nil;return end
 if kind~="Open" and kind~="State" then return end
 if kind=="State" and (not state or payload.Station~=state.Station) then return end
 local changedStation=not state or payload.Station~=state.Station
 state=payload;receivedAt=os.clock()
 local newSignature=stateSignature(state)
 if kind=="Open" then
  if changedStation then page="Meals";recipeId=nil;seasoningId=nil;quantity=1;searchQuery="";search.Text="";table.clear(pageSearch);requests:Cancel() end
  if payload.RecipeId and Catalog.Recipes[payload.RecipeId] then
   recipeId=payload.RecipeId;page="Detail"
   local spice=payload.SeasoningId and Catalog.Seasonings[payload.SeasoningId]
   seasoningId=spice and not spice.Future and not Catalog.Recipes[recipeId].Drink and spice.Id or nil
  end
  gui.Enabled=true;panel.GroupTransparency=.35
  TweenService:Create(panel,TweenInfo.new(.18),{GroupTransparency=0}):Play()
  status.Text="Select a meal to cook.";status.TextColor3=colors.TextMuted
  render(changedStation)
 elseif gui.Enabled and newSignature~=signature then render() end
 signature=newSignature
end)
player:GetAttributeChangedSignal("FoodSeasoning"):Connect(function() if gui.Enabled then render() end end)
inventoryRemote.OnClientEvent:Connect(function(kind,payload)
 if kind~="Snapshot" or type(payload)~="table" then return end
 inventory=payload
 if gui.Enabled and not UIS:GetFocusedTextBox() then render() end
end)
task.defer(function() inventoryRemote:FireServer("RequestSnapshot") end)
UIS.InputBegan:Connect(function(input,processed)
 if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then hide() end
end)
local panelScale=make("UIScale",panel,{Scale=1})
Theme.BindResponsive(gui,function(mobile,available)
 -- One independently scrolling content surface; header/progress never leave view.
 local scale=mobile and 1 or math.clamp(math.min(available.X/1440,available.Y/900),1,2.5)
 panelScale.Scale=scale
 panel.Size=UDim2.fromOffset(math.max(280,math.min(mobile and 900 or 850,(available.X-20)/scale)),math.max(240,math.min(mobile and available.Y-16 or 760,(available.Y-16)/scale)))
 if gui.Enabled then render() end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 if not gui.Enabled or not state then return end
 if not state.Station or not state.Station:IsDescendantOf(workspace) then hide();return end
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 fuelSummary.Text=seconds(state.FuelSeconds).." fuel"
 local job=(state.Jobs or {})[1]
 if job then
  local required=math.max(.01,tonumber(job.WorkRequired) or 1)
  local advance=state.Status=="Cooking" and math.min(2,os.clock()-receivedAt)*(job.Rate or 1) or 0
  local progress=math.clamp(((job.Work or 0)+advance)/required,0,1)
  fill.Size=UDim2.fromScale(progress,1)
  local recipe=Catalog.Recipes[job.RecipeId]
  local remaining=(job.RemainingSeconds or ((job.Remaining or 1)*required-(job.Work or 0)))-advance/math.max(.01,job.Rate or 1)
  jobLabel.Text=string.format("%s · %s · %s",recipe and recipe.Name or name(job.RecipeId),seconds(remaining),state.Status or "Queued")
 else fill.Size=UDim2.fromScale(0,1);jobLabel.Text=state.Status or "No meals queued" end
 for _,update in ipairs(rowCallbacks) do update() end
end)
