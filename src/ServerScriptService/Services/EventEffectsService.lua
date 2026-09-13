-- Event consequences are local and begin only after the visible warning.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Service={}
local function sheltered(root)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={root.Parent};params.RespectCanCollide=true
 return workspace:Raycast(root.Position,Vector3.new(0,18,0),params)~=nil
end
function Service:_tick()
 local scenes=require(script.Parent.ObjectiveRuntimeService)._scenes
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local heat,cold,toxin,lowGravity,wet=0,0,0,false,false
  if root and not player:GetAttribute("IsDead") and not player:GetAttribute("InteriorId") and not RS:GetAttribute("WorldShifting") and not RS:GetAttribute("WorldRestoring") then
   for _,scene in pairs(scenes) do
    local data=scene.Entry.Data
    if not scene.Closed and not scene.State.Completed and data.Elapsed>=data.Warning and (root.Position-scene.Origin).Magnitude<60 then
     local safe=sheltered(root)
     local exposure=scene.Def.Exposure or 0
     if scene.Def.Template=="Thermal" then
      -- A clearly signposted neutral center lane remains safe through each phase.
      if math.abs(root.Position.X-scene.Origin.X)<8 then exposure=0 else exposure*=math.floor((data.Elapsed-data.Warning)/12)%2==0 and 1 or -1 end
     end
     if not safe then if exposure>0 then heat=math.max(heat,exposure) else cold=math.min(cold,exposure) end;toxin=math.max(toxin,scene.Def.Toxin or 0) end
     lowGravity=lowGravity or scene.Def.Gravity==true
     wet=wet or scene.Def.Wet and root.Position.Y<scene.Origin.Y+3
    end
   end
  end
  player:SetAttribute("EventExposureRate",heat+cold);player:SetAttribute("EventToxinRate",toxin)
  player:SetAttribute("EventWet",wet==true)
  if root then
   local force=root:FindFirstChild("WorldEventLift")
   if lowGravity then
    if not force then
     local attachment=Instance.new("Attachment");attachment.Name="WorldEventLiftAttachment";attachment.Parent=root
     force=Instance.new("VectorForce");force.Name="WorldEventLift";force.Attachment0=attachment;force.RelativeTo=Enum.ActuatorRelativeTo.World;force.ApplyAtCenterOfMass=true;force.Parent=root
    end
    force.Force=Vector3.new(0,root.AssemblyMass*workspace.Gravity*.35,0)
   elseif force then
    local attachment=force.Attachment0;force:Destroy();if attachment then attachment:Destroy() end
   end
  end
 end
end
function Service:Init()
 if self._started then return end;self._started=true
 _G.Ecoshift=_G.Ecoshift or {};_G.Ecoshift.Mods={Temp=0,Toxin=0,Wet=0,ResourceMultiplier=1,EnemyMultiplier=1}
 task.spawn(function()while true do local ok,err=pcall(self._tick,self);if not ok then warn("[EventEffects]",err) end;task.wait(.5) end end)
end
return Service
