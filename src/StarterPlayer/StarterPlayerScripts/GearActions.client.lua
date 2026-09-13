local RS=game:GetService("ReplicatedStorage")
if require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode()~="Expedition" then return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Theme=require(RS.Shared.UI.UITheme)
local Settings=require(RS.Shared.ClientSettings)
local Instances=require(RS.Shared.ItemInstance)
local player=Players.LocalPlayer;local playerGui=player:WaitForChild("PlayerGui")
local remotes=RS:WaitForChild("Remotes");local remote=remotes:WaitForChild("GearAction")
local combat=remotes:WaitForChild("CombatAction")
local gui=Instance.new("ScreenGui");gui.Name="GearActions";gui.ResetOnSpawn=false;gui.DisplayOrder=12;gui.Parent=playerGui
local function blocked()
 return not Instances.IsOverhaul() or player:GetAttribute("IsDead") or playerGui:GetAttribute("MenuCursorOpen") or playerGui:GetAttribute("BuildPlacementActive") or playerGui:GetAttribute("ClassPlacementActive") or UIS:GetFocusedTextBox()~=nil
end
local function dodge()
 if blocked() then return end
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if not hum then return end
 local direction=hum.MoveDirection
 if direction.Magnitude<.1 then local root=player.Character:FindFirstChild("HumanoidRootPart");direction=root and root.CFrame.LookVector or Vector3.zero end
 remote:FireServer("Dodge",{Direction=direction})
end
local function special()
 if blocked() then return end
 local camera=workspace.CurrentCamera;local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local tool=player.Character and player.Character:FindFirstChildOfClass("Tool")
 local def=tool and Instances.Definition(tool.Name)
 if not camera or not root or not def or def.Kind~="Weapon" then return end
 local ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
 combat:FireServer("Special",{Dir=ray.Direction,Touch=Theme.IsMobile()})
end
local function makeButton(name,icon,callback)
 local button=Instance.new("TextButton");button.Name=name;button.Size=UDim2.fromOffset(48,48);button.AnchorPoint=Vector2.new(1,1);button.Text="";button.Parent=gui
 Theme.Button(button);button.BackgroundTransparency=.48;Theme.TouchIcon(button,icon,28);button.Activated:Connect(callback)
 local cooldown=Theme.Label(button,"",UDim2.fromScale(1,1),UDim2.new(),17,Theme.Colors.Text);cooldown.TextXAlignment=Enum.TextXAlignment.Center;cooldown.ZIndex=6
 return button,cooldown
