local RS=game:GetService("ReplicatedStorage")
if require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode()~="Expedition" then return end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Theme=require(RS.Shared.UI.UITheme)
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="WorldEventNotice";gui.ResetOnSpawn=false;gui.DisplayOrder=12;gui.Parent=player:WaitForChild("PlayerGui")
local card=Instance.new("Frame");card.Size=UDim2.fromOffset(300,58);card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.new(.5,0,0,64);card.Visible=false;card.Parent=gui
Theme.Panel(card,true)
local title=Theme.Label(card,"",UDim2.new(1,-24,0,22),UDim2.fromOffset(12,7),16,Theme.Colors.Amber,true)
local detail=Theme.Label(card,"",UDim2.new(1,-24,0,18),UDim2.fromOffset(12,32),12,Theme.Colors.Paper,false)
local active={}
Theme.BindResponsive(gui,function(mobile,size)
 card.Size=UDim2.fromOffset(math.min(mobile and 252 or 320,size.X-24),58)
 card.Position=UDim2.new(.5,0,0,mobile and 60 or 64)
end)
local remote=RS:WaitForChild("Remotes"):WaitForChild("EventBroadcast")
remote.OnClientEvent:Connect(function(action,id,data)
 if action=="Minor_End" or action=="Major_End" then active[id]=nil;return end
 if (action~="Minor_Start" and action~="Major_Start") or type(data)~="table" then return end
 active[id]={Name=data.Name or id,Warning=math.max(0,(data.Warning or 0)-(data.Elapsed or 0)),Age=0,Position=data.Position}
end)
remote:FireServer("RequestActive")
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 if RS:GetAttribute("WorldShifting") or RS:GetAttribute("WorldRestoring") then card.Visible=false;return end
 elapsed+=dt;if elapsed<.1 then return end
 local chosen
 for id,event in pairs(active) do
  event.Age+=elapsed
  if event.Age>event.Warning+10 then active[id]=nil
  elseif not chosen or event.Warning-event.Age>chosen.Warning-chosen.Age then chosen=event end
 end
 elapsed=0
 card.Visible=chosen~=nil and not player.PlayerGui:GetAttribute("MenuCursorOpen")
 if not chosen then return end
 local remaining=math.ceil(chosen.Warning-chosen.Age)
 title.Text=chosen.Name
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local p=chosen.Position;local distance=root and type(p)=="table" and (root.Position-Vector3.new(p[1],p[2],p[3])).Magnitude
 detail.Text=(remaining>0 and "Local danger in "..remaining.."s" or chosen.Warning>0 and "Local hazard active · marked on your map" or "Optional opportunity · open the map")..(distance and " · "..math.floor(distance).." studs" or "")
end)
