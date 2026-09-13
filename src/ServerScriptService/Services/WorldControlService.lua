-- A single authoritative team ballot. Inventory never exposes schedule secrets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ControlConfig = require(ReplicatedStorage.Shared.WorldControlConfig)
local InventoryService = require(script.Parent.InventoryService)
local BiomeService = require(script.Parent.BiomeService)
local GameStateService = require(script.Parent.GameStateService)
local WorldControlService = { _cooldowns = {}, _serial = 0, _lastRequest = {}, _receipts={}, _refunds={} }
local Copy=require(ReplicatedStorage.Shared.ItemInstance).Copy

local function isAlive(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return player.Parent == Players and not player:GetAttribute("IsDead") and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") and hum and hum.Health > 0
end

function WorldControlService:_feedback(player, success, message)
	if player and player.Parent == Players then
		self._remote:FireClient(player, "Feedback", { Success = success, Message = message })
	end
end

function WorldControlService:_counts(ballot)
 for _,player in ipairs(Players:GetPlayers()) do if isAlive(player) and (not ballot.Voters[player.UserId] or ballot.Voters[player.UserId].Player~=player) then ballot.Voters[player.UserId]={Player=player};ballot.Votes[player.UserId]=nil end end
	local yes, no, connected = 0, 0, 0
	for userId, voter in pairs(ballot.Voters) do
		if not voter.Left and isAlive(voter.Player) then
			connected += 1
			if ballot.Votes[userId] == true then yes += 1
			elseif ballot.Votes[userId] == false then no += 1 end
		end
	end
	ballot.Required=math.floor(connected/2)+1
	return yes, no, connected
end

function WorldControlService:SendToPlayer(player)
	if player.Parent ~= Players then return end
 self:_deliverRefund(player)
	local now = os.clock()
	local status = { Actions = {}, EligibleBiomes = BiomeService:GetEligibleBiomes(), VisitedBiomes={}, WeatherChoices={}, GameOver = GameStateService:IsGameOver() }
 for _,id in ipairs(status.EligibleBiomes) do
  if (BiomeService:GetVisits()[id] or 0)>0 then table.insert(status.VisitedBiomes,id) end
  status.WeatherChoices[id]={}
  for _,weather in ipairs(require(ReplicatedStorage.Shared.SurvivalConfig).WEATHER_BY_BIOME[id] or {}) do
   if (weather.MinTier or 1)<=(ReplicatedStorage:GetAttribute("CampaignTier") or 1) then table.insert(status.WeatherChoices[id],{Id=weather.Id,Name=weather.Name}) end
  end
 end
	for action, def in pairs(ControlConfig.Actions) do
		local owned = InventoryService:Has(player, def.Device, 1)
		local fuel, hasFuel = {}, InventoryService:CanAfford(player, def.Fuel)
		for _, cost in ipairs(def.Fuel) do
			table.insert(fuel, { Id = cost.Id, N = cost.N, Owned = InventoryService:TotalCount(player, cost.Id) })
		end
		local cooldown = math.max(0, math.ceil((self._cooldowns[action] or 0) - now))
		local reason = status.GameOver and "The expedition has ended."
			or (not isAlive(player) and "A living teammate must propose.")
			or (not owned and "Craft " .. def.Name .. " first.")
			or (not hasFuel and "More fuel is needed.")
			or (cooldown > 0 and "Team cooldown: " .. cooldown .. "s")
			or (self._ballot and "A team ballot is already open.") or nil
		status.Actions[action] = { Owned = owned, HasFuel = hasFuel, Fuel = fuel, Cooldown = cooldown, CanPropose = reason == nil, Reason = reason }
	end
	local ballot = self._ballot
	if ballot then
		local yes, no, count = self:_counts(ballot)
		local voter = ballot.Voters[player.UserId]
		status.Ballot = {
			Id = ballot.Id, Action = ballot.Action, Biome = type(ballot.Biome)=="table" and ballot.Biome.Biome or ballot.Biome, Weather=type(ballot.Biome)=="table" and ballot.Biome.Weather or nil, Extend=type(ballot.Biome)=="table" and ballot.Biome.Extend or false,
			Proposer = ballot.Proposer.DisplayName, ExpiresIn = math.max(0, math.ceil(ballot.ExpiresAt - now)),
			Yes = yes, No = no, Required = ballot.Required, Connected = count,
			CanVote = voter ~= nil and not voter.Left and isAlive(player) and ballot.Votes[player.UserId] == nil,
			Vote = ballot.Votes[player.UserId],
		}
	end
	self._remote:FireClient(player, "Snapshot", status)
end

function WorldControlService:Broadcast()
	for _, player in ipairs(Players:GetPlayers()) do self:SendToPlayer(player) end
end

function WorldControlService:_finish(success, message)
	self._ballot = nil
	self._remote:FireAllClients("Feedback", { Success = success, Message = message })
	self:Broadcast()
end

function WorldControlService:_validateProposer(player, action, biome, version)
	if ReplicatedStorage:GetAttribute("WorldRestoring") then return false, "The expedition is loading." end
	local def = ControlConfig.Actions[action]
	if not def then return false, "Unknown world control." end
	if GameStateService:IsGameOver() then return false, "The expedition has ended." end
	if not isAlive(player) then return false, "A living teammate must propose." end
	if (self._cooldowns[action] or 0) > os.clock() then return false, "This device is on team cooldown." end
	if not InventoryService:Has(player, def.Device, 1) then return false, "The proposer must carry " .. def.Name .. "." end
	if not InventoryService:CanAfford(player, def.Fuel) then return false, "The proposer needs the listed fuel." end
	return BiomeService:CanControl(action, biome, version)
end

function WorldControlService:_commit(ballot)
	if self._ballot ~= ballot then return end
	local valid, reason = self:_validateProposer(ballot.Proposer, ballot.Action, ballot.Biome, ballot.Version)
	if not valid then self:_finish(false, reason) return end
	local def = ControlConfig.Actions[ballot.Action]
 -- Costs and schedule mutation run without yielding; keep an exact receipt until generation commits.
 local paid=InventoryService:TakeCost(ballot.Proposer,def.Fuel,true)
 if not paid then self:_finish(false,"Fuel is no longer available.");return end
 local ran,applied,errorMessage=pcall(BiomeService.ApplyControl,BiomeService,ballot.Action,ballot.Biome,ballot.Version)
 if not ran or not applied then
  for _,entry in ipairs(paid) do InventoryService:GiveEntry(ballot.Proposer,entry,false,true) end
  InventoryService:Sync(ballot.Proposer)
  self:_finish(false,ran and errorMessage or "The control failed; fuel was returned.");return
 end
 table.insert(self._receipts,{UserId=ballot.Proposer.UserId,Action=ballot.Action,Fuel=Copy(paid)})
 self._cooldowns[ballot.Action]=os.clock()+def.Cooldown
 InventoryService:Sync(ballot.Proposer)
	local message = ballot.Action == "Delay" and "Team approved: the biome has been stabilized."
		or (ballot.Action == "Advance" and "Team approved: the world shifts in 15 seconds!")
		or "Team approved: the next destination is locked."
	self:_finish(true, message)
	GameStateService:Broadcast()
end

function WorldControlService:_evaluate()
	local ballot = self._ballot
	if not ballot then return end
	if GameStateService:IsGameOver() then self:_finish(false, "The expedition has ended.") return end
	if not isAlive(ballot.Proposer) then self:_finish(false, "The proposer is no longer available. No fuel was spent.") return end
	if BiomeService:GetTiming().Version ~= ballot.Version then self:_finish(false, "The schedule changed. Propose a new ballot; no fuel was spent.") return end
	if os.clock() >= ballot.ExpiresAt then self:_finish(false, "The ballot expired without a majority. No fuel was spent.") return end
	local yes, no, connected = self:_counts(ballot)
	if yes >= ballot.Required then self:_commit(ballot)
	elseif connected - no < ballot.Required then self:_finish(false, "The ballot cannot reach a majority. No fuel was spent.") end
end

function WorldControlService:Propose(player, action, biome)
	if self._ballot then self:_feedback(player, false, "Finish the current team ballot first.") return end
	if type(action) ~= "string" then return end
 if action=="Anchor" then
  if type(biome)~="table" or type(biome.Biome)~="string" or type(biome.Weather)~="string" or type(biome.Extend)~="boolean" then return end
  biome={Biome=biome.Biome,Weather=biome.Weather,Extend=biome.Extend}
 elseif action=="Select" then if type(biome)~="string" then return end
 else biome=nil end
	local version = BiomeService:GetTiming().Version
	local valid, reason = self:_validateProposer(player, action, biome, version)
	if not valid then self:_feedback(player, false, reason) return end
	local voters, count = {}, 0
	for _, voter in ipairs(Players:GetPlayers()) do
		if isAlive(voter) then voters[voter.UserId] = { Player = voter };count += 1 end
	end
	self._serial += 1
	self._ballot = {
		Id = self._serial, Action = action, Biome = biome, Version = version, Proposer = player,
		Voters = voters, Votes = { [player.UserId] = true }, Required = math.floor(count / 2) + 1,
		ExpiresAt = os.clock() + ControlConfig.VoteSeconds,
	}
	self:Broadcast()
	self:_evaluate()
end

function WorldControlService:Vote(player, ballotId, approve)
	local ballot = self._ballot
	if not ballot or ballot.Id ~= ballotId or type(approve) ~= "boolean" then self:_feedback(player, false, "That ballot is no longer open.") return end
	local voter = ballot.Voters[player.UserId]
	if not voter or voter.Left or not isAlive(player) then self:_feedback(player, false, "You may vote in the next ballot.") return end
	if ballot.Votes[player.UserId] ~= nil then self:_feedback(player, false, "Your vote has already been recorded.") return end
	ballot.Votes[player.UserId] = approve
	self:_evaluate()
	self:Broadcast()
end

function WorldControlService:Init()
	if self._initialized then return end
	self._initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self._remote = remotes:FindFirstChild(Config.RemoteNames.WorldControl) or Instance.new("RemoteEvent")
	self._remote.Name, self._remote.Parent = Config.RemoteNames.WorldControl, remotes
	self._remote.OnServerEvent:Connect(function(player, action, payload)
		if action ~= "RequestSnapshot" and action ~= "Propose" and action ~= "Vote" then return end
		local now = os.clock()
		local requests = self._lastRequest[player] or {}
		self._lastRequest[player] = requests
		if now - (requests[action] or -math.huge) < 0.15 then return end
		requests[action] = now
		if action == "RequestSnapshot" then self:SendToPlayer(player)
		elseif type(payload) == "table" then
			if action == "Propose" then self:Propose(player, payload.Action, payload.Biome)
			elseif action == "Vote" then self:Vote(player, payload.Id, payload.Approve) end
		end
	end)
	InventoryService:OnChanged(function(player) self:SendToPlayer(player) end)
	Players.PlayerAdded:Connect(function(player) task.defer(function() self:SendToPlayer(player) end) end)
	Players.PlayerRemoving:Connect(function(player)
		self._lastRequest[player] = nil
		local ballot = self._ballot
		if ballot then
   if ballot.Proposer==player then self:_finish(false,"The proposer disconnected. No fuel was spent.")
   elseif ballot.Voters[player.UserId] then ballot.Voters[player.UserId].Left=true;self:_evaluate() end
  end
	end)
	task.spawn(function()
		local previous=os.clock()
  while true do
   local now=os.clock();local dt=now-previous;previous=now
   local active=false;for _,player in ipairs(Players:GetPlayers()) do if isAlive(player) then active=true;break end end
   if not active or ReplicatedStorage:GetAttribute("WorldRestoring") then for action,expires in pairs(self._cooldowns) do self._cooldowns[action]=expires+dt end end
   self:_evaluate()
			self:Broadcast()
			task.wait(1)
		end
	end)
end

function WorldControlService:CaptureWorldState()
	local cooldowns = {}
	for action, expires in pairs(self._cooldowns) do cooldowns[action] = math.max(0, expires - os.clock()) end
	return { Cooldowns = cooldowns, Serial = self._serial, Receipts=Copy(self._receipts),Refunds=Copy(self._refunds) }
end

function WorldControlService:RestoreWorldState(state)
	local codec = require(script.Parent.WorldSnapshotCodec)
	local cooldowns = {}
	for action, remaining in pairs(state.Cooldowns) do
		assert(ControlConfig.Actions[action], "Unknown restored world control")
		cooldowns[action] = os.clock() + codec.Number(remaining, 0, 86400)
	end
	self._cooldowns, self._serial = cooldowns, codec.Number(state.Serial, 0, 1e9)
	-- Votes authorize a present team; a disconnected session cannot carry consent.
	self._ballot, self._lastRequest = nil, {}
 self._receipts=Copy(state.Receipts or {});self._refunds=Copy(state.Refunds or {})
end

function WorldControlService:_deliverRefund(player)
 local key=tostring(player.UserId);local pending=self._refunds[key]
 if self._delivering or not pending or ReplicatedStorage:GetAttribute("WorldRestoring") or player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring") then return end
 self._delivering=true;self._refunds[key]=nil
 local remainder={}
 for _,entry in ipairs(pending) do
  local count=InventoryService:GiveEntry(player,entry,false,true)
  if count<entry.N then local rest=Copy(entry);rest.N-=count;table.insert(remainder,rest) end
 end
 if #remainder>0 then self._refunds[key]=remainder end
 InventoryService:Sync(player);self._delivering=false
end
function WorldControlService:ResolveGeneration(success)
 local receipts=self._receipts;self._receipts={}
 if success then return end
 for _,receipt in ipairs(receipts) do
  local key=tostring(receipt.UserId);self._refunds[key]=self._refunds[key] or {}
  for _,entry in ipairs(receipt.Fuel) do table.insert(self._refunds[key],entry) end
  self._cooldowns[receipt.Action]=nil
 end
 for _,player in ipairs(Players:GetPlayers()) do self:_deliverRefund(player) end
 if self._remote and #receipts>0 then self:_finish(false,"World generation failed. Control fuel was refunded and cooldowns cleared.") end
end
return WorldControlService
