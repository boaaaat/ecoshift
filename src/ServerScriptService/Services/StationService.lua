-- Shared furnace escrow and station grades. No station work accrues offline.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Ingredients=require(RS.Shared.IngredientResolver)
local Inventory=require(script.Parent.InventoryService)
local Items=require(RS.Shared.Items.ItemDatabase)
local Codec=require(script.Parent.WorldSnapshotCodec)
local GameState=require(script.Parent.GameStateService)
local S={_states={},_viewers={},_requests={},_rateLimits={}}
local function integer(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
local function alive(p)
 local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 return hum and hum.Health>0 and not p:GetAttribute("IsDead") and not p:GetAttribute("WorldPlayerLoading") and not p:GetAttribute("WorldPlayerRestoring")
end
local function kind(model)
 if typeof(model)~="Instance" or not model:IsDescendantOf(workspace) or not Collection:HasTag(model,"Structure") or not (model:IsA("Model") or model:IsA("BasePart")) then return nil end
 local id=model:GetAttribute("BuildType") or model:GetAttribute("StationType")
 return Catalog.Stations[id] and id or nil
end
function S:Validate(p,model,grade)
 local id=kind(model);local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 if not id or not alive(p) or not root or GameState:IsGameOver() or RS:GetAttribute("WorldRestoring") then return false,"Station unavailable" end
 if (root.Position-model:GetPivot().Position).Magnitude>10 then return false,"Move closer to the station" end
 if (tonumber(model:GetAttribute("StationGrade")) or Catalog.Stations[id].Grade)<(grade or 1) then return false,"Station grade "..tostring(grade).." required" end
 return true
end
function S:Bind(model,stationType,grade)
 if not Catalog.Stations[stationType] or stationType=="Hand" then return end
 model:SetAttribute("StationType",stationType)
 model:SetAttribute("StationGrade",math.clamp(math.floor(tonumber(grade) or tonumber(model:GetAttribute("StationGrade")) or Catalog.Stations[stationType].Grade),1,8))
 if not self._states[model] then
  local output={};for i=1,12 do output[i]=false end
  self._states[model]={Version=1,FuelWork=0,Jobs={},Output=output,Enabled=true}
 end
end
function S:Snapshot(model)
 local state=self._states[model];return state and Codec.Copy(state) or nil
end
function S:Restore(model,state)
 if not state then return end
 assert(type(state)=="table" and state.Version==1,"Invalid furnace snapshot")
 self:Bind(model,model:GetAttribute("BuildType"),model:GetAttribute("StationGrade"))
 self._states[model]=Codec.Copy(state)
end
function S:CanSalvage(player,model)
 local state=self._states[model];if not state then return true end
 if #state.Jobs>0 then return false,"Cancel unfinished furnace jobs before salvaging" end
 for _,slot in ipairs(state.Output) do if slot then return false,"Collect furnace output before salvaging" end end
 return true
end
function S:Remove(model) self._states[model]=nil end
local function fitOutput(output,id,n)
 local result=Codec.Copy(output);local limit=Items:Get(id).StackSize
 for i,entry in ipairs(result) do if entry and entry.Id==id then local add=math.min(n,limit-entry.N);entry.N+=add;n-=add end end
 for i,entry in ipairs(result) do if not entry and n>0 then local add=math.min(n,limit);result[i]={Id=id,N=add};n-=add end end
 return n==0 and result or nil
end
function S:_view(model)
 local state=self._states[model];local grade=model:GetAttribute("StationGrade") or 1
 return {Station=model,StationType=kind(model),Grade=grade,CampaignTier=workspace:GetAttribute("CampaignTier") or 1,UpgradeCost=Catalog.GetStationUpgradeCost(grade+1),State=state and Codec.Copy(state)}
end
function S:_send(p,model,message)
 if self._remote and model and model.Parent then local view=self:_view(model);view.Message=message;self._remote:FireClient(p,"Snapshot",view) end
end
function S:Handle(p,action,payload)
 if type(action)~="string" or type(payload)~="table" then return end
 local model=payload.Station
 if action=="Close" then self._viewers[p]=nil;return end
 local ok,reason=self:Validate(p,model,1)
 if not ok then return false,reason end
 local id=kind(model);self:Bind(model,id)
 local state=self._states[model]
 if action=="Open" then self._viewers[p]=model;return true,"Station ready" end
 if action=="Upgrade" then
  local grade=model:GetAttribute("StationGrade") or 1;local nextGrade=grade+1
  if nextGrade>8 then return false,"Station is fully upgraded" end
  if nextGrade>(workspace:GetAttribute("CampaignTier") or 1) then return false,"Complete the next campaign certification first" end
  if #state.Jobs>0 then return false,"Finish or cancel furnace work first" end
  local cooking=require(script.Parent.CookingService)
  local cookingState=cooking._stations and cooking._stations[model]
  if cookingState and #cookingState.Jobs>0 then return false,"Finish or cancel cooking work first" end
  for _,job in pairs(require(script.Parent.CraftingService)._activeCrafts) do if job.Station==model then return false,"Finish accepted station crafts first" end end
  if not Inventory:PayCost(p,Catalog.GetStationUpgradeCost(nextGrade),true) then return false,"Missing upgrade materials" end
  model:SetAttribute("StationGrade",nextGrade);Inventory:Sync(p);return true,"Upgraded to grade "..nextGrade
 end
 if id~="Furnace" then return false,"This action requires a furnace" end
 if action=="Queue" then
  local recipe=Catalog.Recipes[payload.RecipeId];local quantity=payload.Quantity or 1
  if not recipe or not table.find(recipe.AllowedStations or {},"Furnace") or not integer(quantity,1,20) then return false,"Choose a furnace recipe and 1–20 batches" end
  if #state.Jobs>=3 then return false,"The three-job queue is full" end
  if recipe.CampaignTier>(workspace:GetAttribute("CampaignTier") or 1) then return false,"Campaign tier "..recipe.CampaignTier.." required" end
  local valid,why=self:Validate(p,model,recipe.RequiredGrade);if not valid then return false,why end
  local paid,missing=Ingredients.Resolve(recipe.Ingredients,quantity,function(itemId)return Inventory:TotalCount(p,itemId) end,p)
  if not paid then return false,missing end
  if not Inventory:PayCost(p,paid,true) then return false,"Ingredients changed; try again" end
  table.insert(state.Jobs,{RecipeId=payload.RecipeId,RecipeVersion=2,OwnerUserId=p.UserId,Remaining=quantity,Total=quantity,Work=0,WorkRequired=recipe.BaseCraftTime,Inputs=Codec.Copy(recipe.Ingredients),Output=Codec.Copy(recipe.Output),Paid=paid})
  Inventory:Sync(p);return true,"Queued "..quantity.." batches"
 elseif action=="Fuel" then
  local value=Catalog.FurnaceFuels[payload.ItemId];local n=payload.Quantity or 1
  if not value or not integer(n,1,50) then return false,"Choose Wood, Peat, or Coal" end
  if state.FuelWork+value*n>3600 then return false,"Fuel storage is full" end
  if not Inventory:PayCost(p,{{Id=payload.ItemId,N=n}},true) then return false,"Missing fuel" end
  state.FuelWork+=value*n;Inventory:Sync(p);return true,"Fuel added"
 elseif action=="Toggle" then state.Enabled=not state.Enabled;return true,state.Enabled and "Furnace enabled" or "Furnace paused"
 elseif action=="Cancel" then
  local index=payload.Index
  if not integer(index,1,#state.Jobs) then return false,"That job no longer exists" end
  local job=state.Jobs[index];local refund={}
  for _,entry in ipairs(job.Inputs) do table.insert(refund,{Id=entry.Id,N=entry.N*job.Remaining}) end
  local projected,overflow=Inventory:ProjectRefund(Inventory:CaptureWorldState(p),refund,false)
  if #overflow>0 then return false,"Make room for the refunded materials" end
  table.remove(state.Jobs,index);Inventory:RestoreWorldState(p,projected,true);Inventory:Sync(p);return true,"Unfinished ingredients refunded; used fuel stays spent"
 elseif action=="Collect" then
  local index=payload.Index
  if not integer(index,1,12) or not state.Output[index] then return false,"That output was already collected" end
  local output=state.Output[index]
  if not Inventory:CanFit(p,output.Id,output.N) then return false,"Inventory is full" end
  if Inventory:Give(p,output.Id,output.N,true,true)~=output.N then return false,"Inventory is full" end
  state.Output[index]=false;Inventory:Sync(p);return true,"Output collected"
 end
 return false,"Unknown station action"
end
function S:Init()
 if self._initialized then return end;self._initialized=true
 local folder=RS:WaitForChild("Remotes")
 local remote=folder:FindFirstChild("Station") or Instance.new("RemoteEvent");remote.Name="Station";remote.Parent=folder;self._remote=remote
 remote.OnServerEvent:Connect(function(p,action,payload)
  local now=os.clock();if now-(self._rateLimits[p] or 0)<.08 then return end;self._rateLimits[p]=now
  if type(payload)~="table" then return end
  local request=payload.RequestId
  if type(request)~="string" or #request>80 then return end
  self._requests[p]=self._requests[p] or {}
  if self._requests[p][request] then return end
  self._requests[p][request]=now
  for key,time in pairs(self._requests[p]) do if now-time>120 then self._requests[p][key]=nil end end
  local ok,reason=self:Handle(p,action,payload)
  if self._viewers[p] then self:_send(p,self._viewers[p],reason) else remote:FireClient(p,"Result",{Success=ok==true,Message=reason}) end
 end)
 local function bind(model)local id=model:GetAttribute("BuildType") or model:GetAttribute("StationType");if Catalog.Stations[id] then self:Bind(model,id) end end
 Collection:GetInstanceAddedSignal("Structure"):Connect(bind)
 for _,model in ipairs(Collection:GetTagged("Structure")) do bind(model) end
 Players.PlayerRemoving:Connect(function(p)self._viewers[p]=nil;self._requests[p]=nil;self._rateLimits[p]=nil end)
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  local loaded=false;for _,p in ipairs(Players:GetPlayers()) do if not p:GetAttribute("WorldPlayerLoading") and not p:GetAttribute("WorldPlayerRestoring") then loaded=true;break end end
  local paused=RS:GetAttribute("WorldRestoring") or GameState:IsGameOver() or not loaded
  for model,state in pairs(self._states) do
   if not model.Parent then self._states[model]=nil
   elseif not paused and kind(model)=="Furnace" and state.Enabled and state.Jobs[1] and state.FuelWork>0 then
    local job=state.Jobs[1];local output=fitOutput(state.Output,job.Output.Id,job.Output.N)
    if output then
     local owner=Players:GetPlayerByUserId(job.OwnerUserId)
     local rate=require(script.Parent.ClassAbilityService):GetCraftRate(owner and alive(owner) and owner or nil,model)
     local work=math.min(dt*math.clamp(rate,1,2),state.FuelWork,job.WorkRequired-job.Work)
     job.Work+=work;state.FuelWork-=work
     if job.Work>=job.WorkRequired then
      state.Output=output;job.Remaining-=1;job.Work=0
      if job.Remaining==0 then table.remove(state.Jobs,1) end
     end
    end
   end
  end
  elapsed+=dt;if elapsed>=.25 then
   elapsed=0
   for p,model in pairs(self._viewers) do
    local ok=self:Validate(p,model,1)
    if ok then self:_send(p,model) else self._viewers[p]=nil;remote:FireClient(p,"Close",{}) end
   end
  end
 end)
end
return S
