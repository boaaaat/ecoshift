-- Active-time scheduler. Offline/loading never burns a warning or an opportunity.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Codec=require(script.Parent.WorldSnapshotCodec)
local Definitions=require(RS.Shared.EventsConfig)
local Service={_active={},_nextMinor=210,_nextMajor=720,_opportunities=0,_harmful=0,_time=0}
local function participating()
 local surface,all=0,0
 for _,p in ipairs(Players:GetPlayers()) do
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h and h.Health>0 and not p:GetAttribute("IsDead") and not p:GetAttribute("WorldPlayerLoading") and not p:GetAttribute("WorldPlayerRestoring") then all+=1;if not p:GetAttribute("InteriorId") then surface+=1 end end
 end
 return surface,all
end
local function paused()
 local _,all=participating()
 return all==0 or RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") or require(script.Parent.GameStateService):IsGameOver()
end
local depths={FallingStars=2,HeatSurge=3,AuroraShift=3,Thunderfront=2,RootOutbreak=3,BrokenCrossing=3,ArchiveAlarm=2,DeepRumbling=3,GravityDrift=4}
function Service:ResolveEvent(id) return Definitions.Definitions[id] end
function Service:_sites(id)
 local sites={};local world=require(script.Parent.OverhaulWorldService)
 for _,region in ipairs(world:GetRegions()) do if region.Depth>=(depths[id] or 1) then table.insert(sites,region) end end
 return sites
end
function Service:SelectEvent(biome,kind)
 local pool={};local tier=RS:GetAttribute("CampaignTier") or 1
 local prior=require(script.Parent.BiomeService):GetVisitSerial()
 local ratio=tier<3 and 2 or 1
 for id,d in pairs(Definitions.Definitions) do
  if d.Type==kind and tier>=d.Tier and (not d.Biomes or d.Biomes[biome]) and #self:_sites(id)>0
   and (not d.Harmful or prior>=2 and self._opportunities>=ratio*(self._harmful+1)) then table.insert(pool,id) end
 end
 table.sort(pool);return #pool>0 and pool[math.random(#pool)] or nil
end
function Service:_send(kind,id,data,player,force)
 if not self._remote then return end
 local ending=kind=="Minor_End" or kind=="Major_End"
 local publicAt=math.max(0,(data.Warning or 0)-((Definitions.Definitions[id] or {}).Warning or 0))
 self._sent=self._sent or {};local sent=self._sent[data.InstanceId] or {};self._sent[data.InstanceId]=sent
 for _,recipient in ipairs(player and {player} or Players:GetPlayers()) do
  local detector=require(script.Parent.InstrumentService):GetCapabilities(recipient).EventDetector
  if ending or (force or not sent[recipient.UserId]) and (data.Elapsed>=publicAt or detector) then
   local payload={InstanceId=data.InstanceId,Name=data.Name,Position=data.Position,Duration=data.Duration,Elapsed=data.Elapsed,Warning=data.Warning,StartedAt=workspace:GetServerTimeNow()-data.Elapsed,WarningRemaining=math.max(0,(data.Warning or 0)-data.Elapsed)}
   self._remote:FireClient(recipient,kind,id,payload);sent[recipient.UserId]=true
  end
 end
 if ending then self._sent[data.InstanceId]=nil end
