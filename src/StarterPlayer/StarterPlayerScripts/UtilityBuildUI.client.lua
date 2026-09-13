-- Touch and keyboard management for shared water, rest, trap, and marker supplies.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Shared=RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode()~="Expedition" then return end
local Theme=require(Shared.UI.UITheme)
local Catalog=require(Shared.OverhaulCatalog)
local player=Players.LocalPlayer
local remote=RS:WaitForChild("Remotes"):WaitForChild("UtilityBuild")
local colors=Theme.Colors
local function make(class,parent,props)local v=Instance.new(class);for k,x in pairs(props) do v[k]=x end;v.Parent=parent;return v end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="UtilityBuildUI",DisplayOrder=67,ResetOnSpawn=false,Enabled=false})
make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=colors.Night,BackgroundTransparency=.35,Active=true,BorderSizePixel=0})
local panel=make("CanvasGroup",gui,{Name="UtilityPanel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(620,580),BackgroundColor3=colors.Panel})
Theme.Panel(panel);Theme.CaptureCursor(panel);Theme.TrackRoot(gui)
local function label(parent,text,height)
 return make("TextLabel",parent,{Size=UDim2.new(1,0,0,height or 40),Text=text,TextColor3=colors.Text,Font=Enum.Font.Gotham,TextSize=17,TextWrapped=true,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(parent,text,fn)
 local b=make("TextButton",parent,{Text=text,Size=UDim2.new(1,0,0,48),TextColor3=colors.Text,Font=Enum.Font.GothamMedium,TextSize=17,BackgroundColor3=colors.SlotEmpty,TextWrapped=true});Theme.Button(b);b.Activated:Connect(fn);return b
end
local state,signature,render=nil,"",nil
local title=label(panel,"Camp utility",42);title.Position=UDim2.fromOffset(16,8);title.Size=UDim2.new(1,-86,0,42);title.Font=Enum.Font.GothamBold;title.TextSize=23
local status=label(panel,"",46);status.Position=UDim2.new(0,16,1,-50);status.Size=UDim2.new(1,-32,0,46)
local summary=label(panel,"",68);summary.Position=UDim2.fromOffset(16,56);summary.Size=UDim2.new(1,-32,0,68)
local scroll=make("ScrollingFrame",panel,{Name="Actions",Position=UDim2.fromOffset(16,132),Size=UDim2.new(1,-32,1,-192),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y})
make("UIListLayout",scroll,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",scroll,{PaddingRight=UDim.new(0,7)})
local function send(action,payload)
 if not state then return end
 payload=payload or {};payload.Model=state.Model;status.Text="Sending…";remote:FireServer(action,payload)
end
local function close()send("Close");state=nil;gui.Enabled=false end
local x=button(panel,"×",close);x.Size=UDim2.fromOffset(44,44);x.Position=UDim2.new(1,-58,0,8)
render=function()
 for _,child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
 local s=state.State
 if s.Type=="RainCollector" then
  label(scroll,"Collects one Water every rainy minute while uncovered. Stores ten; no offline production.",68)
  button(scroll,"Collect stored Water",function()send("Collect") end)
 elseif s.Type=="WaterFilter" then
  label(scroll,"One Dirty Water takes ten seconds. One Coal powers ten batches. Full output pauses work.",68)
  button(scroll,"Add Dirty Water ×1",function()send("Input",{Quantity=1}) end)
  button(scroll,"Add Dirty Water ×5",function()send("Input",{Quantity=5}) end)
  button(scroll,"Add Coal ×1 · ten filter uses",function()send("Fuel") end)
  button(scroll,"Collect filtered Water",function()send("Collect") end)
  button(scroll,"Cancel / withdraw unfinished Dirty Water",function()send("Withdraw") end)
 elseif s.Type=="Bedroll" then
  label(scroll,"Rest beside this bedroll: +1 stamina and 0.2 exposure recovery per second. Moving ends rest. No healing or respawn.",90)
  button(scroll,"Start / stop resting",function()send("Rest") end)
 elseif s.Type=="SpikeTrap" then
  label(scroll,string.format("Grade %d: %g damage to one crossing monster; three-second reset. Bone ×1 supplies ten triggers.",state.Grade,Catalog.StandardDamage[state.Grade]*.8),80)
  button(scroll,"Load Bone ×1 · ten triggers",function()send("Ammo") end)
  local costs=Catalog.GetStationUpgradeCost(state.Grade+1)
  if costs then
   local pieces={};for _,c in ipairs(costs) do table.insert(pieces,(Catalog.Items[c.Id].Name).." ×"..c.N) end
   label(scroll,"Next grade: "..table.concat(pieces," + "),65)
   button(scroll,"Upgrade trap",function()send("Upgrade") end)
  end
 else
  label(scroll,"Give this crew marker a clear name. Trail beacons last fifteen active minutes.",65)
  local box=make("TextBox",scroll,{Size=UDim2.new(1,0,0,48),Text=s.Name or "",PlaceholderText="Marker name",TextColor3=colors.Text,PlaceholderColor3=colors.TextMuted,BackgroundColor3=colors.SlotEmpty,TextSize=17,Font=Enum.Font.Gotham,ClearTextOnFocus=false})
  button(scroll,"Save marker name",function()send("Name",{Name=box.Text}) end)
 end
end
remote.OnClientEvent:Connect(function(kind,payload)
 if kind=="Close" then gui.Enabled=false;state=nil;return end
 if kind~="State" then return end
 local fresh=not state or state.Model~=payload.Model
 state=payload;gui.Enabled=true
 local s=state.State;title.Text=Catalog.Items[s.Type].Name
 if payload.Message then status.Text=payload.Message end
 if s.Type=="RainCollector" then summary.Text=string.format("Water %d / 10 · next collection %.0f / 60 seconds",s.Water,s.Work)
 elseif s.Type=="WaterFilter" then summary.Text=string.format("Water %d / 10 · dirty input %d · fuel %d uses\nFiltering %.1f / 10 seconds",s.Water,s.Input,s.FuelUses,s.Work)
 elseif s.Type=="SpikeTrap" then summary.Text=string.format("%d triggers loaded · %.1fs reset",s.Ammo,s.Cooldown)
 elseif s.Type=="Bedroll" then summary.Text=player:GetAttribute("RestingAtBedroll")==state.Model:GetAttribute("UtilityId") and "Resting — stay still nearby" or "Ready to rest"
 else summary.Text=s.Lifetime and string.format("%.0f seconds remaining",s.Lifetime) or "Permanent crew marker" end
 local nextSignature=s.Type..state.Grade
 if fresh or signature~=nextSignature then render();signature=nextSignature end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed)if not processed and gui.Enabled and input.KeyCode==Enum.KeyCode.Escape then close() end end)
Theme.BindResponsive(gui,function(mobile,available)panel.Size=UDim2.fromOffset(math.max(280,math.min(700,available.X-20)),math.max(230,math.min(mobile and available.Y-16 or 620,available.Y-16))) end)
