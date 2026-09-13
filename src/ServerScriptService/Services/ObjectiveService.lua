-- Shared receipt-backed optional objectives; physical interactions live in ObjectiveRuntimeService.
local RS=game:GetService("ReplicatedStorage")
local Codec=require(script.Parent.WorldSnapshotCodec)
local Service={_active={},_claimed={}}
local function hook(kind,...)
 for _,callback in ipairs(((_G.Ecoshift or {}).ObjectiveCallbacks or {})[kind] or {}) do local ok,err=pcall(callback,...);if not ok then warn("[Objectives]",err) end end
end
function Service:Start(id,entry)
 if self._claimed[entry.InstanceId] then return false end
 self._active[id]=entry;entry.State="Active";entry.Data=entry.Data or {Progress=0}
 if self._remote then self._remote:FireAllClients("Start",id,entry) end
 hook("Start",id,entry);return true
end
function Service:Advance(id,delta)
 local entry=self._active[id]
 if not entry or type(delta)~="number" or delta~=delta or delta<=0 or RS:GetAttribute("WorldRestoring") or RS:GetAttribute("WorldShifting") then return false end
 entry.Data.Progress=math.clamp((entry.Data.Progress or 0)+delta,0,1)
 if self._remote then self._remote:FireAllClients("Progress",id,entry.Data.Progress) end
 if entry.Data.Progress>=1 then return self:Complete(id) end
 return true
end
function Service:Complete(id)
 local entry=self._active[id]
 if not entry or self._claimed[entry.InstanceId] then return false end
 self._claimed[entry.InstanceId]=true;entry.State="Completed";entry.Data.Progress=1;self._active[id]=nil
 require(script.Parent.ExpeditionRewardsService):OnObjective(id,entry,entry.Rewards or {})
 if self._remote then self._remote:FireAllClients("End",id,entry) end
 hook("End",id,entry)
 if entry.Schematic then require(script.Parent.EnchantingService):GrantChoice("event:"..entry.InstanceId,entry.Schematic) end
 return true
end
function Service:End(id,state)
 local entry=self._active[id];if not entry then return end
 entry.State=state or "Expired";self._active[id]=nil
 if self._remote then self._remote:FireAllClients("End",id,entry) end;hook("End",id,entry)
end
function Service:EndAll(state) local ids={};for id in pairs(self._active) do table.insert(ids,id) end;for _,id in ipairs(ids) do self:End(id,state) end end
function Service:GetActiveSnapshot() return Codec.Copy(self._active) end
function Service:SendActiveToPlayer(player) if self._remote then for id,entry in pairs(self._active) do self._remote:FireClient(player,"Start",id,entry) end end end
function Service:CaptureState() return {SchemaVersion=2,Active=Codec.Copy(self._active),Claimed=Codec.Copy(self._claimed)} end
function Service:RestoreState(state)
 if type(state)~="table" or state.SchemaVersion~=2 then return false,"InvalidObjectiveSnapshot" end
 Codec.BoundedCount(state.Active,2);Codec.BoundedCount(state.Claimed,10000)
 self._active=Codec.Copy(state.Active);self._claimed=Codec.Copy(state.Claimed);return true
end
function Service:CompleteWorldRestore() return true end
function Service:Init()
 if self._started then return end;self._started=true
 self._remote=RS.Remotes:FindFirstChild("ObjectiveUpdate")
 _G.Ecoshift=_G.Ecoshift or {};_G.Ecoshift.ObjectiveCallbacks={Start={},End={},Progress={}}
 for _,kind in ipairs({"Start","End","Progress"}) do _G.Ecoshift["OnObjective"..kind.."Add"]=function(cb) table.insert(_G.Ecoshift.ObjectiveCallbacks[kind],cb) end end
 if self._remote then self._remote.OnServerEvent:Connect(function(player,action)if action=="RequestActive" then self:SendActiveToPlayer(player) end end) end
end
return Service
