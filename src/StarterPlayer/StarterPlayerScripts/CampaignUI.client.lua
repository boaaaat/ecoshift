local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Shared=RS:WaitForChild("Shared")
if require(Shared.SessionConfig).GetMode()~="Expedition" then return end
local Theme=require(Shared.UI.UITheme)
local Items=require(Shared.Items.ItemDatabase)
local Guide=require(Shared.UI.RecipeGuideUI)
local remote=RS:WaitForChild("Remotes"):WaitForChild("Campaign",120)
if not remote then return end
local colors=Theme.Colors
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props or {}) do o[k]=v end;o.Parent=parent;return o
end
local gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),{Name="CampaignUI",ResetOnSpawn=false,Enabled=false,DisplayOrder=65})
local panel=make("CanvasGroup",gui,{Size=UDim2.new(.94,0,.9,0),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=colors.Panel,BorderSizePixel=0})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(850,760)})
Theme.Panel(panel);Theme.CaptureCursor(panel);Theme.TrackRoot(gui)
local function label(parent,value,height,size)
 return make("TextLabel",parent,{Size=UDim2.new(1,-12,0,height or 38),Text=value,TextSize=size or 17,TextColor3=colors.Text,Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1})
end
local title=label(panel,"Expedition campaign",48,24);title.Position=UDim2.fromOffset(18,8);title.Size=UDim2.new(1,-88,0,48)
local close=make("TextButton",panel,{Position=UDim2.new(1,-60,0,10),Size=UDim2.fromOffset(44,44),Text="×",TextSize=28});Theme.Button(close)
close.Activated:Connect(function() gui.Enabled=false end)
local list=make("ScrollingFrame",panel,{Position=UDim2.fromOffset(18,64),Size=UDim2.new(1,-36,1,-126),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5})
make("UIListLayout",list,{Padding=UDim.new(0,8)})
local status=label(panel,"Contributions and clues are shared with the whole crew.",48,14);status.Position=UDim2.new(0,18,1,-55);status.Size=UDim2.new(1,-36,0,48)
local state,pending,signature
local function request(action)
 if pending then return end;pending=true;status.Text="Sending…";remote:FireServer(action)
 task.delay(5,function() if pending then pending=false;status.Text="Reopen the desk if no response arrives." end end)
end
local function button(text,callback)
 local b=make("TextButton",list,{Size=UDim2.new(1,-12,0,48),Text=text,TextWrapped=true,TextSize=17,Font=Enum.Font.GothamMedium});Theme.Button(b);b.Activated:Connect(callback);return b
end
local function render(force)
 if not state or not gui.Enabled then return end
 local nextSignature=game:GetService("HttpService"):JSONEncode({state.Tier,state.Facts,state.Paid,state.Instruments,state.Started,math.floor(state.Defense or 0),state.Endurance,state.CompleteAt})
 if not force and signature==nextSignature then return end;signature=nextSignature
 local y=list.CanvasPosition.Y
 for _,c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
 title.Text="Tier "..state.Tier.." · "..state.Milestone.Name
 if state.CompleteAt then
  label(list,"Campaign completed. Your crew can keep exploring and crafting.",70,21)
  button(state.Endurance and "Endurance enabled" or "Enable endurance scaling",function() request("Endurance") end)
 else
  label(list,"Recover clues",34,20)
  for fact in pairs(state.Milestone.Facts or {}) do label(list,(state.Facts[fact] and "✓ " or "○ ")..fact:gsub("(%l)(%u)","%1 %2"),40) end
  if state.Milestone.Instruments then
   local n=0;for _ in pairs(state.Instruments or {}) do n+=1 end
   label(list,"Calibrated instruments: "..n.." / 3 different biome C regions",55)
  end
  local ids={};for id in pairs(state.Cost or {}) do table.insert(ids,id) end;table.sort(ids)
  if #ids>0 then label(list,"Shared material contributions",36,20) end
  for _,id in ipairs(ids) do
   local item=Items:Get(id)
   button(string.format("%s   %d / %d   ›",item and item.Name or id,state.Paid[id] or 0,state.Cost[id]),function() Guide.Open(id) end)
  end
  if #ids>0 then button("Contribute materials from my pack",function() request("Contribute") end) end
  if state.Started and state.Milestone.Defense then
   label(list,string.format("Defense: %d / %d seconds · stay near the desk",state.Defense,state.Milestone.Defense),65)
   local bar=make("Frame",list,{Size=UDim2.new(1,-12,0,12),BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0});Theme.Corner(bar,6)
   local fill=make("Frame",bar,{Size=UDim2.fromScale(math.clamp(state.Defense/state.Milestone.Defense,0,1),1),BackgroundColor3=colors.Amber,BorderSizePixel=0});Theme.Corner(fill,6)
  else button(state.Milestone.Boss and "Enter encounter" or state.Milestone.Interior and "Enter archive" or "Begin project defense",function() request("Begin") end) end
 end
 task.defer(function() list.CanvasPosition=Vector2.new(0,y) end)
end
remote.OnClientEvent:Connect(function(action,a,b)
 if action=="State" or action=="Open" then state=a;if action=="Open" then gui.Enabled=true end;render(action=="Open")
 elseif action=="Result" then pending=false;status.Text=b or (a and "Done." or "Cannot do that yet.") end
end)
remote:FireServer("State")
