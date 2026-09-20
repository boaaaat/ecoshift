-- Shared furnace work and station upgrades use one mobile-friendly scrolling surface.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Shared=RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode()~="Expedition" then return end
local Theme=require(Shared.UI.UITheme)
local UIFactory=require(Shared.UI.UIFactory)
local RemoteRequest=require(Shared.UI.RemoteRequest)
local Catalog=require(Shared.OverhaulCatalog)
local Items=require(Shared.Items.ItemDatabase)
local Ingredients=require(Shared.IngredientResolver)
local Workbench=require(Shared.WorkbenchConfig)
local Guide=require(Shared.UI.RecipeGuideUI)
local SearchRank=require(Shared.UI.SearchRank)
local player=Players.LocalPlayer
local remote=RS:WaitForChild("Remotes"):WaitForChild("Station")
local inventoryRemote=RS.Remotes:WaitForChild("InventoryUpdate")
local inventory={}
local inventorySignature=""
local colors=Theme.Colors
local make=UIFactory.Create
local requests=RemoteRequest.new(remote)
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
 local payload=extra or {};payload.Station=state.Station
 requests:Send(action,payload,{
  Track=action~="Close",
  Timeout=8,
  OnBusy=function()status.Text="Waiting for the furnace…" end,
  OnStart=function()status.Text="Sending…";status.TextColor3=colors.Amber end,
  OnTimeout=function()status.Text="No reply from the furnace. Reopen it to refresh.";status.TextColor3=colors.Warning;if gui.Enabled then render() end end,
 })
end
local function close()send("Close");requests:Cancel();gui.Enabled=false;state=nil end
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
work.Size=UDim2.new(1,-160,0,30)
local fuelQuick=button(panel,"0s",function()page="Station";render(true) end,"Flame","Fuel")
fuelQuick.Position=UDim2.new(1,-140,0,106);fuelQuick.Size=UDim2.fromOffset(124,34)
local function name(id)local item=Items:Get(id);return item and item.Name or id end
local function owned(id)return Ingredients.Count(inventory,id) end
local function affordable(recipe)return Ingredients.Max(recipe.Ingredients,inventory,player,20) end
local function itemGlyph(item,id)
 if item then
  if item:HasTag("Mineral") or item:HasTag("Ore") then return "Mineral" end
  if item:HasTag("Food") then return "Food" end
  if item:HasTag("Armor") then return "Armor" end
 end
 local key=string.lower(id or "")
 if key:find("wood") or key:find("plank") or key:find("fiber") or key:find("reeds") then return "Leaf" end
 if key:find("ore") or key:find("bar") or key:find("metal") or key:find("stone") or key:find("glass") or key:find("crystal") then return "Mineral" end
 if key:find("cloth") or key:find("hide") or key:find("wool") then return "Armor" end
 return "Craft"
end
local function iconWell(parent,itemId,size)
 local item=Items:Get(itemId);local glyph=itemGlyph(item,itemId)
 local tint=item and item.IconColor or (glyph=="Mineral" and colors.Cold or glyph=="Armor" and colors.Sage or colors.Moss)
 local well=make("Frame",parent,{Name="ItemIcon",Size=UDim2.fromOffset(size,size),BackgroundColor3=tint,BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=(parent.ZIndex or 1)+1})
 well:SetAttribute("ThemeFixed",true);Theme.Corner(well,8)
 local asset=item and type(item.Icon)=="string" and item.Icon or ""
 if asset~="" then
  make("ImageLabel",well,{Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,Image=asset,ScaleType=Enum.ScaleType.Fit,ZIndex=well.ZIndex+1})
 else Theme.Icon(well,glyph,math.floor(size*.52)) end
 return well
end
local function stationUnlocks(stationType,nextGrade)
 local result,seen={},{ }
 for recipeId,recipe in pairs(Catalog.Recipes) do
  if not recipe.Future and (recipe.RequiredGrade or recipe.Tier or 1)==nextGrade and table.find(recipe.AllowedStations or {},stationType) then
   local output=recipe.Output or {Id=recipeId,N=1}
   local key=output.Id..":"..tostring(output.N or 1)
   if not seen[key] then
    seen[key]=true
    table.insert(result,{Id=output.Id,N=output.N or 1,Category=recipe.Category or (recipe.Cooking and "Meal" or "Recipe")})
   end
  end
 end
 table.sort(result,function(a,b)return name(a.Id)<name(b.Id) end)
 return result
