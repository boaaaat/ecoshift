-- Shared furnace escrow and station grades. No station work accrues offline.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Catalog=require(RS.Shared.OverhaulCatalog)
local Ingredients=require(RS.Shared.IngredientResolver)
local Inventory=require(script.Parent.InventoryService)
local Items=require(RS.Shared.Items.ItemDatabase)
local ServerUtil=require(script.Parent.ServerUtil)
local Codec=require(script.Parent.WorldSnapshotCodec)
local GameState=require(script.Parent.GameStateService)
local S={_states={},_viewers={},_requests={},_rateLimits={}}
local function integer(n,a,b) return type(n)=="number" and n==n and n%1==0 and n>=a and n<=b end
local function alive(p)
 return ServerUtil.IsLiving(p)
end
local function kind(model)
 if typeof(model)~="Instance" or not model:IsDescendantOf(workspace) or not Collection:HasTag(model,"Structure") or not (model:IsA("Model") or model:IsA("BasePart")) then return nil end
 local id=model:GetAttribute("BuildType") or model:GetAttribute("StationType")
 return Catalog.Stations[id] and id or nil
end
local function normalizeState(state)
 -- Saved slot maps may have string indices. Always keep twelve explicit slots.
 local output={}
 for i=1,12 do output[i]=state.Output and (state.Output[i] or state.Output[tostring(i)]) or false end
 state.Output=output
 state.Jobs=state.Jobs or {}
 state.Enabled=state.Enabled~=false
 state.FuelWork=math.clamp(tonumber(state.FuelWork) or 0,0,3600)
 for _,job in ipairs(state.Jobs) do job.Id=job.Id or HttpService:GenerateGUID(false) end
 return state
end
function S:Validate(p,model,grade)
 local id=kind(model);local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 if not id or not alive(p) or not root or GameState:IsGameOver() or RS:GetAttribute("WorldRestoring") then return false,"Station unavailable" end
 local radius=Catalog.Stations[id].InteractRadius or 15
 if (root.Position-model:GetPivot().Position).Magnitude>radius then return false,"Move closer to the station" end
 if (tonumber(model:GetAttribute("StationGrade")) or Catalog.Stations[id].Grade)<(grade or 1) then return false,"Station grade "..tostring(grade).." required" end
 return true
end
function S:Bind(model,stationType,grade)
 if not Catalog.Stations[stationType] or stationType=="Hand" then return end
 model:SetAttribute("StationType",stationType)
 local definition=Catalog.Stations[stationType]
 model:SetAttribute("StationGrade",math.clamp(math.floor(tonumber(grade) or tonumber(model:GetAttribute("StationGrade")) or definition.Grade),definition.Grade,Catalog.GetStationMaxGrade(stationType) or definition.Grade))
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
 self._states[model]=normalizeState(Codec.Copy(state))
end
function S:CanSalvage(player,model)
 local state=self._states[model];if not state then return true end
 if #state.Jobs>0 then return false,"Cancel unfinished furnace jobs before salvaging" end
 for _,slot in ipairs(state.Output) do if slot then return false,"Collect furnace output before salvaging" end end
 return true
end
function S:Remove(model) self._states[model]=nil end
local function fitOutput(output,id,n)
 local item=Items:Get(id);if not item then return nil end
 local result=Codec.Copy(output);local limit=item.StackSize
 for i=1,12 do local entry=result[i];if entry and entry.Id==id then local add=math.min(n,math.max(0,limit-entry.N));entry.N+=add;n-=add end end
 for i=1,12 do if not result[i] and n>0 then local add=math.min(n,limit);result[i]={Id=id,N=add};n-=add end end
 return n==0 and result or nil
end
function S:_status(state)
 if not state.Enabled then return "Paused" end
 local job=state.Jobs[1]
 if not job then return "Ready" end
 if not Items:Get(job.Output.Id) then return "Invalid recipe — cancel for refund" end
 if not fitOutput(state.Output,job.Output.Id,job.Output.N) then return "Output full — collect items" end
 if state.FuelWork<=0 then return "Needs fuel" end
 return "Smelting"
