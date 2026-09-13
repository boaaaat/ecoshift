-- Telegraph-driven species behaviors; no level-based speed or reach escalation.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local Base=require(script.Parent.EntityBase)
local Catalog=require(RS.Shared.OverhaulBiomes)
local Creature={};Creature.__index=Creature;setmetatable(Creature,Base)
local modes={Wolf="Flank",Boar="Charge",BarkSpider="Web",Scorpion="Double",SandSerpent="Burrow",DuneBeetle="Roll",Leech="Drain",BogToad="Tongue",MarshSnake="Lunge",FrostWolf="Cold",IceWraith="Dash",IceBear="Slam",AshHound="Lunge",LavaGolem="Slam",CinderCrab="Side",CrystalStalker="Sidestep",PrismGuard="Beam",ShardMite="Hop",AuroraStag="Charge",SnowOwl="Swoop",SpringBear="Double",RockCrawler="Armored",StarBeetle="Mortar",DustMite="Burrow",TideCrab="Armored",ReefEel="WaterRush",Shellback="Thrust",GaleRaptor="Hop",ThunderRam="Charge",CliffSpider="Web",SporeMite="Puff",RootGuardian="Sweep",CapBeetle="Puff",Rustback="Armored",Burrower="Burrow",ThornJackal="Flank",BranchCat="Stalk",GiantMoth="Cone",VineSnake="Drop",LanternEel="WaterRush",ArchiveGuard="Blast",CanalCrab="Side",EchoHunter="Noise",CaveBat="Swoop",Stoneback="Armored",MoonCrawler="Slam",RiftHopper="Blink",MoonMite="Hop"}
local attackRanges={Charge=17,Roll=13,Lunge=9,Dash=17,Burrow=13,Beam=28,Mortar=30,Tongue=22,Web=17,Slam=9,Sweep=10,Blast=14,Cone=12,WaterRush=15,Swoop=12,Blink=12,Hop=9,Drop=8}
local windups={Charge=1.1,Roll=.8,Beam=1.5,Mortar=1.25,Tongue=1,Web=.9,Slam=1.4,Double=1.1,Burrow=1.2,Blink=1.2,Cone=1.2}
local function ring(position,radius,duration,color)
 local p=Instance.new("Part");p.Name="AttackWarning";p.Shape=Enum.PartType.Cylinder;p.Size=Vector3.new(.12,radius*2,radius*2);p.CFrame=CFrame.new(position)*CFrame.Angles(0,0,math.pi/2);p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Material=Enum.Material.Neon;p.Color=color or Color3.fromRGB(223,145,75);p.Transparency=.65;p.Parent=workspace;Debris:AddItem(p,duration);return p
end
function Creature.new(model,config)
 local self=Base.new(model,config);setmetatable(self,Creature)
 self.Def=Catalog.Creatures[model:GetAttribute("EntityId")];self.Mode=modes[model:GetAttribute("EntityId")] or "Wildlife"
 self.Home=self.Root.Position;self.WindupUntil=0;self.RecoverUntil=0;self.Config.AttackRange=attackRanges[self.Mode] or 5
 self.Config.Speed=self.Def.Role=="H" and 10 or self.Mode=="Drain" and 7 or self.Mode=="WaterRush" and 17 or 14
 self.Config.DetectionDistance=self.Def.Role=="H" and 27 or self.Mode=="Noise" and 65 or 70
 self.Config.AutoDetectRadius=8;self.Config.PlayerPriority="Closest"
 self.LastHealth=self.Humanoid.Health
 self.Humanoid.HealthChanged:Connect(function(hp) if hp<(self.LastHealth or hp) then self.ProvokedUntil=os.clock()+20 end;self.LastHealth=hp end)
 if self.Mode=="Armored" then model:SetAttribute("FrontalReduction",.35) end
 return self
end
function Creature:_targetOkay(player)
 local c=player and player.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hum=c and c:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or player:GetAttribute("IsDead") or player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("InteriorId")~=self.Model:GetAttribute("InteriorId") then return false end
 local taunted=(self.Model:GetAttribute("ClassTauntUserId")==player.UserId) and (self.Model:GetAttribute("ClassTauntUntil") or 0)>os.clock()
 local directed=self.Model:GetAttribute("ProjectDefense")~=nil
 if not directed and not taunted and self.Def.Role=="H" and os.clock()>(self.ProvokedUntil or 0) and (root.Position-self.Home).Magnitude>30 then return false end
 if not directed and not taunted and (root.Position-self.Home).Magnitude>100 then return false end
 if self.Mode=="WaterRush" then
  local world=require(script.Parent.Parent.Services.OverhaulWorldService);local water=world:GetWaterLevel(root.Position.X,root.Position.Z)
  if not water or world:GetHeight(root.Position.X,root.Position.Z)>water then return false end
 end
 if self.Mode=="Noise" and os.clock()>(self.ProvokedUntil or 0) then
  local hearing=self.Config.DetectionDistance*(1-math.clamp(player:GetAttribute("Gear_HearingReduction") or 0,0,.8))
  if hum.MoveDirection.Magnitude<.15 or (root.Position-self.Root.Position).Magnitude>hearing then return false end
 end
 return true