end
local function upgradeDetail(stationType,nextGrade,unlockCount)
 local stationName=(Catalog.Stations[stationType] or {}).Name or stationType
 local lines={stationName.." becomes Grade "..nextGrade.."."}
 if unlockCount>0 then table.insert(lines,"Unlocks "..unlockCount.." Grade "..nextGrade.." recipe"..(unlockCount==1 and "" or "s").." shown below.")
 else table.insert(lines,"No new recipe is assigned to this exact grade; it advances the station toward later grade requirements.") end
 if stationType=="Anvil" then
  table.insert(lines,"Can repair Grade "..nextGrade.." weapons and tools, and reforge Grade "..nextGrade.." armor families assigned to an Anvil.")
 elseif stationType=="Loom" then
  table.insert(lines,"Can repair Grade "..nextGrade.." armor and reforge Grade "..nextGrade.." armor families assigned to a Loom.")
 elseif stationType=="RepairBench" then
  table.insert(lines,"Can repair Grade "..nextGrade.." weapons, tools, and armor.")
 elseif stationType=="EnchantingTable" then
  table.insert(lines,"Can perform enchantment work whose station requirement is Grade "..nextGrade..".")
 elseif stationType=="Workbench" and (nextGrade==4 or nextGrade==7) then
  table.insert(lines,"Its field name changes to "..(nextGrade==4 and "Advanced Workbench" or "Master Workbench")..".")
 end
 if stationType=="Furnace" or table.find({"Campfire","Stove","Oven"},stationType) then
  table.insert(lines,"Queue size, processing speed, fuel value, and output space do not change.")
 else table.insert(lines,"Crafting speed and recipe material costs do not change.") end
 return table.concat(lines," ")
end
local function upgradeMaterialRow(cost,order)
 local itemId,need=cost.Id,cost.N;local have=owned(itemId);local ready=have>=need
 local row=make("TextButton",content,{Name="UpgradeMaterial_"..itemId,Size=UDim2.new(1,0,0,72),LayoutOrder=order,Text="",AutoButtonColor=false,BackgroundColor3=colors.SlotFilled,BorderSizePixel=0})
 Theme.Button(row);Theme.Corner(row,9)
 local stroke=make("UIStroke",row,{Thickness=1,Transparency=.5,Color=ready and colors.Success or colors.Border})
 local well=iconWell(row,itemId,52);well.Position=UDim2.fromOffset(10,10)
 local itemName=label(row,name(itemId),26);itemName.Position=UDim2.fromOffset(74,8);itemName.Size=UDim2.new(1,-200,0,26);itemName.Font=Enum.Font.GothamBold;itemName.TextSize=16;itemName.TextWrapped=false;itemName.TextTruncate=Enum.TextTruncate.AtEnd
 local count=label(row,have.." / "..need,26);count.Position=UDim2.new(1,-120,0,8);count.Size=UDim2.fromOffset(104,26);count.Font=Enum.Font.GothamBold;count.TextSize=16;count.TextXAlignment=Enum.TextXAlignment.Right;count.TextColor3=ready and colors.Success or colors.Warning
 local track=make("Frame",row,{Position=UDim2.fromOffset(74,45),Size=UDim2.new(1,-90,0,9),BackgroundColor3=colors.Background,BackgroundTransparency=.08,BorderSizePixel=0});Theme.Corner(track,5)
 local bar=make("Frame",track,{Size=UDim2.fromScale(math.clamp(have/math.max(1,need),0,1),1),BackgroundColor3=ready and colors.Success or colors.Amber,BorderSizePixel=0});Theme.Corner(bar,5)
 row.Activated:Connect(function()Guide.Open(itemId,{PreferredStationType=state and state.StationType})end)
 return ready
end
local function upgradeUnlockRow(unlock,order)
 local row=make("Frame",content,{Name="Unlock_"..unlock.Id,Size=UDim2.new(1,0,0,54),LayoutOrder=order,BackgroundColor3=colors.SlotEmpty,BackgroundTransparency=.12,BorderSizePixel=0});Theme.Corner(row,8)
 local well=iconWell(row,unlock.Id,38);well.Position=UDim2.fromOffset(8,8)
 local itemName=label(row,name(unlock.Id),24);itemName.Position=UDim2.fromOffset(58,5);itemName.Size=UDim2.new(1,-74,0,24);itemName.Font=Enum.Font.GothamBold;itemName.TextSize=15;itemName.TextWrapped=false;itemName.TextTruncate=Enum.TextTruncate.AtEnd
 local detail=label(row,(unlock.N>1 and ("Makes ×"..unlock.N.." · ") or "")..unlock.Category,20);detail.Position=UDim2.fromOffset(58,28);detail.Size=UDim2.new(1,-74,0,20);detail.TextSize=12;detail.TextColor3=colors.TextMuted
