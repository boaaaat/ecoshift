-- Nearby creature nameplates, independent of whether they have taken damage.
local RS=game:GetService("ReplicatedStorage")
if require(RS.Shared.SessionConfig).GetMode()~="Expedition" then return end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local TweenService=game:GetService("TweenService")
local Theme=require(RS.Shared.UI.UITheme)
local C=Theme.Colors
local player=Players.LocalPlayer
local NEAR_DISTANCE=30
local BOSS_DISTANCE=100
local records={}
local watchModel

-- Bosses retain their world-space nameplate, but also receive a shared-style
-- encounter bar so every nearby crew member can read the fight at a glance.
local bossGui=Instance.new("ScreenGui")
bossGui.Name="BossHealthUI"
bossGui.ResetOnSpawn=false
bossGui.DisplayOrder=11
bossGui.Parent=player:WaitForChild("PlayerGui")
local bossPanel=Instance.new("Frame")
bossPanel.Name="EncounterBar"
bossPanel.AnchorPoint=Vector2.new(.5,0)
bossPanel.Position=UDim2.new(.5,0,0,48)
bossPanel.Size=UDim2.new(.5,0,0,68)
bossPanel.BackgroundColor3=Color3.fromRGB(28,20,34)
bossPanel.BackgroundTransparency=.06
bossPanel.BorderSizePixel=0
bossPanel.Visible=false
bossPanel.Parent=bossGui
Theme.Corner(bossPanel,9)
local bossLimit=Instance.new("UISizeConstraint")
bossLimit.MinSize=Vector2.new(300,68)
bossLimit.MaxSize=Vector2.new(720,68)
bossLimit.Parent=bossPanel
local bossStroke=Instance.new("UIStroke")
bossStroke.Color=Color3.fromRGB(193,126,220)
bossStroke.Transparency=.12
bossStroke.Thickness=2
bossStroke.Parent=bossPanel
local bossAccent=Instance.new("Frame")
bossAccent.Name="BossAccent"
bossAccent.Size=UDim2.new(.24,0,0,4)
bossAccent.Position=UDim2.new(.38,0,0,0)
bossAccent.BackgroundColor3=Color3.fromRGB(222,151,244)
bossAccent.BorderSizePixel=0
bossAccent.Parent=bossPanel
Theme.Corner(bossAccent,2)
local bossName=Theme.Label(bossPanel,"BOSS",UDim2.new(1,-126,0,24),UDim2.fromOffset(14,7),15,C.Paper,true)
bossName.TextXAlignment=Enum.TextXAlignment.Center
local bossPhase=Theme.Label(bossPanel,"",UDim2.fromOffset(92,22),UDim2.new(1,-102,0,8),11,Color3.fromRGB(225,182,239),true)
bossPhase.TextXAlignment=Enum.TextXAlignment.Right
local bossTrack=Instance.new("Frame")
bossTrack.Name="HealthTrack"
bossTrack.Size=UDim2.new(1,-24,0,24)
bossTrack.Position=UDim2.fromOffset(12,36)
bossTrack.BackgroundColor3=Color3.fromRGB(12,9,16)
bossTrack.BorderSizePixel=0
bossTrack.ClipsDescendants=true
bossTrack.Parent=bossPanel
Theme.Corner(bossTrack,6)
local bossFill=Instance.new("Frame")
bossFill.Name="Fill"
bossFill.Size=UDim2.fromScale(1,1)
bossFill.BackgroundColor3=Color3.fromRGB(157,59,190)
bossFill.BorderSizePixel=0
bossFill.Parent=bossTrack
Theme.Corner(bossFill,6)
local bossGradient=Instance.new("UIGradient")
bossGradient.Color=ColorSequence.new(Color3.fromRGB(216,101,238),Color3.fromRGB(104,39,150))
bossGradient.Parent=bossFill
local bossHealth=Theme.Label(bossTrack,"",UDim2.fromScale(1,1),UDim2.new(),13,Color3.fromRGB(255,246,255),true)
bossHealth.TextXAlignment=Enum.TextXAlignment.Center
bossHealth.TextStrokeTransparency=.35
local currentBoss,bossTween,bossLastHealth,bossLastMax

