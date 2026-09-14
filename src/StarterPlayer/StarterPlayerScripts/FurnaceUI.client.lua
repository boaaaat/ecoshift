-- Shared furnace work and station upgrades use one mobile-friendly scrolling surface.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local Shared=RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode()~="Expedition" then return end
local Theme=require(Shared.UI.UITheme)
local Catalog=require(Shared.OverhaulCatalog)
local Items=require(Shared.Items.ItemDatabase)
local Guide=require(Shared.UI.RecipeGuideUI)
local player=Players.LocalPlayer
local remote=RS:WaitForChild("Remotes"):WaitForChild("Station")
local colors=Theme.Colors
local function make(class,parent,props)local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="StationUI",Enabled=false,ResetOnSpawn=false,DisplayOrder=66,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=colors.Night,BackgroundTransparency=.3,Active=true,BorderSizePixel=0})
local panel=make("CanvasGroup",gui,{Name="StationPanel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(750,680),BackgroundColor3=colors.Panel})
Theme.Panel(panel);Theme.CaptureCursor(panel);Theme.TrackRoot(gui)
local function label(parent,value,height)
 return make("TextLabel",parent,{Size=UDim2.new(1,0,0,height or 34),Text=value,TextColor3=colors.Text,Font=Enum.Font.Gotham,TextSize=16,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1})
end
local function button(parent,value,fn,icon,role)
 local b=make("TextButton",parent,{Size=UDim2.new(1,0,0,46),Text=value,TextColor3=colors.Text,Font=Enum.Font.GothamMedium,TextSize=16,TextWrapped=true,BackgroundColor3=colors.SlotEmpty});Theme.StationStyle(b,icon,role);b.Activated:Connect(fn);return b
end
local state,recipeId,page,quantity,signature=nil,nil,"Recipes",1,""
local searchQuery=""
local render
local fuelLabel
local title=label(panel,"Station",40);title.Position=UDim2.fromOffset(16,8);title.Size=UDim2.new(1,-88,0,40);title.TextSize=23;title.Font=Enum.Font.GothamBold
local status=label(panel,"",38);status.Position=UDim2.new(0,16,1,-42);status.Size=UDim2.new(1,-32,0,38)
local function send(action,extra)
 if not state then return end
 local payload=extra or {};payload.Station=state.Station;payload.RequestId=Http:GenerateGUID(false)
 status.Text="Sending…";remote:FireServer(action,payload)
end
local function close()send("Close");gui.Enabled=false;state=nil end
local x=button(panel,"",close);x.Size=UDim2.fromOffset(44,44);x.Position=UDim2.new(1,-58,0,8);Theme.Icon(x,"Close",22)
local tabs=make("Frame",panel,{Position=UDim2.fromOffset(16,58),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1})
local recipesTab=button(tabs,"Recipes",function()page="Recipes";render(true) end,"Flame","Craft");recipesTab.Size=UDim2.new(1/3,-5,1,0)
local queueTab=button(tabs,"Output",function()page="Queue";render(true) end,"Collect","Collect");queueTab.Position=UDim2.new(1/3,2,0,0);queueTab.Size=UDim2.new(1/3,-5,1,0)
local stationTab=button(tabs,"Fuel",function()page="Station";render(true) end,"Flame","Fuel");stationTab.Position=UDim2.new(2/3,4,0,0);stationTab.Size=UDim2.new(1/3,-4,1,0)
local actions=make("Frame",panel,{Name="SmeltActions",Position=UDim2.fromOffset(16,160),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1,Visible=false})
local search=make("TextBox",panel,{Name="RecipeSearch",Position=UDim2.fromOffset(16,110),Size=UDim2.new(1,-32,0,40),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0,Text="",PlaceholderText="Search furnace recipes or ingredients",PlaceholderColor3=colors.TextMuted,TextColor3=colors.Text,TextSize=15,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Visible=false})
Theme.Corner(search,8)
make("UIPadding",search,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
local content=make("ScrollingFrame",panel,{Name="Content",Position=UDim2.fromOffset(16,110),Size=UDim2.new(1,-32,1,-198),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",content,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",content,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
local progress=make("Frame",panel,{Size=UDim2.new(1,-32,0,7),Position=UDim2.fromOffset(16,145),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0});Theme.Corner(progress,4)
local fill=make("Frame",progress,{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.Amber,BorderSizePixel=0});Theme.Corner(fill,4)
local work=label(panel,"No work queued",30);work.Position=UDim2.fromOffset(16,108);work.Size=UDim2.new(1,-32,0,30);work.TextSize=14;work.TextWrapped=false;work.TextTruncate=Enum.TextTruncate.AtEnd;work.TextColor3=colors.Amber
local function name(id)local item=Items:Get(id);return item and item.Name or id end
local function costs(list)local pieces={};for _,v in ipairs(list or {}) do table.insert(pieces,name(v.Id).." ×"..v.N) end;return table.concat(pieces," + ") end
local function recipeMatches(id,r)
 if searchQuery=="" then return true end
 local values={id,(r.Output and r.Output.Id) or "",(r.Output and name(r.Output.Id)) or "",r.Category or ""}
 for _,ingredient in ipairs(r.Ingredients or {}) do table.insert(values,ingredient.Id);table.insert(values,name(ingredient.Id)) end
 for _,value in ipairs(values) do if string.find(string.lower(tostring(value or "")),searchQuery,1,true) then return true end end
 return false
end
render=function(reset)
 if not state then return end
 local pos=content.CanvasPosition
 fuelLabel=nil
 for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 for _,child in ipairs(actions:GetChildren()) do child:Destroy() end
 title.Text=(Catalog.Stations[state.StationType].Name).." · Grade "..state.Grade
 if state.StationType=="Workbench" then title.Text=(state.Grade>=7 and "Master Workbench" or state.Grade>=4 and "Advanced Workbench" or "Workbench").." · Grade "..state.Grade end
 local furnace=state.StationType=="Furnace"
 tabs.Visible=furnace
 if not furnace then page="Station" end
 search.Visible=state.StationType=="Furnace" and page=="Recipes"
 actions.Visible=furnace and page=="Detail"
 local compactHeight=panel.Size.Y.Offset<360
 progress.Visible=furnace and not compactHeight;work.Visible=progress.Visible
 local toolbarTop=compactHeight and 110 or 160
 search.Position=UDim2.fromOffset(16,toolbarTop);actions.Position=search.Position
 local top=not furnace and 64 or ((search.Visible or actions.Visible) and toolbarTop+52 or toolbarTop)
 content.Position=UDim2.fromOffset(16,top);content.Size=UDim2.new(1,-32,1,-top-48)
 local compact=panel.Size.X.Offset<440
 for _,entry in ipairs({{recipesTab,"Recipes","Flame","Craft",page=="Recipes" or page=="Detail"},{queueTab,"Output","Collect","Collect",page=="Queue"},{stationTab,"Fuel","Flame","Fuel",page=="Station"}}) do
  entry[1]:SetAttribute("ActionLabel",entry[2]);entry[1].Text=compact and "" or entry[2];Theme.StationStyle(entry[1],entry[3],entry[4],compact);entry[1].BackgroundTransparency=entry[5] and 0 or .45
 end
 if page=="Recipes" then
  local recipes={};for id,r in pairs(Catalog.Recipes) do if table.find(r.AllowedStations or {},"Furnace") and recipeMatches(id,r) then table.insert(recipes,{Id=id,Recipe=r}) end end
  table.sort(recipes,function(a,b)return a.Recipe.RequiredGrade==b.Recipe.RequiredGrade and a.Id<b.Id or a.Recipe.RequiredGrade<b.Recipe.RequiredGrade end)
  for _,entry in ipairs(recipes) do
   local r=entry.Recipe
   button(content,string.format("%s ×%d  ·  G%d  ·  %ds",name(r.Output.Id),r.Output.N,r.RequiredGrade,r.BaseCraftTime),function()recipeId=entry.Id;page="Detail";render(true) end,"Mineral","Fuel")
  end
 elseif page=="Detail" then
  local r=Catalog.Recipes[recipeId]
  label(content,name(r.Output.Id).." · grade "..r.RequiredGrade.." / campaign "..r.CampaignTier,42)
  local minus=button(actions,"−",function()quantity=math.max(1,quantity-1);render() end);minus.Size=UDim2.fromOffset(40,44)
  local count=label(actions,tostring(quantity),44);count.Position=UDim2.fromOffset(44,0);count.Size=UDim2.fromOffset(44,44);count.TextXAlignment=Enum.TextXAlignment.Center
  local plus=button(actions,"+",function()quantity=math.min(20,quantity+1);render() end);plus.Position=UDim2.fromOffset(92,0);plus.Size=UDim2.fromOffset(40,44)
  local locked=r.RequiredGrade>state.Grade or r.CampaignTier>state.CampaignTier
  local queue=button(actions,locked and "Locked" or "Smelt",function()if not locked then send("Queue",{RecipeId=recipeId,Quantity=quantity}) else status.Text="Requires station grade "..r.RequiredGrade.." / campaign "..r.CampaignTier end end,"Flame",locked and "Neutral" or "Craft")
  queue.Position=UDim2.fromOffset(140,0);queue.Size=UDim2.new(1,-140,1,0)
  label(content,quantity.." batches · "..quantity*r.BaseCraftTime.."s work",28).TextColor3=colors.Amber
  for _,entry in ipairs(r.Ingredients) do button(content,name(entry.Id).." ×"..entry.N*quantity,function()Guide.Open(entry.Id,{PreferredStationType="Furnace"}) end,"Search") end
 elseif page=="Queue" then
  label(content,"Ready to collect",30).TextColor3=colors.Cold
  local ready=0
  for i,slot in ipairs(state.State.Output) do if slot then ready+=1;button(content,name(slot.Id).." ×"..slot.N,function()send("Collect",{Index=i}) end,"Collect","Collect") end end
  if ready==0 then label(content,"Nothing ready yet.",30) end
  label(content,"Queue",30).TextColor3=colors.Amber
  for i,job in ipairs(state.State.Jobs) do button(content,name(job.Output.Id).." ×"..job.Remaining.." · cancel",function()send("Cancel",{Index=i}) end,"Close","Danger") end
 else
  if furnace then
   fuelLabel=label(content,"Fuel: "..math.floor(state.State.FuelWork).."s",36);fuelLabel.TextColor3=colors.Amber
   button(content,state.State.Enabled and "Pause" or "Resume",function()send("Toggle") end,state.State.Enabled and "Pause" or "Play","Fuel")
   local fuels=make("Frame",content,{Size=UDim2.new(1,0,0,76),BackgroundTransparency=1})
   for index,id in ipairs({"Wood","Peat","Coal"}) do
    local b=button(fuels,name(id).." +1\n"..Catalog.FurnaceFuels[id].."s",function()send("Fuel",{ItemId=id,Quantity=1}) end,"Flame","Fuel")
    b.Position=UDim2.new((index-1)/3,0,0,0);b.Size=UDim2.new(1/3,-6,1,0);b.TextSize=14
    Theme.StationTile(b,"Flame","Fuel")
   end
  end
  if table.find({"Anvil","Loom","RepairBench","Workbench"},state.StationType) then
   button(content,"Repair / upgrade gear",function()
    local event=player.PlayerGui:FindFirstChild("OpenGearWorkshop")
    if event and event:IsA("BindableEvent") then event:Fire(state.Station);gui.Enabled=false;send("Close") end
   end,"Craft","Collect")
  end
  if state.Grade<8 then
   button(content,"Upgrade station · G"..(state.Grade+1),function()send("Upgrade") end,"Upgrade","Special")
   label(content,costs(state.UpgradeCost),48)
   if state.CampaignTier<=state.Grade then label(content,"Complete the next campaign tier first.",36).TextColor3=colors.Warning end
  else label(content,"Station fully upgraded",40) end
 end
 content.CanvasPosition=reset and Vector2.zero or pos
end
search:GetPropertyChangedSignal("Text"):Connect(function()
 searchQuery=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
 if gui.Enabled and state and page=="Recipes" then render(true) end
end)
remote.OnClientEvent:Connect(function(kind,payload)
 if kind=="Close" then gui.Enabled=false;state=nil;return end
 if kind=="Result" then if payload.Message then status.Text=payload.Message end;return end
 if kind~="Snapshot" then return end
 local fresh=not state or state.Station~=payload.Station
 state=payload;gui.Enabled=true
 if fresh then page=state.StationType=="Furnace" and "Recipes" or "Station";recipeId=nil;quantity=1;searchQuery="";search.Text="" end
 if payload.Message then status.Text=payload.Message end
 local bits={tostring(state.Grade),tostring(state.CampaignTier),tostring(state.State.Enabled)}
 for _,job in ipairs(state.State.Jobs) do table.insert(bits,job.RecipeId..job.Remaining) end
 for i,slot in ipairs(state.State.Output) do if slot then table.insert(bits,i..slot.Id..slot.N) end end
 local nextSignature=table.concat(bits,"|")
 if fresh or signature~=nextSignature then render(fresh);signature=nextSignature end
 if fuelLabel then fuelLabel.Text="Fuel: "..math.floor(state.State.FuelWork).."s" end
 local job=state.State.Jobs[1]
 fill.Size=UDim2.fromScale(job and math.clamp(job.Work/job.WorkRequired,0,1) or 0,1)
 work.Text=job and string.format("%s ×%d · %ds fuel",name(job.Output.Id),job.Remaining,math.floor(state.State.FuelWork)) or "No work queued"
end)
UIS.InputBegan:Connect(function(input,processed)if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then close() end end)
Theme.BindResponsive(gui,function(mobile,available)
 panel.Size=UDim2.fromOffset(math.max(280,math.min(850,available.X-20)),math.max(230,math.min(mobile and available.Y-16 or 740,available.Y-16)))
 if gui.Enabled then render() end
end)