end
local function lockReason(recipe)
 if recipe.RequiredGrade>state.Grade then return "Needs furnace grade "..recipe.RequiredGrade end
 if recipe.CampaignTier>state.CampaignTier then return "Needs campaign tier "..recipe.CampaignTier end
end
local function fuelControls()
 local fuels=make("Frame",content,{Size=UDim2.new(1,0,0,80),BackgroundTransparency=1})
 for index,id in ipairs({"Wood","Peat","Coal"}) do
  local itemId=id;local count=owned(id)
  local b=button(fuels,name(id).." +1\n"..count.." owned",function()
   if owned(itemId)<1 then status.Text="No "..name(itemId).." in your pack";return end
   send("Fuel",{ItemId=itemId,Quantity=1})
  end)
  b.Position=UDim2.new((index-1)/3,0,0,0);b.Size=UDim2.new(1/3,-6,1,0)
  Theme.StationTile(b,"Flame",count>0 and "Fuel" or "Neutral")
 end
end
local function updateWork()
 if not state then return end
 local job=state.State.Jobs[1]
 local ratio=job and math.clamp(job.Work/math.max(.01,job.WorkRequired),0,1) or 0
 fill.Size=UDim2.fromScale(ratio,1)
 work.Text=(state.Status or "Ready")..(job and string.format(" · %s · %d%%",name(job.Output.Id),math.floor(ratio*100)) or "")
 fuelQuick.Text=math.ceil(state.State.FuelWork).."s"
 if fuelLabel then fuelLabel.Text="Fuel: "..math.ceil(state.State.FuelWork).."s stored" end
