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
local Catalog = require(Shared:WaitForChild("CookingConfig"))
local Biomes = require(Shared.BiomeConfig)
local Items = require(Shared.Items.ItemDatabase)
local Guide = require(Shared.UI.RecipeGuideUI)
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
local pending, rowCallbacks = {}, {}
local receivedAt, signature = 0, ""
local searchQuery = ""
local render
local function make(class, parent, props)
 local object = Instance.new(class)
 for key, value in pairs(props or {}) do object[key] = value end
 object.Parent = parent
 return object
end
local gui = make("ScreenGui", playerGui, {Name="CookingUI",ResetOnSpawn=false,DisplayOrder=65,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local backdrop = make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=colors.Night,BackgroundTransparency=.35,BorderSizePixel=0,Active=true})
local panel = make("CanvasGroup",gui,{Name="Kitchen",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-24,1,-24),BackgroundColor3=colors.Panel,BorderSizePixel=0})
Theme.Panel(panel); Theme.CaptureCursor(panel); Theme.TrackRoot(gui)
local function text(parent, value, height, size)
 return make("TextLabel",parent,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 36),Text=value,TextSize=size or 16,Font=Enum.Font.Gotham,TextColor3=colors.Text,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(parent, value, callback, height)
 local b = make("TextButton",parent,{Size=UDim2.new(1,0,0,height or 48),Text=value,TextSize=16,Font=Enum.Font.GothamMedium,TextColor3=colors.Text,BackgroundColor3=colors.SlotEmpty,TextWrapped=true,AutoButtonColor=false})
 Theme.Button(b)
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
close=button(panel,"×",hide,44);close.Position=UDim2.new(1,-58,0,8);close.Size=UDim2.fromOffset(44,44);close.TextSize=26
local tabs=make("Frame",panel,{BackgroundTransparency=1,Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,0,44)})
button(tabs,"Meals",function() page="Meals";render(true) end).Size=UDim2.new(.5,-4,1,0)
local kitchenTab=button(tabs,"Kitchen",function() page="Kitchen";render(true) end)
kitchenTab.Position=UDim2.new(.5,4,0,0);kitchenTab.Size=UDim2.new(.5,-4,1,0)
local search=make("TextBox",panel,{Name="ItemSearch",BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,0,40),Text="",PlaceholderText="Search meals, ingredients, or seasonings",PlaceholderColor3=colors.TextMuted,TextColor3=colors.Text,TextSize=15,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Visible=false})
Theme.Corner(search,8)
make("UIPadding",search,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
local content=make("ScrollingFrame",panel,{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,1,-210),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5,ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.WhenScrollable})
make("UIListLayout",content,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",content,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
local upgrade=button(panel,"Upgrade",function()
 if not state then return end
 local stationRemote=remotes:FindFirstChild("Station")
 if stationRemote then stationRemote:FireServer("Open",{Station=state.Station,RequestId=HttpService:GenerateGUID(false)}) end
end,36)
upgrade.Position=UDim2.new(1,-160,0,12);upgrade.Size=UDim2.fromOffset(90,36)
title.Size=UDim2.new(1,-188,0,40)
local jobLabel=text(panel,"No meals queued",30,14);jobLabel.Position=UDim2.new(0,16,1,-90);jobLabel.Size=UDim2.new(1,-32,0,30)
local track=make("Frame",panel,{Position=UDim2.new(0,16,1,-55),Size=UDim2.new(1,-32,0,7),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0})
Theme.Corner(track,4)
local fill=make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.Amber,BorderSizePixel=0});Theme.Corner(fill,4)
local status=text(panel,"Choose a meal to prepare.",36,14);status.Position=UDim2.new(0,16,1,-44);status.Size=UDim2.new(1,-32,0,36)
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
 if next(pending) then status.Text="Waiting for the station…";return end
 payload=payload or {};payload.Station=state.Station;payload.RequestId=HttpService:GenerateGUID(false)
 local id=payload.RequestId;pending[id]=true
 status.Text="Sending…";status.TextColor3=colors.Amber
 remote:FireServer(action,payload)
 task.delay(10,function()
  if pending[id] then pending[id]=nil;status.Text="No response yet. Reopen the station to refresh.";status.TextColor3=colors.Warning end
 end)
end
local function go(nextPage) page=nextPage;render(true) end
local function source(id)
 Guide.Open(id,{PreferredStationType=state and state.StationType})
end
local function addText(value,height,size) return text(content,value,height,size) end
local function addButton(value,fn,height) return button(content,value,fn,height) end
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
local function matchesSearch(...)
 if searchQuery=="" then return true end
 for index=1,select("#",...) do
  if string.find(string.lower(tostring(select(index,...) or "")),searchQuery,1,true) then return true end
 end
 return false
end
local function recipeMatches(id,recipe)
 if matchesSearch(id,recipe.Name,recipe.Category) then return true end
 for _,ingredient in ipairs(recipe.Ingredients or {}) do
  if matchesSearch(ingredient.Id,name(ingredient.Id)) then return true end
 end
 return false