Theme.BindResponsive(bossPanel,function(mobile)
 bossPanel.Position=UDim2.new(.5,0,0,mobile and 54 or 48)
 bossPanel.Size=UDim2.new(mobile and .6 or .5,0,0,68)
end)

local function number(value)
 return string.format("%.2f",value):gsub("0+$",""):gsub("%.$","")
end
local function isBoss(model)
 return model:GetAttribute("IsBoss")==true or model:GetAttribute("Boss")==true or CollectionService:HasTag(model,"Boss")
end
local function updateBossBar(model,humanoid)
 if not model or not humanoid or humanoid.Health<=0 then
  currentBoss,bossLastHealth,bossLastMax=nil,nil,nil
  bossPanel.Visible=false
  if bossTween then bossTween:Cancel();bossTween=nil end
  return
 end
 bossPanel.Visible=true
 if currentBoss~=model then
  currentBoss=model
  bossLastHealth,bossLastMax=nil,nil
 end
 local level=model:GetAttribute("Level") or model:GetAttribute("MonsterLevel") or 1
 bossName.Text=string.upper(model:GetAttribute("DisplayName") or model.Name).."  ·  LV "..level
 local phase=tonumber(model:GetAttribute("BossPhase"))
 bossPhase.Text=phase and "PHASE "..math.max(1,math.floor(phase)) or "BOSS"
 local current,maximum=math.max(0,humanoid.Health),math.max(1,humanoid.MaxHealth)
 bossHealth.Text=number(current).." / "..number(maximum).." HP"
 if current~=bossLastHealth or maximum~=bossLastMax then
  bossLastHealth,bossLastMax=current,maximum
  if bossTween then bossTween:Cancel() end
  bossTween=TweenService:Create(bossFill,TweenInfo.new(.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
   Size=UDim2.fromScale(math.clamp(current/maximum,0,1),1),
  })
  bossTween:Play()
 end
end
local function cleanup(model)
 local data=records[model]
 if not data then return end
 records[model]=nil
 for _,connection in ipairs(data.Connections) do connection:Disconnect() end
 if data.Tween then data.Tween:Cancel() end
 if data.Gui then data.Gui:Destroy() end
end
local function attach(model,data)
 if data.Gui then return end
 local hum=model:FindFirstChildOfClass("Humanoid")
 local anchor=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
 if not hum or not anchor or not anchor:IsA("BasePart") or hum.Health<=0 then return end
 local gui=Instance.new("BillboardGui")
 local height=3
 local ok,size=pcall(function() return model:GetExtentsSize() end)
 if ok then height=math.max(3,size.Y*.5+1.35) end
 gui.Name,gui.Size,gui.StudsOffset="EnemyHealthBar",UDim2.fromOffset(186,50),Vector3.new(0,height,0)
 gui.AlwaysOnTop,gui.LightInfluence,gui.Enabled,gui.Adornee,gui.Parent=true,0,false,anchor,model
 local name=Theme.Label(gui,"",UDim2.new(1,0,0,22),UDim2.new(),14,C.Paper,true)
 name.TextXAlignment,name.TextStrokeTransparency=Enum.TextXAlignment.Center,.35
 local background=Instance.new("Frame")
 background.Name,background.Size,background.Position="Health",UDim2.new(1,-12,0,22),UDim2.fromOffset(6,25)
 background.BackgroundColor3,background.BackgroundTransparency,background.BorderSizePixel,background.Parent=C.Night,.08,0,gui
 Theme.Corner(background,6)
 local fill=Instance.new("Frame")
 fill.Name,fill.Size,fill.BackgroundColor3,fill.BorderSizePixel,fill.Parent="Fill",UDim2.fromScale(1,1),C.Moss,0,background
 Theme.Corner(fill,6)
 local hp=Theme.Label(background,"",UDim2.fromScale(1,1),UDim2.new(),13,C.Paper,true)
 hp.Name,hp.ZIndex,hp.TextXAlignment,hp.TextStrokeTransparency="ExactHealth",2,Enum.TextXAlignment.Center,.4
 data.Gui,data.Humanoid,data.Fill=gui,hum,fill
 local function updateName()
  name.Text=string.format("%s · LV %d",model:GetAttribute("DisplayName") or model.Name,model:GetAttribute("Level") or model:GetAttribute("MonsterLevel") or 1)
 end
 local function updateHealth()
  if hum.Health<=0 then cleanup(model);return end
  local current,maximum=math.max(0,hum.Health),math.max(0,hum.MaxHealth)
  local fraction=maximum>0 and math.clamp(current/maximum,0,1) or 0
  hp.Text=number(current).." / "..number(maximum).." HP"
  if data.Tween then data.Tween:Cancel() end
  data.Tween=TweenService:Create(fill,TweenInfo.new(.15),{Size=UDim2.fromScale(fraction,1)})
  data.Tween:Play()
  fill.BackgroundColor3=fraction>.6 and C.Moss or fraction>.3 and C.Amber or C.DangerFill
 end
 table.insert(data.Connections,hum.HealthChanged:Connect(updateHealth))
 table.insert(data.Connections,hum:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth))
 table.insert(data.Connections,model:GetPropertyChangedSignal("Name"):Connect(updateName))
 for _,key in ipairs({"DisplayName","Level","MonsterLevel"}) do table.insert(data.Connections,model:GetAttributeChangedSignal(key):Connect(updateName)) end
 updateName();updateHealth()
