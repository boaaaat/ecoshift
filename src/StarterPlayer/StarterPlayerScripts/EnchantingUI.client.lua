local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Shared=RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode()~="Expedition" then return end
local Theme=require(Shared.UI.UITheme)
local Catalog=require(Shared.OverhaulCatalog)
local Items=require(Shared.Items.ItemDatabase)
local player=Players.LocalPlayer
local remotes=RS:WaitForChild("Remotes")
local remote=remotes:WaitForChild("Enchanting",120)
if not remote then return end
local colors=Theme.Colors
local function make(class,parent,props)local o=Instance.new(class);for k,v in pairs(props or {}) do o[k]=v end;o.Parent=parent;return o end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="EnchantingUI",ResetOnSpawn=false,Enabled=false,DisplayOrder=68})
local panel=make("CanvasGroup",gui,{Size=UDim2.new(.95,0,.92,0),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=colors.Panel,BorderSizePixel=0})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(900,820)});Theme.Panel(panel);Theme.CaptureCursor(panel);Theme.TrackRoot(gui)
local title=make("TextLabel",panel,{Position=UDim2.fromOffset(18,8),Size=UDim2.new(1,-90,0,48),Text="Gear workshop",Font=Enum.Font.GothamBold,TextSize=24,TextColor3=colors.Text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left})
local close=make("TextButton",panel,{Position=UDim2.new(1,-60,0,10),Size=UDim2.fromOffset(44,44),Text="×",TextSize=28});Theme.Button(close);close.Activated:Connect(function()gui.Enabled=false end)
local list=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(18,65),Size=UDim2.new(1,-36,1,-123),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5})
make("UIListLayout",list,{Padding=UDim.new(0,8)})
local status=make("TextLabel",panel,{Position=UDim2.new(0,18,1,-52),Size=UDim2.new(1,-36,0,44),Text="Choose an item.",TextSize=15,TextColor3=colors.Text,Font=Enum.Font.Gotham,TextWrapped=true,BackgroundTransparency=1})
local state,selected,enchantment,page,pending,inventory,workshop=nil,nil,nil,"Gear",false,nil,false
local render
local function name(id)local item=Items:Get(id);return item and item.Name or id end
local function text(value,height,size)return make("TextLabel",list,{Size=UDim2.new(1,-12,0,height or 40),Text=value,TextSize=size or 17,TextWrapped=true,TextColor3=colors.Text,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1}) end
local function button(value,fn)
 local b=make("TextButton",list,{Size=UDim2.new(1,-12,0,50),Text=value,TextSize=17,TextWrapped=true,Font=Enum.Font.GothamMedium});Theme.Button(b);b.Activated:Connect(fn);return b
end
local function send(action,extra)
 if pending or not state then return end
 local payload=extra or {};payload.Station=state.Station;payload.Uid=selected;payload.Enchantment=payload.Enchantment or enchantment;payload.RequestId=Http:GenerateGUID(false)
 pending=true;status.Text="Sending…";remote:FireServer(action,payload)
 task.delay(5,function()if pending then pending=false;status.Text="No reply yet. Reopen the station to refresh." end end)
end
local function entry()
 for _,e in ipairs(state and state.Gear or {}) do if e.Uid==selected then return e end end
end
local function rank(e,id)local v=e and e.Enchantments and e.Enchantments[id];return tonumber(type(v)=="table" and (v.Level or v.Rank) or v) or 0 end
local function maintenance(action,extra)
 local r=remotes:FindFirstChild("GearAction");if not r or not selected then return end
 local payload=extra or {};payload.Uid=selected;status.Text="Working…";r:FireServer(action,payload)
