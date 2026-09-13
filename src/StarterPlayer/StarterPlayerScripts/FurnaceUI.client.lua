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
local function button(parent,value,fn)
 local b=make("TextButton",parent,{Size=UDim2.new(1,0,0,46),Text=value,TextColor3=colors.Text,Font=Enum.Font.GothamMedium,TextSize=16,TextWrapped=true,BackgroundColor3=colors.SlotEmpty});Theme.Button(b);b.Activated:Connect(fn);return b
end
local state,recipeId,page,quantity,signature=nil,nil,"Recipes",1,""
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
local x=button(panel,"×",close);x.Size=UDim2.fromOffset(44,44);x.Position=UDim2.new(1,-58,0,8)
local tabs=make("Frame",panel,{Position=UDim2.fromOffset(16,58),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1})
local recipesTab=button(tabs,"Recipes",function()page="Recipes";render(true) end);recipesTab.Size=UDim2.new(.5,-4,1,0)
local queueTab=button(tabs,"Station / queue",function()page="Station";render(true) end);queueTab.Position=UDim2.new(.5,4,0,0);queueTab.Size=UDim2.new(.5,-4,1,0)
local content=make("ScrollingFrame",panel,{Name="Content",Position=UDim2.fromOffset(16,110),Size=UDim2.new(1,-32,1,-198),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",content,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",content,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
local progress=make("Frame",panel,{Size=UDim2.new(1,-32,0,8),Position=UDim2.new(0,16,1,-72),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0});Theme.Corner(progress,4)
local fill=make("Frame",progress,{Size=UDim2.fromScale(0,1),BackgroundColor3=colors.Amber,BorderSizePixel=0});Theme.Corner(fill,4)
local work=label(panel,"No work queued",22);work.Position=UDim2.new(0,16,1,-64);work.Size=UDim2.new(1,-32,0,22);work.TextSize=14
local function name(id)local item=Items:Get(id);return item and item.Name or id end
local function costs(list)local pieces={};for _,v in ipairs(list or {}) do table.insert(pieces,name(v.Id).." ×"..v.N) end;return table.concat(pieces," + ") end
render=function(reset)
 if not state then return end
 local pos=content.CanvasPosition
 fuelLabel=nil
 for _,child in ipairs(content:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 title.Text=(Catalog.Stations[state.StationType].Name).." · Grade "..state.Grade
 if state.StationType=="Workbench" then title.Text=(state.Grade>=7 and "Master Workbench" or state.Grade>=4 and "Advanced Workbench" or "Workbench").." · Grade "..state.Grade end
 recipesTab.Visible=state.StationType=="Furnace"
 if state.StationType~="Furnace" then page="Station" end
 if page=="Recipes" then
  local recipes={};for id,r in pairs(Catalog.Recipes) do if table.find(r.AllowedStations or {},"Furnace") then table.insert(recipes,{Id=id,Recipe=r}) end end
  table.sort(recipes,function(a,b)return a.Recipe.RequiredGrade==b.Recipe.RequiredGrade and a.Id<b.Id or a.Recipe.RequiredGrade<b.Recipe.RequiredGrade end)
  for _,entry in ipairs(recipes) do
   local r=entry.Recipe
   button(content,string.format("%s ×%d  ·  Grade %d  ·  %ds",name(r.Output.Id),r.Output.N,r.RequiredGrade,r.BaseCraftTime),function()recipeId=entry.Id;page="Detail";render(true) end)
  end
 elseif page=="Detail" then
  local r=Catalog.Recipes[recipeId]
  button(content,"‹ All furnace recipes",function()page="Recipes";render(true) end)
  label(content,name(r.Output.Id).." · grade "..r.RequiredGrade.." / campaign "..r.CampaignTier,42)
  for _,entry in ipairs(r.Ingredients) do button(content,name(entry.Id).." ×"..entry.N.." per batch · source / recipe →",function()Guide.Open(entry.Id,{PreferredStationType="Furnace"}) end) end
  label(content,"Fuel is separate: Wood 15 / Peat 30 / Coal 60 work-seconds.",44)
  local controls=make("Frame",content,{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1})
  local minus=button(controls,"−",function()quantity=math.max(1,quantity-1);render() end);minus.Size=UDim2.new(.2,-4,1,0)
  local count=label(controls,tostring(quantity).." batches",46);count.Position=UDim2.fromScale(.22,0);count.Size=UDim2.fromScale(.56,1);count.TextXAlignment=Enum.TextXAlignment.Center
  local plus=button(controls,"+",function()quantity=math.min(20,quantity+1);render() end);plus.Position=UDim2.fromScale(.8,0);plus.Size=UDim2.new(.2,-4,1,0)
  local locked=r.RequiredGrade>state.Grade or r.CampaignTier>state.CampaignTier
  button(content,locked and ("Requires station / campaign grade "..r.RequiredGrade) or ("Queue "..quantity.." batches · "..quantity*r.BaseCraftTime.." work-seconds"),function()if not locked then send("Queue",{RecipeId=recipeId,Quantity=quantity}) end end)
 else
  if table.find({"Anvil","Loom","RepairBench","Workbench"},state.StationType) then
   button(content,"Gear maintenance / upgrades",function()
    local event=player.PlayerGui:FindFirstChild("OpenGearWorkshop")
    if event and event:IsA("BindableEvent") then event:Fire(state.Station);gui.Enabled=false;send("Close") end
   end)
  end
  if state.Grade<8 then
   label(content,"Next grade "..(state.Grade+1)..": "..costs(state.UpgradeCost),68)
   button(content,state.CampaignTier>state.Grade and "Purchase station upgrade" or "Complete the next campaign certification first",function()send("Upgrade") end)
  else label(content,"Station fully upgraded",40) end
  if state.StationType=="Furnace" then
   fuelLabel=label(content,"Fuel: "..math.floor(state.State.FuelWork).." work-seconds. Unused fuel is saved.",44)
   for _,id in ipairs({"Wood","Peat","Coal"}) do button(content,"Add "..name(id).." ×1 ("..Catalog.FurnaceFuels[id].." work-seconds)",function()send("Fuel",{ItemId=id,Quantity=1}) end) end
   button(content,state.State.Enabled and "Pause furnace" or "Resume furnace",function()send("Toggle") end)
   for i,job in ipairs(state.State.Jobs) do button(content,"Cancel "..name(job.Output.Id).." · "..job.Remaining.." batches remaining",function()send("Cancel",{Index=i}) end) end
   for i,slot in ipairs(state.State.Output) do if slot then button(content,"Collect "..name(slot.Id).." ×"..slot.N,function()send("Collect",{Index=i}) end) end
  else label(content,"Upgrading raises station capability. Existing recipes keep their exact costs and outputs.",62) end
 end
 content.CanvasPosition=reset and Vector2.zero or pos
end
remote.OnClientEvent:Connect(function(kind,payload)
 if kind=="Close" then gui.Enabled=false;state=nil;return end
 if kind=="Result" then if payload.Message then status.Text=payload.Message end;return end
 if kind~="Snapshot" then return end
 local fresh=not state or state.Station~=payload.Station
 state=payload;gui.Enabled=true
 if fresh then page=state.StationType=="Furnace" and "Recipes" or "Station";recipeId=nil;quantity=1 end
 if payload.Message then status.Text=payload.Message end
 local bits={tostring(state.Grade),tostring(state.CampaignTier),tostring(state.State.Enabled)}
 for _,job in ipairs(state.State.Jobs) do table.insert(bits,job.RecipeId..job.Remaining) end
 for i,slot in ipairs(state.State.Output) do if slot then table.insert(bits,i..slot.Id..slot.N) end end
 local nextSignature=table.concat(bits,"|")
 if fresh or signature~=nextSignature then render(fresh);signature=nextSignature end
 if fuelLabel then fuelLabel.Text="Fuel: "..math.floor(state.State.FuelWork).." work-seconds. Unused fuel is saved." end
 local job=state.State.Jobs[1]
 fill.Size=UDim2.fromScale(job and math.clamp(job.Work/job.WorkRequired,0,1) or 0,1)
 work.Text=job and string.format("%s · %d batches · %.1f work-seconds fuel",name(job.Output.Id),job.Remaining,state.State.FuelWork) or "No work queued"
end)
UIS.InputBegan:Connect(function(input,processed)if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then close() end end)
Theme.BindResponsive(gui,function(mobile,available)
 panel.Size=UDim2.fromOffset(math.max(280,math.min(850,available.X-20)),math.max(230,math.min(mobile and available.Y-16 or 740,available.Y-16)))
end)
