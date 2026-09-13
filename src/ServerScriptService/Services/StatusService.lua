-- Region hazards use active world time and equipped resistance; no loading damage.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Biomes=require(script.Parent.BiomeService)
local Gear=require(script.Parent.GearService)
local Service={_burns=setmetatable({},{__mode="k"})}
local function resistance(char,player,kind)
 local armor=math.clamp(char:GetAttribute("GearRes_"..kind) or 0,0,.9)
 local tonic=math.max(char:GetAttribute("Res_"..kind) or 0,player:GetAttribute("Gear_"..kind.."Tonic") or 0)
 return (1-armor)*(1-math.clamp(tonic,0,.9))*(1-(player:GetAttribute("Gear_SharedCover") or 0))*Gear:GetChannelMultiplier(player,kind)
end
function Service:ApplyBurn(player,damagePerSecond,duration)
 if not player or not player:IsA("Player") or type(damagePerSecond)~="number" or damagePerSecond~=damagePerSecond or type(duration)~="number" or duration~=duration then return end
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 or player:GetAttribute("IsDead") or player:GetAttribute("WorldPlayerRestoring") or RS:GetAttribute("WorldRestoring") then return end
 duration=math.clamp(duration,0,60)*(1-math.clamp(Gear:GetModifiers(player).BurnDurationReduction or 0,0,.8))
 local previous=self._burns[player]
 self._burns[player]={Dps=math.max(previous and previous.Dps or 0,math.clamp(damagePerSecond,0,1000)),Remaining=math.max(previous and previous.Remaining or 0,duration)}
end
function Service:CapturePlayer(player)
 local burn=self._burns[player];return burn and {Dps=burn.Dps,Remaining=burn.Remaining} or nil
end
function Service:RestorePlayer(player,saved)
 self._burns[player]=nil
 if type(saved)=="table" and type(saved.Dps)=="number" and type(saved.Remaining)=="number" then self._burns[player]={Dps=math.clamp(saved.Dps,0,1000),Remaining=math.clamp(saved.Remaining,0,60)} end
end
function Service:_tickPlayer(player,dt)
 if (RS:GetAttribute("WorldShifting") and not player:GetAttribute("InteriorId")) or RS:GetAttribute("WorldRestoring") or player:GetAttribute("IsDead") or player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") then return end
 if workspace:GetAttribute("WorldType")=="Creative" and player:GetAttribute("CreativeMode") and player:GetAttribute("CreativeInvincible") then return end
 local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then return end
 local interior=player:GetAttribute("InteriorId")
 local burn=self._burns[player]
 if burn then
  hum:TakeDamage(burn.Dps*math.min(dt,burn.Remaining));burn.Remaining-=dt
  if burn.Remaining<=0 then self._burns[player]=nil end
 end
 char:SetAttribute("Burning",self._burns[player]~=nil)
 local weather=not interior and Biomes:GetWeather() or {};local modifiers=Gear:GetModifiers(player)
 local biome=Biomes:GetCurrent();local depth=math.clamp(player:GetAttribute("RegionDepth") or 1,1,5)
 local timing=Biomes:GetTiming();local ramp=math.clamp((timing.Duration-timing.Remaining)/60,0,1)
 local maturity=Biomes:GetMaturity()*ramp
 local baseToxin=not interior and (biome=="Swamp" or biome=="MyceliumHollow") and .08*depth or 0
 local toxin=(baseToxin+math.min(.5,tonumber(weather.Toxin) or 0))*maturity+(not interior and player:GetAttribute("EventToxinRate") or 0)
 local wet=math.min(1,tonumber(weather.Wet) or 0)*maturity
 if hum:GetState()==Enum.HumanoidStateType.Swimming or player:GetAttribute("EventWet") then wet=1 end
 if player:GetAttribute("GearRoofShelter") then wet*=.4 end
 wet*=resistance(char,player,"Wet")*(1-(player:GetAttribute("Food_WetnessReduction") or 0))
 local wetness=char:GetAttribute("WetStacks") or 0
 if wet>0 then wetness=math.min(5,wetness+wet*dt) else wetness=math.max(0,wetness-dt*(1+(player:GetAttribute("Gear_DryStepRecovery") or 0))) end
 char:SetAttribute("WetStacks",wetness)
 local poison=char:GetAttribute("ToxinStacks") or 0
 if toxin>0 then poison=math.min(100,poison+toxin*10*resistance(char,player,"Toxin")*dt) else poison=math.max(0,poison-2*dt/(1-math.min(.8,modifiers.PoisonDurationReduction or 0))) end
 if (player:GetAttribute("Gear_ToxinTonic") or 0)>0 then poison=math.max(0,poison-dt*4) end
 char:SetAttribute("ToxinStacks",poison)
 if poison>50 then hum:TakeDamage((poison-50)/25*(1-(player:GetAttribute("Food_PoisonDamageReduction") or 0))*dt) end
end
function Service:Bind()
 if self.Bound then return end;self.Bound=true
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;dt=math.min(2,elapsed);elapsed=0
  for _,player in ipairs(Players:GetPlayers()) do if player:GetAttribute("IsDead") then self._burns[player]=nil else self:_tickPlayer(player,dt) end end
 end)
end
return Service