end
local function go(nextPage)page=nextPage;render(true) end
render=function(reset)
 if not state or not gui.Enabled then return end
 local y=reset and 0 or list.CanvasPosition.Y
 for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 if page=="Gear" then
  title.Text=workshop and "Gear maintenance" or "Enchanting workshop"
  if not workshop then
   button("Craft Enchanting Dust",function()gui.Enabled=false;require(Shared.UI.RecipeGuideUI).Open("EnchantingDust",{PreferredStationType="EnchantingTable"}) end)
   for source,options in pairs(state.Choices or {}) do
    text("Choose a crew schematic · "..source,44,20)
    for _,id in ipairs(options) do button(Catalog.Enchantments[id].Name..((state.ChoiceRanks or {})[source]=="Maximum" and " � final rank" or ""),function()send("Choose",{Source=source,Enchantment=id}) end) end
   end
   for _,id in ipairs(state.Pages or {}) do button("Read "..name(id),function()send("Read",{ItemId=id}) end) end
  end
  text("Select a piece of gear",38,20)
  for _,e in ipairs(state.Gear or {}) do
   button(name(e.Id).." · grade "..e.Grade..(e.Durability and string.format(" · %d / %d durability",e.Durability,e.MaxDurability) or ""),function()selected=e.Uid;go(workshop and "Maintenance" or "Enchantments") end)
  end
 else
  local e=entry();if not e then page="Gear";render(true);return end
  title.Text=name(e.Id).." · grade "..e.Grade
  button("‹ "..(page=="Detail" and "Enchantments" or "All gear"),function()go(page=="Detail" and "Enchantments" or "Gear") end)
  if page=="Maintenance" then
   local def=Catalog.Gear[e.Id]
   text("Repairs and upgrades require the matching nearby station. Work completes while you stay nearby; leaving cancels it without payment.",88,16)
   local repairCost=Catalog.GetRepairCost(e.Id,e.Grade,e.Durability)
   local parts={};for _,cost in ipairs(repairCost or {}) do table.insert(parts,cost.N.." "..name(cost.Id)) end
   text("Repair: "..(#parts>0 and table.concat(parts," + ") or "No repair needed"),55,16)
   button("Repair durability",function()maintenance("RepairStation") end)
   if e.Grade<8 then button("Reforge to grade "..(e.Grade+1),function()maintenance("Reforge",{Grade=e.Grade+1}) end) end
   button("Awaken with the matching deep-region trophy",function()maintenance("Awaken") end)
   button("Refill air / instrument / traversal supply",function()maintenance("Refill") end)
   if rank(e,"CampStitch")>0 then button("Camp Stitch · 1 Resin · once per visit",function()maintenance("CampStitch") end) end
  elseif page=="Enchantments" then
   local count=0;for _ in pairs(e.Enchantments or {}) do count+=1 end
   text(count.." / "..Catalog.EnchantmentSlots(Catalog.Gear[e.Id].Kind,e.Grade).." enchantment slots",38)
   local ids={};for id in pairs(Catalog.Enchantments) do table.insert(ids,id) end;table.sort(ids)
   for _,id in ipairs(ids) do
    local def=Catalog.Enchantments[id]
    local current=rank(e,id)
    local gear=table.clone(Catalog.Gear[e.Id]);gear.Grade=e.Grade
    if current>0 or Catalog.CanEnchant(gear,def,math.max(1,current)) then
     button(def.Name..(current>0 and " · rank "..current.." / "..def.MaxLevel or " · "..def.MaxLevel.." ranks"),function()enchantment=id;go("Detail") end)
    end
   end
  elseif page=="Detail" then
   local def=Catalog.Enchantments[enchantment];local current=rank(e,enchantment);local nextRank=current+1
   text(def.Name.." · "..current.." / "..def.MaxLevel,38,22)
   text(def.Description,160,16)
   text("Found through "..def.Source,80,15)
   if def.Grades[nextRank] then
    local cost=Catalog.EnchantingCosts[def.Grades[nextRank]]
    text(string.format("Rank %d needs grade %d · %d Dust + %d %s + %d %s%s",nextRank,def.Grades[nextRank],cost.Dust,cost.Material,name(Catalog.GetMaterial(e.Grade)),cost.Theme,name(enchantment=="OpenSeam" and nextRank>=2 and "DeepResin" or def.Theme),nextRank==def.MaxLevel and def.Trophy~="" and (" + "..name(def.Trophy)) or ""),86)
    local known=state.Known[enchantment] and state.Known[enchantment][tostring(nextRank)]
    button(known and "Apply next rank" or "Schematic not discovered",function()if known then send("Enchant") else status.Text="Find or choose this rank's schematic first." end end)
   end
   for _,id in ipairs(state.Scrolls or {}) do
    local scroll=Catalog.Items[id].Scroll
    if scroll.Id==enchantment then button("Apply "..name(id).." · half material/theme cost",function()send("ApplyScroll",{ItemId=id}) end) end
   end
   if current>0 then
    local cost=Catalog.EnchantingCosts[def.Grades[current]]
    button("Extract scroll · "..math.ceil(cost.Dust/2).." Dust + 1 Glass",function()send("Extract") end)
    local confirm=false
    button("Remove enchantment",function()if confirm then send("Remove") else confirm=true;status.Text="Press Remove again to destroy this enchantment without a refund." end end)
   end
  end
 end
 task.defer(function()list.CanvasPosition=Vector2.new(0,y) end)
end
remote.OnClientEvent:Connect(function(action,a,b)
 if action=="Open" or action=="State" then
  state=a;workshop=false
  if action=="Open" then gui.Enabled=true;page="Gear";selected=nil end
  render(action=="Open")
 elseif action=="Result" then pending=false;status.Text=b or (a and "Ready." or "Unavailable.") end
end)
local function refreshWorkshop()
 if not inventory or not workshop then return end
 state.Gear={}
 for _,kind in ipairs({"Hotbar","Storage","Equipment","Accessory"}) do
  for _,e in pairs(inventory[kind] or {}) do if e and Catalog.Gear[e.Id] then table.insert(state.Gear,e) end end
 end
 render(false)
end
remotes:WaitForChild("InventoryUpdate").OnClientEvent:Connect(function(action,data)if action=="Snapshot" then inventory=data;refreshWorkshop() end end)
remotes.InventoryUpdate:FireServer("RequestSnapshot")
local open=make("BindableEvent",player.PlayerGui,{Name="OpenGearWorkshop"})
open.Event:Connect(function(station)state={Station=station,Gear={},Known={},Choices={},Scrolls={},Pages={}};workshop=true;page="Gear";selected=nil;gui.Enabled=true;refreshWorkshop();remotes.InventoryUpdate:FireServer("RequestSnapshot") end)
local gearRemote=remotes:WaitForChild("GearAction",120)
if gearRemote then gearRemote.OnClientEvent:Connect(function(action,data)
 if action=="Result" and gui.Enabled then status.Text=type(data)=="table" and (data.Message or data.Reason or "Updated.") or tostring(data) end
end) end