end
local function renderDetails()
 local recipe=chosenRecipe();if not recipe then go("Meals");return end
 addButton("‹ All meals",function() go("Meals") end,44)
 addText(recipe.Name or name(recipeId),36,22).Font=Enum.Font.GothamBold
 local effect=string.format("+%d food · +%d energy · %ss per serving",recipe.Hunger or 0,recipe.Stamina or 0,recipeWork(recipe))
 if type(recipe.ExposureRelief)=="table" then
  for channel,value in pairs(recipe.ExposureRelief) do effect ..=string.format(" · −%d %s exposure",value,string.lower(channel)) end
 end
 if recipe.Thermal then effect ..=string.format(" · %d%% less %s buildup for %ss",recipe.Thermal.Reduction*100,string.lower(recipe.Thermal.Channel),recipe.Thermal.Duration) end
 addText(effect,56)
 addText("Exact ingredients · tap to see source",32,14)
 for _,ingredient in ipairs(recipe.Ingredients) do
  local id,required=ingredient.Id,ingredient.N*quantity
  addButton(string.format("%s   %d / %d  ›",name(id),count(id),required),function() source(id) end,48)
 end
 if not recipe.Drink then
  local spice=seasoningId and Catalog.Seasonings[seasoningId]
  badge(addButton(spice and ("Seasoning: "..spice.Name.."  ›") or "Add one seasoning (optional)  ›",function() go("Seasoning") end),spice)
  if spice then addText(seasoningDescription(spice).." · "..count(seasoningId).." / "..quantity.." charges",56) end
 end
 local controls=make("Frame",content,{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1})
 local minus=button(controls,"−",function() quantity=math.max(1,quantity-1);render() end)
 minus.Size=UDim2.fromOffset(48,48)
 local box=make("TextBox",controls,{Position=UDim2.fromOffset(56,0),Size=UDim2.new(1,-112,0,48),BackgroundColor3=colors.SlotEmpty,TextColor3=colors.Text,Text=tostring(quantity),PlaceholderText="1–20 servings",ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextSize=18})
 Theme.Corner(box,8)
 box.FocusLost:Connect(function() quantity=math.clamp(math.floor(tonumber(box.Text) or quantity),1,20);render() end)
 local plus=button(controls,"+",function() quantity=math.min(20,quantity+1);render() end)
 plus.Size=UDim2.fromOffset(48,48);plus.Position=UDim2.new(1,-48,0,0)
 addText(string.format("%d servings · %s baseline work · queue %d/3",quantity,seconds(recipeWork(recipe)*quantity),#(state.Jobs or {})),42,14)
 local enough=#(state.Jobs or {})<3
 for _,ingredient in ipairs(recipe.Ingredients) do if count(ingredient.Id)<ingredient.N*quantity then enough=false end end
 if seasoningId and not recipe.Drink and count(seasoningId)<quantity then enough=false end
 local queue=addButton(enough and "Queue meal" or "Missing supplies or queue full",function()
  if not enough then status.Text="Check the required ingredients and queue space.";return end
  request("Queue",{RecipeId=recipeId,SeasoningId=not recipe.Drink and seasoningId or nil,Quantity=quantity})
 end)
 queue.BackgroundColor3=enough and colors.Moss or colors.SlotEmpty
 addText("One serving cooks at a time. You can leave while the station works.",44,14)
end
render=function(resetScroll)
 local oldPosition=content.CanvasPosition
 rowCallbacks={}
 for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 if not state then return end
 search.Visible=page=="Meals" or page=="Seasoning"
 content.Position=search.Visible and UDim2.fromOffset(16,160) or UDim2.fromOffset(16,112)
 content.Size=search.Visible and UDim2.new(1,-32,1,-258) or UDim2.new(1,-32,1,-210)
 title.Text=(state.StationType or "Camp").." kitchen"
 kitchenTab.Text="Kitchen · "..#(state.Jobs or {}).."/3"
 local activeSpice=Catalog.Seasonings[player:GetAttribute("FoodSeasoning")]
 if activeSpice then
  local buff=addText("",60,14)
  badge(buff,activeSpice)
  local function updateBuff()
   buff.Text="Active meal: "..activeSpice.Name.." · "..seconds(player:GetAttribute("FoodSeasoningRemaining")).." remaining\n"..activeSpice.Effect
  end
  updateBuff();table.insert(rowCallbacks,updateBuff)
 end
 if page=="Meals" then
  addText("Choose a recipe. Seasoning is optional.",36,14)
  local recipes={}
  for id,recipe in pairs(Catalog.Recipes) do if recipe.StationType==state.StationType and not recipe.Future and recipeMatches(id,recipe) then table.insert(recipes,{Id=id,Recipe=recipe}) end end
  table.sort(recipes,function(a,b) if a.Recipe.Tier~=b.Recipe.Tier then return (a.Recipe.Tier or 1)<(b.Recipe.Tier or 1) end return a.Recipe.Name<b.Recipe.Name end)
  for _,entry in ipairs(recipes) do
   addButton(entry.Recipe.Name..string.format("\n+%d food · +%d energy · %ss",entry.Recipe.Hunger or 0,entry.Recipe.Stamina or 0,recipeWork(entry.Recipe)),function()
    recipeId=entry.Id;seasoningId=nil;quantity=1;go("Detail")
   end,68)
  end
 elseif page=="Detail" then renderDetails()
 elseif page=="Seasoning" then
  addButton("‹ Back to meal",function() go("Detail") end,44)
  addButton("No seasoning",function() seasoningId=nil;go("Detail") end)
  local spices={}
  for _,spice in pairs(Catalog.Seasonings) do if not spice.Future and matchesSearch(spice.Id,spice.Name,spice.Effect,spice.Description,biomeName(spice.Biome)) then table.insert(spices,spice) end end
  table.sort(spices,function(a,b) return a.Name<b.Name end)
  for _,spice in ipairs(spices) do
   local itemId=spice.Id
   badge(addButton(spice.Name.." · "..count(itemId).." owned\n"..seasoningDescription(spice),function() seasoningId=itemId;go("Detail") end,76),spice)
   addButton("Found in "..biomeName(spice.Biome).."  ›",function() source(itemId) end,44)
  end
 else
  local fuel=addText("Fuel: "..seconds(state.FuelSeconds).." · "..tostring(state.Status or "Idle"),38)
  table.insert(rowCallbacks,function() fuel.Text="Fuel: "..seconds(state.FuelSeconds).." · "..tostring(state.Status or "Idle") end)
  addButton(state.Enabled==false and "Resume cooking" or "Pause cooking",function() request("SetEnabled",{Enabled=state.Enabled==false}) end)
  for _,id in ipairs({"Wood","Peat","Coal"}) do
   local itemId=id
   addButton("Add 1 "..name(id).." · +"..seconds(Catalog.Fuels[id]).." · "..count(id).." owned",function() request("Fuel",{ItemId=itemId,Quantity=1}) end,44)
  end
  if state.StationType=="Campfire" then addButton("Keep warm: "..(state.KeepWarm and "On" or "Off"),function() request("KeepWarm",{Enabled=not state.KeepWarm}) end) end
  addText("Fuel stops when cooking ends, unless Keep warm is on. Loaded fuel cannot be reclaimed by salvaging.",56,14)
  addText("Queued meals",32,18)
  for index,job in ipairs(state.Jobs or {}) do
   local jobId=job.Id
   local spice=job.SeasoningId and Catalog.Seasonings[job.SeasoningId]
   local recipe=Catalog.Recipes[job.RecipeId]
   addText(string.format("%d. %s ×%d%s",index,recipe and recipe.Name or name(job.RecipeId),job.Remaining or job.Quantity or 1,spice and (" · "..spice.Name) or ""),54)
   addButton("Cancel & refund unfinished servings",function() request("Cancel",{JobId=jobId}) end,44)
  end
  addText("Finished meals · tap to collect",38,18)
  local occupied=0
  for index=1,12 do
   local stack=(state.Output or {})[index] or (state.Output or {})[tostring(index)]
   if type(stack)=="table" and stack.Id and (stack.N or 0)>0 then
    occupied+=1;local slot=index
    local recipe,spice=Catalog.GetMeal(stack.Id)
    addButton((recipe and recipe.Name or name(stack.Id)).." ×"..stack.N..(spice and ("\n"..spice.Name) or ""),function() request("Collect",{Slot=slot,ExpectedId=stack.Id}) end,spice and 64 or 48)
   end
  end
  addText(occupied.." / 12 output slots · full output pauses cooking",42,14)
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
  if payload.RequestId then pending[payload.RequestId]=nil end
  status.Text=payload.Message or (payload.Success and "Done." or "Couldn't complete that action.")
  status.TextColor3=payload.Success and colors.Success or colors.Warning
  return
 end
 if kind=="Close" or kind=="Closed" then gui.Enabled=false;state=nil;return end
 if kind~="Open" and kind~="State" then return end
 if kind=="State" and (not state or payload.Station~=state.Station) then return end
 local changedStation=not state or payload.Station~=state.Station
 state=payload;receivedAt=os.clock()
 local newSignature=stateSignature(state)
 if kind=="Open" then
  if changedStation then page="Meals";recipeId=nil;seasoningId=nil;quantity=1;searchQuery="";search.Text="";table.clear(pending) end
  if payload.RecipeId and Catalog.Recipes[payload.RecipeId] then
   recipeId=payload.RecipeId;page="Detail"
   local spice=payload.SeasoningId and Catalog.Seasonings[payload.SeasoningId]
   seasoningId=spice and not spice.Future and not Catalog.Recipes[recipeId].Drink and spice.Id or nil
  end
  gui.Enabled=true;panel.GroupTransparency=.35
  TweenService:Create(panel,TweenInfo.new(.18),{GroupTransparency=0}):Play()
  status.Text="Choose a meal or manage the shared kitchen.";status.TextColor3=colors.TextMuted
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
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 if not gui.Enabled or not state then return end
 if not state.Station or not state.Station:IsDescendantOf(workspace) then hide();return end
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
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