end
function Creature:AcquireTarget()
 local tauntId=self.Model:GetAttribute("ClassTauntUserId")
 if tauntId and (self.Model:GetAttribute("ClassTauntUntil") or 0)>os.clock() and not self.Model:GetAttribute("IsBoss") then
  local target=Players:GetPlayerByUserId(tauntId)
  if target and self:_targetOkay(target) then self.Target=target;return target end
 end
 self.Target=nil;local best=math.huge
 if self.Model:GetAttribute("ProjectDefense") then
  local goal=self.Model:GetAttribute("ProjectGoal") or Vector3.zero
  for _,p in ipairs(Players:GetPlayers()) do if self:_targetOkay(p) then
   local root=p.Character.HumanoidRootPart;local distance=(root.Position-self.Root.Position).Magnitude
   if (root.Position-goal).Magnitude<180 and distance<400 and distance<best then self.Target=p;best=distance end
  end end
  if self.Target then return self.Target end
 end
 for _,player in ipairs(Players:GetPlayers()) do
  if self:_targetOkay(player) then local detected,distance=self:CanDetectTarget(player.Character);if detected and distance and distance<self.Config.DetectionDistance and distance<best and self:HasLineOfSight(player.Character) then self.Target=player;best=distance end end
 end
 return self.Target
end
function Creature:IsTargetValid() return self:_targetOkay(self.Target) end
function Creature:_damageAt(position,radius,amount,cone)
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local delta=root and root.Position-position
  local aimed=not cone or delta and delta.Magnitude>.01 and delta.Unit:Dot(cone)>.55
  if root and aimed and self:_targetOkay(player) and delta.Magnitude<=radius and self:HasLineOfSight(player.Character) then
   local humanoid=player.Character:FindFirstChildOfClass("Humanoid");local before=humanoid and humanoid.Health
   require(script.Parent.Parent.Services.CombatService):ApplyDamage(self.Model,player.Character,amount,"Melee")
   if self.Model:GetAttribute("EntityId")=="LavaGolem" and self.Mode=="Slam" and humanoid and before and humanoid.Health<before then require(script.Parent.Parent.Services.StatusService):ApplyBurn(player,3,3) end
   if self.Mode=="Web" or self.Mode=="Tongue" then
    local baseDuration=self.Mode=="Web" and 1 or 1.5
    player:SetAttribute("MonsterSnaredUntil",workspace:GetServerTimeNow()+baseDuration*(1-math.clamp(player:GetAttribute("Gear_StaggerReduction") or 0,0,.75)))
   end
  end
 end
end
function Creature:_beginAttack(now)
 self.Aim=self.Target.Character.HumanoidRootPart.Position
 self.WindupUntil=now+(windups[self.Mode] or .65)
 self.NextAttack=self.WindupUntil+2
 self.Humanoid:MoveTo(self.Root.Position);self.Humanoid.WalkSpeed=0
 local radius=(self.Mode=="Slam" or self.Mode=="Mortar" or self.Mode=="Blast") and 7 or 3
 local ground=require(script.Parent.Parent.Services.OverhaulWorldService):GetHeight(self.Aim.X,self.Aim.Z)
 self.Warning=ring(Vector3.new(self.Aim.X,ground+.3,self.Aim.Z),radius,self.WindupUntil-now+.5)
 self.Model:SetAttribute("AttackWindup",true);self.Model:SetAttribute("AttackWarning",workspace:GetServerTimeNow()+1.5)
 if self.Mode=="Beam" or self.Mode=="Tongue" or self.Mode=="Web" then
  local a,b=self.Root.Position,self.Aim;local line=Instance.new("Part");line.Name="AimLine";line.Size=Vector3.new(.2,.2,(b-a).Magnitude);line.CFrame=CFrame.lookAt((a+b)/2,b);line.Anchored=true;line.CanCollide=false;line.CanQuery=false;line.Material=Enum.Material.Neon;line.Color=Color3.fromRGB(233,169,76);line.Parent=workspace;Debris:AddItem(line,self.WindupUntil-now)
 end