end
watchModel=function(model)
 if not model:IsA("Model") or Players:GetPlayerFromCharacter(model) or records[model] then return end
 local data={Connections={}}
 records[model]=data
 table.insert(data.Connections,model.ChildAdded:Connect(function() attach(model,data) end))
 table.insert(data.Connections,model.ChildRemoved:Connect(function(child)
  if data.Gui and (child==data.Humanoid or child==data.Gui.Adornee) then
   cleanup(model)
   if model:IsDescendantOf(workspace) then watchModel(model) end
  end
 end))
 table.insert(data.Connections,model:GetPropertyChangedSignal("PrimaryPart"):Connect(function() attach(model,data) end))
 table.insert(data.Connections,model.AncestryChanged:Connect(function()
  if not model:IsDescendantOf(workspace) then cleanup(model) end
 end))
 attach(model,data)
end
for _,tag in ipairs({"Monster","Animal"}) do
 CollectionService:GetInstanceAddedSignal(tag):Connect(watchModel)
 for _,model in ipairs(CollectionService:GetTagged(tag)) do watchModel(model) end
end
local watchedFolders=setmetatable({},{__mode="k"})
local function watchFolder(folder)
 if watchedFolders[folder] then return end
 watchedFolders[folder]=true
 local function added(child)
  if child:IsA("Folder") then watchFolder(child)
  elseif child:IsA("Model") then watchModel(child) end
 end
 folder.ChildAdded:Connect(added)
 for _,child in ipairs(folder:GetChildren()) do added(child) end
end
for _,name in ipairs({"Enemies","Animals"}) do local folder=workspace:FindFirstChild(name);if folder then watchFolder(folder) end end
workspace.ChildAdded:Connect(function(child) if child.Name=="Enemies" or child.Name=="Animals" then watchFolder(child) end end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.15 then return end;elapsed=0
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local nearestBoss,nearestHumanoid,nearestDistance
 for model,data in pairs(records) do
  if data.Gui then
   local anchor=data.Gui.Adornee
   local distance=root and anchor and anchor:IsDescendantOf(workspace) and (anchor.Position-root.Position).Magnitude or math.huge
   data.Gui.Enabled=distance<=NEAR_DISTANCE and data.Humanoid.Health>0
   if isBoss(model) and data.Humanoid.Health>0 and distance<=BOSS_DISTANCE and (not nearestDistance or distance<nearestDistance) then
    nearestBoss,nearestHumanoid,nearestDistance=model,data.Humanoid,distance
   end
  end
 end
 updateBossBar(nearestBoss,nearestHumanoid)
end)
script.Destroying:Connect(function() for model in pairs(records) do cleanup(model) end end)