end
function S:_view(model)
 local state=self._states[model];local stationType=kind(model);local grade=model:GetAttribute("StationGrade") or 1
 local upgradeCost,nextGrade=Catalog.GetStationUpgradeCost(stationType,grade)
 return {Station=model,StationType=stationType,Grade=grade,NextGrade=nextGrade,MaxGrade=Catalog.GetStationMaxGrade(stationType),CampaignTier=workspace:GetAttribute("CampaignTier") or 1,UpgradeCost=upgradeCost,State=state and Codec.Copy(state),Status=state and self:_status(state)}
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
  local grade=model:GetAttribute("StationGrade") or Catalog.Stations[id].Grade
  local upgradeCost,nextGrade=Catalog.GetStationUpgradeCost(id,grade)
  if not nextGrade then return false,"Station is fully upgraded" end
  if nextGrade>(workspace:GetAttribute("CampaignTier") or 1) then return false,"Complete the next campaign certification first" end
  if #state.Jobs>0 then return false,"Finish or cancel furnace work first" end
  local cooking=require(script.Parent.CookingService)
  local cookingState=cooking._stations and cooking._stations[model]
  if cookingState and #cookingState.Jobs>0 then return false,"Finish or cancel cooking work first" end
  for _,job in pairs(require(script.Parent.CraftingService)._activeCrafts) do if job.Station==model then return false,"Finish accepted station crafts first" end end
  if not Inventory:PayCost(p,upgradeCost,true) then return false,"Missing upgrade materials" end
  model:SetAttribute("StationGrade",nextGrade);Inventory:Sync(p);return true,"Upgraded to grade "..nextGrade
 end
 if id~="Furnace" then return false,"This action requires a furnace" end
 if action=="Queue" then
  local recipe=Catalog.Recipes[payload.RecipeId];local quantity=payload.Quantity or 1
  if not recipe or recipe.Future or not table.find(recipe.AllowedStations or {},"Furnace") or not integer(quantity,1,20) then return false,"Choose a furnace recipe and 1–20 batches" end
  if #state.Jobs>=3 then return false,"The three-job queue is full" end
  if recipe.CampaignTier>(workspace:GetAttribute("CampaignTier") or 1) then return false,"Campaign tier "..recipe.CampaignTier.." required" end
  local valid,why=self:Validate(p,model,recipe.RequiredGrade);if not valid then return false,why end
  local paid,missing=Ingredients.Resolve(recipe.Ingredients,quantity,function(itemId)return Inventory:TotalCount(p,itemId) end,p)
  if not paid then return false,missing end
  -- Prepare the complete job before taking anything from inventory.
  if not recipe.Output or not Items:Get(recipe.Output.Id) or not integer(recipe.Output.N,1,999) or not integer(recipe.BaseCraftTime,1,3600) then return false,"Recipe unavailable; materials kept" end
  local job={Id=HttpService:GenerateGUID(false),RecipeId=payload.RecipeId,RecipeVersion=2,OwnerUserId=p.UserId,Remaining=quantity,Total=quantity,Work=0,WorkRequired=recipe.BaseCraftTime,Inputs=Codec.Copy(recipe.Ingredients),Output=Codec.Copy(recipe.Output),Paid=paid}
  if not Inventory:PayCost(p,paid,true) then return false,"Ingredients changed; try again" end
  table.insert(state.Jobs,job)
  Inventory:Sync(p);return true,"Queued "..quantity.." batches · "..self:_status(state)
 elseif action=="Fuel" then
  local value=Catalog.FurnaceFuels[payload.ItemId];local n=payload.Quantity or 1
  if not value or not integer(n,1,50) then return false,"Choose Wood, Peat, or Coal" end
  if state.FuelWork+value*n>3600 then return false,"Fuel storage is full" end
  if not Inventory:PayCost(p,{{Id=payload.ItemId,N=n}},true) then return false,"Missing fuel" end
  state.FuelWork+=value*n;Inventory:Sync(p);return true,"Fuel added · "..math.floor(state.FuelWork).."s stored · "..self:_status(state)
 elseif action=="Toggle" then state.Enabled=not state.Enabled;return true,state.Enabled and "Furnace enabled" or "Furnace paused"
 elseif action=="Cancel" then
  local index=payload.Index
  if type(payload.JobId)=="string" then
   index=nil;for i,job in ipairs(state.Jobs) do if job.Id==payload.JobId then index=i;break end end
  end
  if not integer(index,1,#state.Jobs) then return false,"That job no longer exists" end
  local job=state.Jobs[index];local refund={}
  for _,entry in ipairs(job.Paid or job.Inputs) do
   local amount=job.Paid and math.floor(entry.N*job.Remaining/job.Total+.00001) or entry.N*job.Remaining
   if amount>0 then table.insert(refund,{Id=entry.Id,N=amount}) end
  end
  if not Inventory:GiveEntriesOrDrop(p,refund,true) then return false,"Unable to refund materials. Try again." end
  table.remove(state.Jobs,index);Inventory:Sync(p);return true,"Unfinished ingredients refunded; used fuel stays spent"
 elseif action=="Collect" then
  local index=payload.Index
  if not integer(index,1,12) or not state.Output[index] then return false,"That output was already collected" end
  local output=state.Output[index]
  if payload.ExpectedId and payload.ExpectedId~=output.Id then return false,"Output changed; choose the item again" end
  if Inventory:GiveOrDrop(p,output.Id,output.N,true)~=output.N then return false,"Unable to collect output. Try again." end
  state.Output[index]=false;Inventory:Sync(p);return true,"Output collected"
 end
 return false,"Unknown station action"
end
function S:Init()
 if self._initialized then return end;self._initialized=true
 local folder=RS:WaitForChild("Remotes")
 local remote=folder:FindFirstChild("Station") or Instance.new("RemoteEvent");remote.Name="Station";remote.Parent=folder;self._remote=remote
 remote.OnServerEvent:Connect(function(p,action,payload)
  if type(payload)~="table" then return end
  local request=payload.RequestId
  if type(request)~="string" or #request>80 then return end
  if action=="Close" then self._viewers[p]=nil;remote:FireClient(p,"Close",{});return end
  local now=os.clock()
  self._requests[p]=self._requests[p] or {}
  local previous=self._requests[p][request]
  if previous then remote:FireClient(p,"Result",previous.Result);return end
  if now-(self._rateLimits[p] or 0)<.08 then
   remote:FireClient(p,"Result",{RequestId=request,Success=false,Message="Please wait a moment before the next action"});return
  end
  self._rateLimits[p]=now
  for key,record in pairs(self._requests[p]) do if now-record.Time>120 then self._requests[p][key]=nil end end
  local ok,reason=self:Handle(p,action,payload)
  local result={RequestId=request,Station=payload.Station,Success=ok==true,Message=reason}
  self._requests[p][request]={Time=now,Result=result}
  if self._viewers[p] then self:_send(p,self._viewers[p]) end
  remote:FireClient(p,"Result",result)
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
     local work=math.min(dt*rate,state.FuelWork,job.WorkRequired-job.Work)
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