end
function Creature:_execute(now)
 self.Model:SetAttribute("AttackWindup",false);self.Model:SetAttribute("AttackWarning",nil);local mode=self.Mode;local damage=self.Model:GetAttribute("Damage") or self.Config.Damage or 8
 if mode=="Charge" or mode=="Roll" or mode=="Lunge" or mode=="Dash" or mode=="WaterRush" or mode=="Hop" or mode=="Swoop" or mode=="Stalk" or mode=="Drop" then
  local delta=self.Aim-self.Root.Position;local dir=Vector3.new(delta.X,0,delta.Z)
  self.RushUntil=now+.65;self.RushAim=self.Aim;self.RushVictims={}
  self.Humanoid.WalkSpeed=mode=="Charge" and 26 or 23;self.Humanoid:MoveTo(self.Aim)
  if mode=="Hop" or mode=="Swoop" or mode=="Drop" then self.Humanoid.Jump=true end
 elseif mode=="Burrow" or mode=="Blink" then
  local world=require(script.Parent.Parent.Services.OverhaulWorldService)
  if world:IsSafe(self.Aim) and self:HasLineOfSight(self.Target and self.Target.Character) then
   local p=Vector3.new(self.Aim.X,world:GetHeight(self.Aim.X,self.Aim.Z)+3,self.Aim.Z)
   self.Model:PivotTo(CFrame.new(p)*self.Model:GetPivot().Rotation)
   self:_damageAt(p,4,damage)
  end
 elseif mode=="Beam" or mode=="Tongue" or mode=="Web" then
  local delta=self.Aim-self.Root.Position;local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.Model}
  local hit=workspace:Raycast(self.Root.Position,delta,params)
  if not hit or hit.Instance:FindFirstAncestorOfClass("Model")== (self.Target and self.Target.Character) then self:_damageAt(self.Aim,3,damage) end
 elseif mode=="Mortar" then
  local aim=self.Aim;ring(aim-Vector3.new(0,2,0),7,1)
  task.delay(.8,function() if self:IsAlive() and not RS:GetAttribute("WorldShifting") then self:_damageAt(aim,7,damage) end end)
 elseif mode=="Double" then
  self:_damageAt(self.Root.Position,6,damage*.6)
  task.delay(.5,function()if self:IsAlive() and not RS:GetAttribute("WorldShifting") then self:_damageAt(self.Root.Position,6,damage*.6) end end)
 elseif mode=="Cone" then
  local delta=self.Aim-self.Root.Position
  self:_damageAt(self.Root.Position,12,damage,delta.Magnitude>.01 and delta.Unit or self.Root.CFrame.LookVector)
 elseif mode=="Cold" then
  self:_damageAt(self.Root.Position,5,damage)
  local p=self.Root.Position;local ground=require(script.Parent.Parent.Services.OverhaulWorldService):GetHeight(p.X,p.Z)
  local patch=ring(Vector3.new(p.X,ground+.2,p.Z),5,4);patch.Color=Color3.fromRGB(147,213,240)
  task.spawn(function()
   for _=1,4 do task.wait(1);if not self:IsAlive() or RS:GetAttribute("WorldShifting") then break end
    self:_damageAt(p,5,damage*.15)
   end
  end)
 elseif mode=="Slam" or mode=="Blast" or mode=="Sweep" or mode=="Puff" then self:_damageAt(self.Root.Position,mode=="Slam" and 9 or 7,damage)
 else
  self:_damageAt(self.Root.Position,5,damage)
  if mode=="Drain" and self:IsTargetValid() and (self.Target.Character.HumanoidRootPart.Position-self.Root.Position).Magnitude<=5 then self.Humanoid.Health=math.min(self.Humanoid.MaxHealth,self.Humanoid.Health+damage*.2) end
 end
 self.RecoverUntil=now+(self.Def.Role=="H" and 2 or mode=="Swoop" and 2.2 or 1.3)
 self.WindupUntil=0
end
function Creature:StepDeployment(targetPart,record,service)
 if RS:GetAttribute("WorldShifting") or RS:GetAttribute("WorldRestoring") then return true end
 self.WindupUntil=0;self.RushUntil=nil
 local now=os.clock();local serverNow=workspace:GetServerTimeNow()
 if (self.Model:GetAttribute("GearStaggerUntil") or 0)>serverNow then self.Humanoid.WalkSpeed=0;return true end
 local point=targetPart.CFrame:PointToObjectSpace(self.Root.Position);local half=targetPart.Size*.5
 point=targetPart.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X,-half.X,half.X),math.clamp(point.Y,-half.Y,half.Y),math.clamp(point.Z,-half.Z,half.Z)))
 if self.DeploymentWindup and self.DeploymentWindup.Model~=record.Model then self.DeploymentWindup=nil end
 if now<self.RecoverUntil then self.Humanoid.WalkSpeed=0;return true end
 if (point-self.Root.Position).Magnitude>5 then
  self.DeploymentWindup=nil
  local slow=(self.Model:GetAttribute("GearSlowUntil") or 0)>serverNow and (self.Model:GetAttribute("GearSlowFactor") or 1) or 1
  self.Humanoid.WalkSpeed=self.Config.Speed*slow;self:UpdatePath(point);self:FollowPath();return true
 end
 self.Humanoid:MoveTo(self.Root.Position)
 if not self.DeploymentWindup then
  self.DeploymentWindup={Model=record.Model,At=now+(windups[self.Mode] or .8)}
  self.Model:SetAttribute("AttackWindup",true);self.Model:SetAttribute("AttackWarning",workspace:GetServerTimeNow()+1.5);ring(point,3,1.5)
 elseif now>=self.DeploymentWindup.At then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.Model}
  local hit=workspace:Raycast(self.Root.Position,point-self.Root.Position,params)
  if not hit or hit.Instance:IsDescendantOf(record.Model) then service:Damage(record.Model,self.Model:GetAttribute("Damage") or self.Config.Damage or 8) end
  self.DeploymentWindup=nil;self.Model:SetAttribute("AttackWindup",false);self.Model:SetAttribute("AttackWarning",nil);self.RecoverUntil=now+1.5
 end
 return true