end
local function recipeSearchScore(id,r)
 local outputId=(r.Output and r.Output.Id) or id
 local secondary={r.Category or ""}
 for _,ingredient in ipairs(r.Ingredients or {}) do table.insert(secondary,ingredient.Id);table.insert(secondary,name(ingredient.Id)) end
 return SearchRank.Score(searchQuery,{name(outputId),outputId,id},secondary)
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
 progress.Visible=furnace and not compactHeight;work.Visible=progress.Visible;fuelQuick.Visible=progress.Visible
 local toolbarTop=compactHeight and 110 or 160
 search.Position=UDim2.fromOffset(16,toolbarTop);actions.Position=search.Position
 local top=not furnace and 64 or ((search.Visible or actions.Visible) and toolbarTop+52 or toolbarTop)
 content.Position=UDim2.fromOffset(16,top);content.Size=UDim2.new(1,-32,1,-top-48)
 local compact=panel.Size.X.Offset<440
 for _,entry in ipairs({{recipesTab,"Recipes","Flame","Craft",page=="Recipes" or page=="Detail"},{queueTab,"Output","Collect","Collect",page=="Queue"},{stationTab,"Fuel","Flame","Fuel",page=="Station"}}) do
  entry[1]:SetAttribute("ActionLabel",entry[2]);entry[1].Text=compact and "" or entry[2];Theme.StationStyle(entry[1],entry[3],entry[4],compact);entry[1].BackgroundTransparency=entry[5] and 0 or .45
 end
 if page=="Recipes" then
  local recipes={};for id,r in pairs(Catalog.Recipes) do
   local searchScore=recipeSearchScore(id,r)
   if table.find(r.AllowedStations or {},"Furnace") and searchScore~=nil then
    local maximum=affordable(r);local locked=lockReason(r)
    table.insert(recipes,{Id=id,Recipe=r,Maximum=maximum,Locked=locked,Group=locked and 3 or maximum>0 and 1 or 2,SearchScore=searchScore})
   end
  end
  table.sort(recipes,function(a,b)
   return SearchRank.Less(a,b,searchQuery,function(entry)return name(entry.Recipe.Output.Id)end,function(left,right)
    if left.Group~=right.Group then return left.Group<right.Group end
    if left.Recipe.RequiredGrade~=right.Recipe.RequiredGrade then return left.Recipe.RequiredGrade<right.Recipe.RequiredGrade end
    return nil
   end)
  end)
  local group
  for _,entry in ipairs(recipes) do
   local r=entry.Recipe
   if group~=entry.Group then group=entry.Group;label(content,({"Have materials","Need materials","Locked recipes"})[group],28).TextColor3=group==1 and colors.Success or colors.TextMuted end
   local caption=entry.Locked or (entry.Maximum>0 and ("Materials for ×"..entry.Maximum*r.Output.N) or "Missing materials")
   local b=button(content,name(r.Output.Id).." ×"..r.Output.N.."\n"..caption,function()recipeId=entry.Id;quantity=1;page="Detail";render(true) end,"Mineral",entry.Group==1 and "Craft" or "Neutral")
   b.Size=UDim2.new(1,0,0,58)
  end
  if #recipes==0 then label(content,"No matching furnace recipes.",40) end
 elseif page=="Detail" then
  local r=Catalog.Recipes[recipeId]
  label(content,name(r.Output.Id).." ×"..r.Output.N*quantity,36).Font=Enum.Font.GothamBold
  local minus=button(actions,"−",function()quantity=math.max(1,quantity-1);render() end);minus.Size=UDim2.fromOffset(40,44)
  local count=label(actions,tostring(quantity),44);count.Position=UDim2.fromOffset(44,0);count.Size=UDim2.fromOffset(44,44);count.TextXAlignment=Enum.TextXAlignment.Center
  local plus=button(actions,"+",function()quantity=math.min(20,quantity+1);render() end);plus.Position=UDim2.fromOffset(92,0);plus.Size=UDim2.fromOffset(40,44)
  local maximum=affordable(r)
  local blocked=lockReason(r) or (#state.State.Jobs>=3 and "Queue full — three jobs maximum") or (quantity>maximum and "Missing materials")
  local queue=button(actions,requests:IsPending() and "Sending…" or blocked and "Can't smelt" or "Smelt",function()
   if blocked then status.Text=blocked;return end
   send("Queue",{RecipeId=recipeId,Quantity=quantity})
  end,"Flame",blocked and "Neutral" or "Craft")
  queue.Position=UDim2.fromOffset(140,0);queue.Size=UDim2.new(1,-140,1,0)
  label(content,blocked or (quantity.." batches · "..quantity*r.BaseCraftTime.."s fuel required"),32).TextColor3=blocked and colors.Warning or colors.Amber
  label(content,"Materials · owned / needed",26).TextColor3=colors.TextMuted
  for _,entry in ipairs(r.Ingredients) do
   local id=entry.Id;local need=Workbench:IngredientCost(entry,player)*quantity;local have=owned(id)
   button(content,name(id).."  "..have.." / "..need,function()Guide.Open(id,{PreferredStationType="Furnace"}) end,have>=need and "Place" or "Search",have>=need and "Neutral" or "Danger")
  end
  if maximum>1 then button(content,"Max · "..maximum.." batches",function()quantity=maximum;render() end,"Queue","Craft") end
  fuelLabel=label(content,"",28);fuelLabel.TextColor3=colors.Amber
  fuelControls()
 elseif page=="Queue" then
  label(content,(state.Status or "Ready").." · "..#state.State.Jobs.." / 3 jobs",32).TextColor3=colors.Amber
  if not state.State.Enabled then button(content,"Resume smelting",function()send("Toggle") end,"Play","Fuel") end
  if state.State.FuelWork<=0 then fuelControls() end
  label(content,"Ready to collect",30).TextColor3=colors.Cold
  local ready=0
  for i=1,12 do local slot=state.State.Output[i];if slot then local index,id=i,slot.Id;ready+=1;button(content,name(id).." ×"..slot.N,function()send("Collect",{Index=index,ExpectedId=id}) end,"Collect","Collect") end end
  if ready==0 then label(content,"Nothing ready yet.",30) end
  label(content,"Queue",30).TextColor3=colors.Amber
  if #state.State.Jobs>0 then label(content,"Materials are stored here until smelted or refunded.",28).TextColor3=colors.TextMuted end
  for i,job in ipairs(state.State.Jobs) do
   local index,jobId=i,job.Id
   button(content,name(job.Output.Id).." ×"..job.Remaining*job.Output.N.." · cancel / refund",function()send("Cancel",{Index=index,JobId=jobId}) end,"Close","Danger")
  end
 else
  if furnace then
   fuelLabel=label(content,"Fuel: "..math.floor(state.State.FuelWork).."s",36);fuelLabel.TextColor3=colors.Amber
   button(content,state.State.Enabled and "Pause" or "Resume",function()send("Toggle") end,state.State.Enabled and "Pause" or "Play","Fuel")
   fuelControls()
   label(content,"Wood 15s · Peat 30s · Coal 60s\nFuel is stored until a queued job uses it.",46).TextColor3=colors.TextMuted
  end
  if table.find({"Anvil","Loom","RepairBench","Workbench"},state.StationType) then
   button(content,"Repair / upgrade gear",function()
    local event=player.PlayerGui:FindFirstChild("OpenGearWorkshop")
    if event and event:IsA("BindableEvent") then event:Fire(state.Station);gui.Enabled=false;send("Close") end
   end,"Craft","Collect")
  end
  if state.Grade<8 then
   local nextGrade=state.Grade+1
   local unlocks=stationUnlocks(state.StationType,nextGrade)
   local summary=make("Frame",content,{Name="UpgradeSummary",Size=UDim2.new(1,0,0,132),BackgroundColor3=colors.SlotFilled,BorderSizePixel=0});Theme.Corner(summary,10)
   local summaryStroke=make("UIStroke",summary,{Color=colors.Special,Transparency=.35,Thickness=1})
   local badge=make("Frame",summary,{Size=UDim2.fromOffset(94,38),Position=UDim2.fromOffset(12,12),BackgroundColor3=Color3.fromRGB(88,67,110),BorderSizePixel=0});badge:SetAttribute("ThemeFixed",true);Theme.Corner(badge,7)
   local badgeIcon=Theme.Icon(badge,"Upgrade",21);badgeIcon.Position=UDim2.new(0,22,.5,0)
   local badgeText=label(badge,"G"..state.Grade.."  ›  G"..nextGrade,38);badgeText.Position=UDim2.fromOffset(38,0);badgeText.Size=UDim2.new(1,-42,1,0);badgeText.Font=Enum.Font.GothamBold;badgeText.TextSize=13
   local heading=label(summary,"STATION UPGRADE",30);heading.Position=UDim2.fromOffset(118,10);heading.Size=UDim2.new(1,-132,0,30);heading.Font=Enum.Font.GothamBold;heading.TextSize=18;heading.TextColor3=colors.Special
   local detailText=upgradeDetail(state.StationType,nextGrade,#unlocks)
   local detail=label(summary,detailText,72);detail.Position=UDim2.fromOffset(14,54);detail.Size=UDim2.new(1,-28,0,68);detail.TextSize=13;detail.TextColor3=colors.TextMuted;detail.TextYAlignment=Enum.TextYAlignment.Top
   label(content,"UPGRADE MATERIALS · OWNED / REQUIRED",26).TextColor3=colors.Amber
   local materialsReady=true
   for index,cost in ipairs(state.UpgradeCost or {}) do if not upgradeMaterialRow(cost,20+index) then materialsReady=false end end
   if #unlocks>0 then
    local unlockHeader=label(content,"NEW RECIPES AT GRADE "..nextGrade,28);unlockHeader.TextColor3=colors.Cold;unlockHeader.LayoutOrder=40
    for index,unlock in ipairs(unlocks) do upgradeUnlockRow(unlock,40+index) end
   end
   local campaignReady=state.CampaignTier>=nextGrade
   local canUpgrade=materialsReady and campaignReady and not requests:IsPending()
   local upgradeText=requests:IsPending() and "UPGRADING…" or not campaignReady and ("CAMPAIGN TIER "..nextGrade.." REQUIRED") or not materialsReady and "MISSING UPGRADE MATERIALS" or ("UPGRADE TO GRADE "..nextGrade)
   local upgradeButton=button(content,upgradeText,function()
    if requests:IsPending() then return end
    if not campaignReady then status.Text="Complete campaign tier "..nextGrade.." first.";status.TextColor3=colors.Warning;return end
    if not materialsReady then status.Text="Collect the missing upgrade materials first.";status.TextColor3=colors.Warning;return end
    send("Upgrade")
   end,"Upgrade",canUpgrade and "Special" or "Neutral")
   upgradeButton.LayoutOrder=100;upgradeButton.Active=canUpgrade;upgradeButton.Selectable=canUpgrade
   if not campaignReady then local warning=label(content,"Campaign certification controls the maximum station grade.",34);warning.LayoutOrder=101;warning.TextColor3=colors.Warning end
  else
   local complete=make("Frame",content,{Size=UDim2.new(1,0,0,92),BackgroundColor3=colors.SlotFilled,BorderSizePixel=0});Theme.Corner(complete,10)
   local icon=iconWell(complete,state.StationType,54);icon.Position=UDim2.fromOffset(12,19)
   local done=label(complete,"STATION FULLY UPGRADED",30);done.Position=UDim2.fromOffset(78,16);done.Size=UDim2.new(1,-94,0,30);done.Font=Enum.Font.GothamBold;done.TextSize=18;done.TextColor3=colors.Success
   local copy=label(complete,"Grade 8 · every available station-grade function is enabled.",28);copy.Position=UDim2.fromOffset(78,46);copy.Size=UDim2.new(1,-94,0,28);copy.TextColor3=colors.TextMuted
  end
 end
 content.CanvasPosition=reset and Vector2.zero or pos
 updateWork()
end
search:GetPropertyChangedSignal("Text"):Connect(function()
 searchQuery=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
 if gui.Enabled and state and page=="Recipes" then render(true) end
end)
remote.OnClientEvent:Connect(function(kind,payload)
 if type(payload)~="table" then return end
 if kind=="Close" then gui.Enabled=false;state=nil;requests:Cancel();return end
 if kind=="Result" then
  if payload.Station and state and payload.Station~=state.Station then return end
  local completed=requests:Resolve(payload.RequestId)
  if payload.Message then status.Text=payload.Message;status.TextColor3=payload.Success and colors.Success or colors.Warning end
  if completed and payload.Success and completed.Action=="Queue" then page="Queue" end
  if gui.Enabled then render(completed and payload.Success and completed.Action=="Queue") end
  return
 end
 if kind~="Snapshot" or type(payload.State)~="table" then return end
 local fresh=not state or state.Station~=payload.Station
 state=payload;gui.Enabled=true
 local output={};for i=1,12 do output[i]=state.State.Output and (state.State.Output[i] or state.State.Output[tostring(i)]) or false end;state.State.Output=output
 if fresh then
  requests:Cancel();page=state.StationType=="Furnace" and "Recipes" or "Station";recipeId=nil;quantity=1;searchQuery="";search.Text=""
  status.Text="Choose a recipe; green rows have enough materials.";status.TextColor3=colors.TextMuted
  inventoryRemote:FireServer("RequestSnapshot")
 end
 if payload.Message then status.Text=payload.Message end
 local bits={tostring(state.Grade),tostring(state.CampaignTier),tostring(state.State.Enabled),tostring(state.Status)}
 for _,job in ipairs(state.State.Jobs) do table.insert(bits,tostring(job.Id)..job.RecipeId..job.Remaining) end
 for i,slot in ipairs(state.State.Output) do if slot then table.insert(bits,i..slot.Id..slot.N) end end
 local nextSignature=table.concat(bits,"|")
 if fresh or signature~=nextSignature then render(fresh);signature=nextSignature end
 updateWork()
end)
inventoryRemote.OnClientEvent:Connect(function(kind,payload)
 if kind~="Snapshot" or type(payload)~="table" then return end
 inventory=payload
 local counts={}
 for _,bag in ipairs({payload.Hotbar or {},payload.Storage or {}}) do
  for _,entry in pairs(bag) do if entry then counts[entry.Id]=(counts[entry.Id] or 0)+entry.N end end
 end
 local bits={};for id,n in pairs(counts) do table.insert(bits,id..":"..n) end;table.sort(bits)
 local nextSignature=table.concat(bits,"|")
 if nextSignature~=inventorySignature then
  inventorySignature=nextSignature
  if gui.Enabled and state then render() end
 end
end)
inventoryRemote:FireServer("RequestSnapshot")
UIS.InputBegan:Connect(function(input,processed)if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then close() end end)
Theme.BindResponsive(gui,function(mobile,available)
 panel.Size=UDim2.fromOffset(math.max(280,math.min(850,available.X-20)),math.max(230,math.min(mobile and available.Y-16 or 740,available.Y-16)))
 if gui.Enabled then render() end
end)
