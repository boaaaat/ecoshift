-- Equipped building items place directly; deliberate holds salvage existing builds.
local RS = game:GetService("ReplicatedStorage")
if require(RS.Shared.SessionConfig).GetMode() ~= "Expedition" then return end
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Theme = require(RS.Shared.UI.UITheme)
local Config = require(RS.Shared.Config)
local Placement = require(RS.Shared.BuildPlacement)
local Items = require(RS.Shared.Items.ItemDatabase)
local Settings = require(RS.Shared.ClientSettings)
local SettingsSchema = require(RS.Shared.SettingsConfig)
local Messages = require(RS.Shared.ResultMessages).Build
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = RS:WaitForChild("Remotes"):WaitForChild(Config.RemoteNames.Build)
local mouse = player:GetMouse()
local selected, preview, position, target, heldTarget
local rotation, lastPulse, startedAt, statusUntil = 0, 0, 0, 0
local holding, latched = false, false
local holdInput
local duration = Config.BUILD.SalvageSeconds or 3
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "BuildingUI", false, 24, playerGui
local status = Theme.Label(gui,"",UDim2.fromOffset(430,48),UDim2.new(.5,0,1,-220),16,Theme.Colors.Paper,true)
status.AnchorPoint, status.TextXAlignment, status.TextWrapped = Vector2.new(.5,1), Enum.TextXAlignment.Center, true
status.BackgroundColor3, status.BackgroundTransparency, status.Visible = Theme.Colors.Night, .15, false
Theme.Corner(status,10)
local progress = Instance.new("Frame")
progress.Name, progress.Size, progress.Position = "SalvageProgress", UDim2.new(0,0,0,5), UDim2.new(0,0,1,-5)
progress.BackgroundColor3, progress.BorderSizePixel, progress.Parent = Theme.Colors.Amber, 0, status
Theme.Corner(progress,3)
local highlight = Instance.new("Highlight")
highlight.Name, highlight.FillTransparency, highlight.DepthMode = "SalvageTarget", .82, Enum.HighlightDepthMode.Occluded
highlight.FillColor, highlight.OutlineColor = Theme.Colors.Amber, Theme.Colors.Amber
highlight.Enabled, highlight.Parent = false, workspace
local toolbar = Instance.new("Frame")
toolbar.Name, toolbar.Size, toolbar.Position = "TouchPlacement", UDim2.fromOffset(152,48), UDim2.new(1,-100,1,-168)
toolbar.AnchorPoint, toolbar.BackgroundTransparency, toolbar.Parent = Vector2.new(1,1), 1, gui
local function button(name, icon, x)
 local b=Instance.new("TextButton")
 b.Name,b.Text,b.Size,b.Position,b.Parent=name,"",UDim2.fromOffset(48,48),UDim2.fromOffset(x,0),toolbar
 Theme.Button(b);Theme.TouchIcon(b,icon,26)
 return b
end
local placeButton = button("Place","Place",0)
local rotateButton = button("Rotate","Rotate",52)
local salvageButton = button("HoldToSalvage","Harvest",104)
local reticle=Theme.Label(gui,"+",UDim2.fromOffset(24,24),UDim2.fromScale(.5,.5),24,Theme.Colors.Amber,true)
reticle.AnchorPoint,reticle.TextXAlignment=Vector2.new(.5,.5),Enum.TextXAlignment.Center
local function blocked()
 return player:GetAttribute("IsDead") or playerGui:GetAttribute("MenuCursorOpen") or playerGui:GetAttribute("ClassPlacementActive")
end
local function resetHold()
 if heldTarget then remote:FireServer("CancelSalvage",{}) end
 heldTarget=nil
 playerGui:SetAttribute("BuildSalvageActive",false)
 progress.Size=UDim2.new(0,0,0,5)
end
local function currentItem()
 local char=player.Character
 local tool=char and char:FindFirstChildOfClass("Tool")
 return tool and Config.BUILD.PlaceableItems[tool.Name] and tool.Name or nil
end
local function aimRay()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local centered=Theme.IsMobile() or UIS.PreferredInput==Enum.PreferredInput.Gamepad or UIS.MouseBehavior==Enum.MouseBehavior.LockCenter
 local aim=centered and camera.ViewportSize*.5 or Vector2.new(mouse.X,mouse.Y)
 local ray=camera:ViewportPointToRay(aim.X,aim.Y)
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local ignore={}
 if player.Character then table.insert(ignore,player.Character) end
 if preview then table.insert(ignore,preview) end
 params.FilterDescendantsInstances=ignore
 return workspace:Raycast(ray.Origin,ray.Direction*120,params)
end
local function salvageTarget(hit)
 local node=hit and hit.Instance
 while node and node~=workspace do
  if CollectionService:HasTag(node,"Structure") and node:GetAttribute("BuildType") then
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if node:GetAttribute("OwnerUserId")==player.UserId and root and (node:GetPivot().Position-root.Position).Magnitude<= (Config.GRID.BuildMaxDistance or 45) then return node end
   return nil
  end
  node=node.Parent
 end
end
local function showStatus(text)
 status.Text=text;statusUntil=os.clock()+2;status.Visible=true
end
local function rotateKey()
 for _, candidate in ipairs({Enum.KeyCode.R,Enum.KeyCode.T,Enum.KeyCode.X,Enum.KeyCode.Z}) do
  local free=true
  for _, action in ipairs(SettingsSchema.Actions) do if Settings.Key(action)==candidate then free=false;break end end
  if free then return candidate end
 end
 return nil
end
local function place()
 if blocked() or not selected or not position then return end
 remote:FireServer("Place",{Type=selected,Position=position,Rotation=rotation})
end
local function beginHold(input)
 if blocked() then return end
 holding,latched,holdInput=true,false,input