end
function Creature:Step(dt)
 if not self:IsAlive() or RS:GetAttribute("WorldShifting") or RS:GetAttribute("WorldRestoring") then return end
 local now=os.clock()
 if self.DeploymentWindup then self.DeploymentWindup=nil;self.Model:SetAttribute("AttackWindup",false);self.Model:SetAttribute("AttackWarning",nil) end
 if (self.Model:GetAttribute("GearStaggerUntil") or 0)>workspace:GetServerTimeNow() then self.Humanoid.WalkSpeed=0;self.Humanoid:MoveTo(self.Root.Position);return end
 self.Slow=(self.Model:GetAttribute("GearSlowUntil") or 0)>workspace:GetServerTimeNow() and (self.Model:GetAttribute("GearSlowFactor") or 1) or 1
 if self.Def.Role=="N" then
  local danger
  for _,p in ipairs(Players:GetPlayers()) do local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart");if r and (r.Position-self.Root.Position).Magnitude<25 then danger=r;break end end
  if danger then
   local away=self.Root.Position-danger.Position;local dir=away.Magnitude>.01 and away.Unit or Vector3.xAxis
   local target=self.Root.Position+dir*25
   if require(script.Parent.Parent.Services.OverhaulWorldService):IsSafe(target) then self.Humanoid.WalkSpeed=18;self:MoveTo(target) end
  elseif now>(self.NextWander or 0) then
   self.NextWander=now+4;self.Humanoid.WalkSpeed=self.Model:GetAttribute("EntityId")=="MossSnail" and 3 or 7
   local target=self.Home+Vector3.new(math.random(-22,22),0,math.random(-22,22))
   if require(script.Parent.Parent.Services.OverhaulWorldService):IsSafe(target) then self:UpdatePath(target) end
  else self:FollowPath()
  end
  return
 end
 if self.RushUntil and now<self.RushUntil then
  for _,p in ipairs(Players:GetPlayers()) do
   if self:_targetOkay(p) and not self.RushVictims[p] and (p.Character.HumanoidRootPart.Position-self.Root.Position).Magnitude<5 and self:HasLineOfSight(p.Character) then
    self.RushVictims[p]=true;require(script.Parent.Parent.Services.CombatService):ApplyDamage(self.Model,p.Character,self.Model:GetAttribute("Damage") or self.Config.Damage,"Melee")
   end
  end
  return
 end
 if self.WindupUntil>0 then if now>=self.WindupUntil then self:_execute(now) end;return end
 if now<self.RecoverUntil then self.Humanoid.WalkSpeed=0;self.Humanoid:MoveTo(self.Root.Position);return end
 if not self:IsTargetValid() then self:AcquireTarget() end
 if not self.Target then
  local goal=self.Model:GetAttribute("ProjectGoal") or self.Home
  self.Humanoid.WalkSpeed=self.Model:GetAttribute("ProjectDefense") and self.Config.Speed or 8
  if (self.Root.Position-goal).Magnitude>10 then self:UpdatePath(goal);self:FollowPath() end;return
 end
 if self:InAttackRange() and self:HasLineOfSight(self.Target.Character) and now>=self.NextAttack then self:_beginAttack(now);return end
 self.Humanoid.WalkSpeed=self.Config.Speed*(self.Slow or 1)
 local target=self.Target.Character.HumanoidRootPart.Position
 if self.Mode=="Flank" or self.Mode=="Sidestep" or self.Mode=="Side" then
  local delta=target-self.Root.Position
  if delta.Magnitude>8 and delta.Magnitude<25 then target+=Vector3.new(-delta.Z,0,delta.X).Unit*7 end
 end
 self:UpdatePath(target);self:FollowPath()
end
return Creature
