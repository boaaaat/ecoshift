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
local records={}
local watchModel
local function number(value)
 return string.format("%.2f",value):gsub("0+$",""):gsub("%.$","")
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
 gui.Name,gui.Size,gui.StudsOffset="EnemyHealthBar",UDim2.fromOffset(186,50),Vector3.new(0,3,0)
 gui.AlwaysOnTop,gui.Enabled,gui.Adornee,gui.Parent=false,false,anchor,model
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
 for model,data in pairs(records) do
  if data.Gui then
   local anchor=data.Gui.Adornee
   data.Gui.Enabled=root~=nil and anchor~=nil and anchor:IsDescendantOf(workspace)
    and (anchor.Position-root.Position).Magnitude<=NEAR_DISTANCE and data.Humanoid.Health>0
  end
 end
end)
script.Destroying:Connect(function() for model in pairs(records) do cleanup(model) end end)