end
local function endHold()
 holding,latched,holdInput=false,false,nil
 resetHold()
end
placeButton.Activated:Connect(place)
rotateButton.Activated:Connect(function() rotation=(rotation+90)%360 end)
salvageButton.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then beginHold(input) end
end)
UIS.InputBegan:Connect(function(input,processed)
 if processed or blocked() then return end
 if input.UserInputType==Enum.UserInputType.MouseButton2 or input.KeyCode==Enum.KeyCode.ButtonL2 then place()
 elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then beginHold(input)
 elseif input.KeyCode==rotateKey() and selected then rotation=(rotation+90)%360 end
end)
UIS.InputEnded:Connect(function(input)
 if input==holdInput or input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then endHold() end
end)
UIS.WindowFocusReleased:Connect(endHold)
remote.OnClientEvent:Connect(function(kind,data)
 if kind~="Result" or type(data)~="table" then return end
 if data.Action=="Place" or data.Action=="Remove" or data.Action=="Salvage" then
  if data.Action~="Place" then resetHold();latched=true end
  showStatus(data.Success and (data.Action=="Place" and "Placed." or "Salvaged into your inventory.") or Messages[data.Reason] or "Unable to complete that build action.")
 end
end)
RunService.RenderStepped:Connect(function()
 local now=os.clock()
 local nextItem=currentItem()
 if nextItem~=selected then selected=nextItem;rotation=0;endHold() end
 local isBlocked=blocked()
 playerGui:SetAttribute("BuildPlacementActive",selected~=nil and not isBlocked)
 local hit=not isBlocked and aimRay() or nil
 target=salvageTarget(hit)
 if isBlocked then endHold() end
 highlight.Adornee,highlight.Enabled=target,target~=nil
 if selected and hit and not isBlocked then
  position=Placement.Surface(hit.Position,preview and {preview} or {})
  if not preview then
   preview=Instance.new("Part")
   preview.Name,preview.Size="PlacementPreview",Vector3.new(Config.GRID.Size-.5,Config.GRID.Size-.5,Config.GRID.Size-.5)
   preview.Anchored,preview.CanCollide,preview.CanTouch,preview.CanQuery=true,false,false,false
   preview.Material,preview.Transparency,preview.Parent=Enum.Material.SmoothPlastic,.6,workspace
   local facing=Instance.new("WedgePart")
   facing.Name,facing.Size,facing.Anchored,facing.CanCollide,facing.CanQuery="Facing",Vector3.new(1.8,.6,2),true,false,false
   facing.Color,facing.Parent=Theme.Colors.Amber,preview
  end
  preview.Transparency=position and .6 or 1
  preview.Facing.Transparency=position and 0 or 1
  if position then
   preview.CFrame=CFrame.new(position+Vector3.new(0,preview.Size.Y/2,0))*CFrame.Angles(0,math.rad(rotation),0)
   preview.Facing.CFrame=preview.CFrame*CFrame.new(0,preview.Size.Y/2+.1,-1.1)*CFrame.Angles(0,math.pi,0)
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   local valid=root and Placement.WithinCamp(position) and (position-root.Position).Magnitude<=(Config.GRID.BuildMaxDistance or 45)
   preview.Color=valid and Theme.Colors.ValidPlacement or Theme.Colors.InvalidPlacement
   if not valid then position=nil end
  end
 else
  position=nil
  if preview then preview:Destroy();preview=nil end
 end
 if holding and not latched then
  if heldTarget and target~=heldTarget then resetHold();latched=true end
  if target and not latched then
   if not heldTarget then
    heldTarget,startedAt,lastPulse=target,now,now
    remote:FireServer("BeginSalvage",{Target=target})
   end
   playerGui:SetAttribute("BuildSalvageActive",true)
   if now-lastPulse>=.2 then lastPulse=now;remote:FireServer("ContinueSalvage",{Target=target}) end
   local fraction=math.clamp((now-startedAt)/duration,0,1)
   progress.Size=UDim2.new(fraction,0,0,5)
   status.Text=string.format("Salvaging %s · %.1fs",tostring(target:GetAttribute("BuildType")),math.max(0,duration-(now-startedAt)))
   status.Visible=true
   if now-startedAt>=duration+.1 then latched=true;remote:FireServer("Remove",{Target=target}) end
  end
 end
 if not heldTarget and now>=statusUntil then
  status.Visible=not isBlocked and (selected~=nil or target~=nil)
  if selected then
   status.Text=Theme.IsMobile() and "Tap place · Hold salvage to recover a build" or ((Items:Get(selected) and Items:Get(selected).Name or selected) .. " · Right-click place · " .. (rotateKey() and rotateKey().Name or "") .. " rotate · Hold left-click salvage")
  elseif target then status.Text=Theme.IsMobile() and "Hold the salvage icon to recover this build" or "Hold left-click for 3 seconds to salvage" end
 end
 toolbar.Visible=Theme.IsMobile() and not isBlocked and (selected~=nil or target~=nil)
 placeButton.Visible,rotateButton.Visible=selected~=nil,selected~=nil
 salvageButton.Visible=target~=nil
 reticle.Visible=Theme.IsMobile() and selected~=nil and not isBlocked
end)
Theme.BindResponsive(gui,function(mobile,size)
 status.Size=UDim2.fromOffset(math.min(520,size.X-24),48)
 status.Position=mobile and UDim2.new(.5,0,1,-226) or UDim2.new(.5,0,1,-220)
 status.TextSize=mobile and 14 or 16
end)
player.CharacterRemoving:Connect(endHold)
gui.Destroying:Connect(function() if preview then preview:Destroy() end;highlight:Destroy() end)
Theme.TrackRoot(gui)