end
function Service:TriggerEvent(id,biome)
 if paused() then return nil end
 local d=self:ResolveEvent(id);if not d then return nil end
 local kind=d.Type;if self._active[kind] then return nil end
 local surface=participating();if d.Harmful and surface==0 then return nil end
 local sites=self:_sites(id);if #sites==0 then return nil end
 local world=require(script.Parent.OverhaulWorldService);local site=sites[math.random(#sites)]
 local origin=world:SafePosition(id=="CampWarning" and Vector3.new(250,0,0) or site.Center)-Vector3.new(0,5,0)
 local warning=d.Harmful and 45 or 0
 local data={InstanceId=Http:GenerateGUID(false),Type=kind,EventId=id,Biome=biome or require(script.Parent.BiomeService):GetCurrent(),Visit=require(script.Parent.BiomeService):GetVisitSerial(),Elapsed=0,Duration=d.Duration+warning,Warning=warning,Name=d.Name,Position={origin.X,origin.Y,origin.Z},Depth=site.Depth,State={Claims={},Progress=0},Resolved={Name=d.Name,Type=kind,EndOnBiomeChange=true}}
 local entry={Id=id,Data=data};self._active[kind]=entry
 local ok,err=pcall(function() require(script.Parent.ObjectiveRuntimeService):Start(entry) end)
 if not ok then self:EndEvent(kind);warn("[Events] Event initialization failed",id,err);return nil end
 if d.Harmful then self._harmful+=1 else self._opportunities+=1 end
 self:_send(kind.."_Start",id,data)
 return d
end
function Service:EndEvent(kind)
 local entry=self._active[kind];if not entry then return end
 self._active[kind]=nil
 require(script.Parent.ObjectiveRuntimeService):End(entry.Data.InstanceId)
 require(script.Parent.ObjectiveService):End(entry.Id)
 self:_send(kind.."_End",entry.Id,entry.Data)
end
function Service:EndAll() self:EndEvent("Minor");self:EndEvent("Major") end
function Service:GetActive(kind) return self._active[kind] end
function Service:SendActiveToPlayer(player) for kind,entry in pairs(self._active) do self:_send(kind.."_Start",entry.Id,entry.Data,player,true) end end
function Service:_tick(dt)
 if paused() then return end
 self._time+=dt;self._nextMinor-=dt;self._nextMajor-=dt
 local biome=require(script.Parent.BiomeService):GetCurrent();local serial=require(script.Parent.BiomeService):GetVisitSerial()
 for kind,entry in pairs(self._active) do
  entry.Data.Elapsed+=dt
  self:_send(kind.."_Start",entry.Id,entry.Data)
  if entry.Data.Elapsed>=entry.Data.Duration or entry.Data.Visit~=serial then self:EndEvent(kind)
  else require(script.Parent.ObjectiveRuntimeService):Step(entry,dt) end
 end
 local surface=participating()
 if self._nextMinor<=0 and not self._active.Minor and surface>0 then
  local id=self:SelectEvent(biome,"Minor");if id then self:TriggerEvent(id,biome) end;self._nextMinor=math.random(180,300)
 end
 if self._nextMajor<=0 and not self._active.Major and surface>0 then
  local id=self:SelectEvent(biome,"Major");if id then self:TriggerEvent(id,biome) end;self._nextMajor=math.random(600,900)
 end
end
function Service:CaptureState()
 require(script.Parent.ObjectiveRuntimeService):CaptureActors()
 return {SchemaVersion=2,Time=self._time,NextMinor=self._nextMinor,NextMajor=self._nextMajor,Opportunities=self._opportunities,Harmful=self._harmful,Active=Codec.Copy(self._active)}
end
function Service:RestoreState(state)
 if type(state)~="table" or state.SchemaVersion~=2 then return false,"InvalidEventSnapshot" end
 Codec.BoundedCount(state.Active,2)
 self._time=Codec.Number(state.Time,0,1e9);self._nextMinor=Codec.Number(state.NextMinor,-86400,86400);self._nextMajor=Codec.Number(state.NextMajor,-86400,86400)
 self._opportunities=Codec.Number(state.Opportunities,0,1e8);self._harmful=Codec.Number(state.Harmful,0,1e8);self._active=Codec.Copy(state.Active);self._restore=true
 for kind,entry in pairs(self._active) do
  assert((kind=="Minor" or kind=="Major") and Definitions.Definitions[entry.Id],"Unknown saved event")
  Codec.Number(entry.Data.Elapsed,0,86400);Codec.Number(entry.Data.Duration,0,86400)
 end
 return true
end
function Service:CompleteWorldRestore()
 if self._restore then self._restore=nil;for kind,entry in pairs(self._active) do require(script.Parent.ObjectiveRuntimeService):Start(entry,true);self:_send(kind.."_Start",entry.Id,entry.Data) end end
 return true
end
function Service:Init()
 if self._started then return end;self._started=true
 self._remote=RS.Remotes:FindFirstChild("EventBroadcast")
 if self._remote then self._remote.OnServerEvent:Connect(function(player,action)if action=="RequestActive" then self:SendActiveToPlayer(player) end end) end
 task.spawn(function()
  while true do
   local ok,err=pcall(self._tick,self,1);if not ok then warn("[Events]",err) end
   task.wait(1)
  end
 end)
end
return Service