end
local roll,rollLabel=makeButton("Dodge","Rotate",dodge)
local burst,burstLabel=makeButton("WeaponSpecial","Attack",special)
local glide=makeButton("Glide","Survey",function() if not blocked() then remote:FireServer("Glide") end end)
local status=Theme.Label(gui,"",UDim2.fromOffset(350,40),UDim2.new(.5,-175,1,-160),16,Theme.Colors.Text);status.TextXAlignment=Enum.TextXAlignment.Center;status.Visible=false
local wear=Theme.Label(gui,"",UDim2.fromOffset(350,24),UDim2.new(.5,-175,1,-142),13,Theme.Colors.Amber);wear.TextXAlignment=Enum.TextXAlignment.Center
local token=0
remote.OnClientEvent:Connect(function(action,payload)
 if action=="Result" then
  token+=1;local serial=token;status.Text=payload.Message or "";status.Visible=status.Text~="";task.delay(3,function()if token==serial then status.Visible=false end end)
 elseif action=="Warnings" then
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and payload[1] then status.Text="Nearby "..payload[1].Name;status.Visible=true;task.delay(8,function()status.Visible=false end) end
 end
end)
UIS.InputBegan:Connect(function(input,processed)
 if processed or blocked() then return end
 if input.KeyCode==Settings.Key("Dodge") or input.KeyCode==Enum.KeyCode.ButtonB then dodge()
 elseif input.KeyCode==Settings.Key("Glide") or input.KeyCode==Enum.KeyCode.ButtonL3 then remote:FireServer("Glide")
 elseif input.KeyCode==Enum.KeyCode.ButtonL2 then special()
 elseif input.KeyCode==Enum.KeyCode.ButtonR2 then
  local tool=player.Character and player.Character:FindFirstChildOfClass("Tool")
  if tool then tool:Activate() end
 end
end)
UIS.InputEnded:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.ButtonR2 then local tool=player.Character and player.Character:FindFirstChildOfClass("Tool");if tool then tool:Deactivate() end end
end)
local tick=0;local wasProgress=false
local warnings={}
Run.RenderStepped:Connect(function(dt)
 tick+=dt;if tick<.1 then return end;tick=0
 local mobile=Theme.IsMobile();local available=not blocked();local tool=player.Character and player.Character:FindFirstChildOfClass("Tool");local def=tool and Instances.Definition(tool.Name)
 roll.Visible=mobile and available;burst.Visible=mobile and available and def~=nil and def.Kind=="Weapon";glide.Visible=mobile and available and (player:GetAttribute("Gear_Glide")==true or player:GetAttribute("Gear_Climb")==true)
 roll.Position=UDim2.new(1,-74,1,-132);burst.Position=UDim2.new(1,-16,1,-186);glide.Position=UDim2.new(1,-132,1,-132)
 local durability=tool and tool:GetAttribute("Durability");local maximum=tool and tool:GetAttribute("MaxDurability")
 wear.Visible=available and durability~=nil and maximum~=nil and durability<=maximum*.2
 wear.Text=wear.Visible and (durability<=0 and "BROKEN · Repair at camp" or string.format("Gear worn · %d%% durability",durability/maximum*100)) or ""
 local bowStarted=player:GetAttribute("BowChargeStarted")
 if bowStarted then status.Visible=true;status.Text=string.format("Drawing bow · %d%%",math.min(100,(os.clock()-bowStarted)/1.3*100)) end
 local progress=player:GetAttribute("GearMaintenanceProgress") or player:GetAttribute("GearTreatmentProgress")
 if progress then status.Visible=true;status.Text=string.format(player:GetAttribute("GearTreatmentProgress") and "Applying treatment · %d%%" or "Maintaining gear · %d%%",progress*100) end
 if not progress and not bowStarted and wasProgress then status.Visible=false end
 wasProgress=progress~=nil or bowStarted~=nil
 if player:GetAttribute("IsDead") then status.Visible=false end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart");local seen={}
 if player:GetAttribute("Gear_AttackWarning") and root then
  for _,monster in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
   local target=monster:FindFirstChild("HumanoidRootPart")
   if target and (monster:GetAttribute("AttackWarning") or 0)>workspace:GetServerTimeNow() and (target.Position-root.Position).Magnitude<=30 then
    seen[monster]=true
    if not warnings[monster] then
     local cue=Instance.new("BillboardGui");cue.Name="AttackWarning";cue.Size=UDim2.fromOffset(40,40);cue.StudsOffset=Vector3.new(0,5,0);cue.Adornee=target;cue.AlwaysOnTop=false;cue.Parent=gui
     local text=Instance.new("TextLabel");text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1);text.Text="!";text.TextSize=32;text.Font=Enum.Font.GothamBold;text.TextColor3=Color3.fromRGB(241,186,83);text.Parent=cue;warnings[monster]=cue
    end
   end
  end
 end
 for monster,cue in pairs(warnings) do if not seen[monster] then cue:Destroy();warnings[monster]=nil end end
 local dodgeRemaining=player:GetAttribute("DodgeCooldown") or 0
 rollLabel.Text=dodgeRemaining>0 and string.format("%.1f",dodgeRemaining) or ""
 local remaining=math.max(0,(player:GetAttribute("WeaponSpecialReadyAt") or 0)-workspace:GetServerTimeNow())
 burstLabel.Text=remaining>0 and tostring(math.ceil(remaining)) or ""
end)
Theme.TrackRoot(gui)
