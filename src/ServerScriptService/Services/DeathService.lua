-- DeathService.lua
-- Handles player death, ragdoll, revival, and spectate coordination
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DEBUG = false

local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local InventoryService = require(script.Parent.InventoryService)
local ItemDropService = require(script.Parent.ItemDropService)
local StatsService = require(script.Parent.StatsService)
local GameStateService = require(script.Parent.GameStateService)

local DeathService = {}
DeathService._deadPlayers = {} -- [player] = { ragdoll: Model, deathTime: number }
DeathService._spectating = {} -- [player] = targetPlayer
DeathService._reviveHolds = {}
DeathService._runStats = {}
local REVIVE_ITEM = "ReviveKit"

-- Remotes (created on init)
local Remotes = nil
local DeathRemote = nil -- Server -> Client death events
local ReviveRemote = nil -- Client -> Server revival requests
local SpectateRemote = nil -- Client -> Server spectate requests

local REVIVAL_TIME = 3 -- seconds to hold E to revive
local REVIVAL_RANGE = 10 -- studs from body
local REVIVAL_STATS = { Health = 30, Temperature = 0, Hunger = 50, Stamina = 50 }
local DROP_RADIUS = 3
local DROP_HORIZONTAL_SPEED_MIN = 10
local DROP_HORIZONTAL_SPEED_MAX = 24
local DROP_VERTICAL_SPEED_MIN = 10
local DROP_VERTICAL_SPEED_MAX = 20

function DeathService:Init()
	if self._initialized then return end
	self._initialized = true
	dprint("[DeathService] Init() called - starting...")
	
	Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not Remotes then
		Remotes = Instance.new("Folder")
		Remotes.Name = "Remotes"
		Remotes.Parent = ReplicatedStorage
	end
	
	dprint("[DeathService] Remotes folder found/created")
	
	-- Create remotes
	DeathRemote = Remotes:FindFirstChild("Death") or Instance.new("RemoteEvent")
	DeathRemote.Name = "Death"
	DeathRemote.Parent = Remotes
	
	ReviveRemote = Remotes:FindFirstChild("Revive") or Instance.new("RemoteEvent")
	ReviveRemote.Name = "Revive"
	ReviveRemote.Parent = Remotes
	
	SpectateRemote = Remotes:FindFirstChild("Spectate") or Instance.new("RemoteEvent")
	SpectateRemote.Name = "Spectate"
	SpectateRemote.Parent = Remotes
	
	-- Handle revival requests
	ReviveRemote.OnServerEvent:Connect(function(player, action, targetPlayer)
		if action == "StartRevive" then
			self:_startRevive(player, targetPlayer)
		elseif action == "CancelRevive" then
			self:_cancelRevive(player)
		elseif action == "ReturnToLobby" then
			self:_returnToLobby(player)
		end
	end)
	
	-- Handle spectate requests
	SpectateRemote.OnServerEvent:Connect(function(player, action, targetPlayer)
		if action == "StartSpectate" then
			self:_startSpectate(player, targetPlayer)
		elseif action == "NextTarget" then
			self:_cycleSpectate(player, 1)
		elseif action == "PrevTarget" then
			self:_cycleSpectate(player, -1)
		elseif action == "StopSpectate" then
			self:_stopSpectate(player)
		end
	end)
	
	-- Clean up on player leave
	Players.PlayerRemoving:Connect(function(player)
		self:_cleanupPlayer(player)
	end)
	
	-- Hook into Humanoid.Died for all players (catches all death sources)
	Players.PlayerAdded:Connect(function(plr)
		dprint("[DeathService] PlayerAdded:", plr.Name)
		plr.CharacterAdded:Connect(function(char)
			-- If player is marked dead, destroy the character (prevent respawn)
			if plr:GetAttribute("IsDead") then
				dprint("[DeathService] Player is dead, preventing respawn")
				task.defer(function()
					if char and char.Parent then
						char:Destroy()
					end
				end)
				return
			end
			
			dprint("[DeathService] CharacterAdded for", plr.Name)
			local humanoid = char:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.BreakJointsOnDeath = false
				dprint("[DeathService] Hooking Humanoid.HealthChanged for", plr.Name)
				-- Use HealthChanged instead of Died so we can clone before cleanup
				humanoid.HealthChanged:Connect(function(health)
					if health <= 0 and not self:IsDead(plr) then
						dprint("[DeathService] Health hit 0 for", plr.Name)
						self:KillPlayer(plr)
					end
				end)
			end
		end)
	end)
	
	-- Handle existing players (for late initialization)
	for _, plr in ipairs(Players:GetPlayers()) do
		dprint("[DeathService] Handling existing player:", plr.Name)
		local char = plr.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.BreakJointsOnDeath = false
				dprint("[DeathService] Hooking existing Humanoid.HealthChanged for", plr.Name)
				humanoid.HealthChanged:Connect(function(health)
					if health <= 0 and not self:IsDead(plr) then
						dprint("[DeathService] Health hit 0 for", plr.Name)
						self:KillPlayer(plr)
					end
				end)
			end
		end
		plr.CharacterAdded:Connect(function(char)
			-- If player is marked dead, destroy the character (prevent respawn)
			if plr:GetAttribute("IsDead") then
				dprint("[DeathService] Player is dead, preventing respawn")
				task.defer(function()
					if char and char.Parent then
						char:Destroy()
					end
				end)
				return
			end
			
			dprint("[DeathService] CharacterAdded (existing player) for", plr.Name)
			local hum = char:WaitForChild("Humanoid", 5)
			if hum then
				hum.BreakJointsOnDeath = false
				dprint("[DeathService] Hooking Humanoid.HealthChanged for", plr.Name)
				hum.HealthChanged:Connect(function(health)
					if health <= 0 and not self:IsDead(plr) then
						dprint("[DeathService] Health hit 0 for", plr.Name)
						self:KillPlayer(plr)
					end
				end)
			end
		end)
	end
	
	local function trackPlayer(player)
		self._runStats[player.UserId] = self._runStats[player.UserId] or {
			Name = player.Name, DisplayName = player.DisplayName, Deaths = 0, Revives = 0,
		}
	end
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
	RunService.Heartbeat:Connect(function()
		for reviver, hold in pairs(self._reviveHolds) do
			if os.clock() - hold.StartedAt > REVIVAL_TIME + 2 or not self:_canRevive(hold.Target, reviver) then
				self._reviveHolds[reviver] = nil
			end
		end
	end)
	GameStateService:OnStateChanged(function(state)
		if state.MatchState ~= "GameOver" then return end
		self._reviveHolds = {}
		for _, data in pairs(self._deadPlayers) do
			local prompt = data.ragdoll and data.ragdoll:FindFirstChild("RevivePrompt", true)
			if prompt then prompt.Enabled = false end
		end
		local results = { Elapsed = state.FinalElapsed or state.Elapsed or 0, Players = {} }
		for userId, stats in pairs(self._runStats) do
			table.insert(results.Players, { UserId = userId, Name = stats.Name, DisplayName = stats.DisplayName, Deaths = stats.Deaths, Revives = stats.Revives })
		end
		table.sort(results.Players, function(a, b) return a.Name < b.Name end)
		self._results = results
		DeathRemote:FireAllClients("TeamResults", results)
	end)
	DeathRemote.OnServerEvent:Connect(function(player, action)
		if action ~= "RequestState" then return end
		if self._results then DeathRemote:FireClient(player, "TeamResults", self._results) end
		local data = self._deadPlayers[player]
		if data then
			DeathRemote:FireClient(player, "Died", {
				canSpectate = #self:_getAlivePlayers(player) > 0,
				ragdoll = data.ragdoll, ragdollPosition = self:GetDeathPosition(player), DeathId = data.DeathId,
			})
		end
	end)
	dprint("[DeathService] Initialized")
end

function DeathService:IsDead(player)
	return self._deadPlayers[player] ~= nil
end

function DeathService:GetRagdoll(player)
	local data = self._deadPlayers[player]
	return data and data.ragdoll or nil
end

function DeathService:GetDeathPosition(player)
	local data = self._deadPlayers[player]
	if not data then return nil end
	local body = data.ragdoll
	return body and body.Parent and body:GetPivot().Position or data.deathPosition
end

function DeathService:_focusCorpse(player)
	local data = self._deadPlayers[player]
	local body = data and data.ragdoll
	if not body then return end
	body:SetAttribute("OriginalUserId", player.UserId)
	body:SetAttribute("DeathId", data.DeathId)
	player.ReplicationFocus = body.PrimaryPart or body:FindFirstChild("HumanoidRootPart") or body:FindFirstChildWhichIsA("BasePart")
end

function DeathService:_dropPlayerInventory(player, deathPosition)
	local drops = InventoryService:DrainAll(player)
	if #drops == 0 then
		return
	end
	local rng = Random.new()
	for _, entry in ipairs(drops) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0, DROP_RADIUS)
		local spawnPos = deathPosition + Vector3.new(
			math.cos(angle) * radius,
			2 + rng:NextNumber(0, 1.5),
			math.sin(angle) * radius
		)
		local speed = rng:NextNumber(DROP_HORIZONTAL_SPEED_MIN, DROP_HORIZONTAL_SPEED_MAX)
		local velocity = Vector3.new(
			math.cos(angle) * speed,
			rng:NextNumber(DROP_VERTICAL_SPEED_MIN, DROP_VERTICAL_SPEED_MAX),
			math.sin(angle) * speed
		)
		ItemDropService:SpawnDrop(entry.Id, entry.N, spawnPos, {
			InitialVelocity = velocity,
		})
	end
end

function DeathService:KillPlayer(player)
	if ReplicatedStorage:GetAttribute("WorldRestoring") or player:GetAttribute("WorldPlayerRestoring") then return end
	dprint("[DeathService] KillPlayer called for", player.Name)
	
	if self:IsDead(player) then 
		dprint("[DeathService] Player already dead, skipping")
		return 
	end
	
	local character = player.Character
	if not character then 
		dprint("[DeathService] No character found")
		return 
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then 
		dprint("[DeathService] No humanoid found")
		return 
	end
	
	dprint("[DeathService] Creating ragdoll...")
	
	-- Get position before anything changes
	local deathPosition = character:GetPivot().Position
	
	-- Create ragdoll FIRST before character state changes
	local ragdoll = self:_createRagdoll(character)
	dprint("[DeathService] Ragdoll created:", ragdoll ~= nil)
	
	-- Store death data
	self._deadPlayers[player] = {
		DeathId = HttpService:GenerateGUID(false),
		ragdoll = ragdoll,
		deathTime = os.clock(),
		deathPosition = deathPosition,
	}
	self:_focusCorpse(player)

	player:SetAttribute("IsDead", true)
	self._reviveHolds[player] = nil
	local runStats = self._runStats[player.UserId]
	if runStats then runStats.Deaths += 1 end

	-- Drop all carried inventory stacks with random toss directions.
	self:_dropPlayerInventory(player, deathPosition)
	
	-- Mark player as dead (prevents auto-respawn in CharacterAdded handler)
	player:SetAttribute("IsDead", true)
	
	-- Destroy original character to prevent Roblox auto-respawn issues
	if character then
		character:Destroy()
	end
	
	-- Check if other players exist for spectate option
	local otherPlayers = self:_getAlivePlayers(player)
	local canSpectate = #otherPlayers > 0
	
	dprint("[DeathService] Firing DeathRemote to client, canSpectate:", canSpectate)
	
	-- Notify client of death
	DeathRemote:FireClient(player, "Died", {
		canSpectate = canSpectate,
		ragdoll = ragdoll,
		ragdollPosition = ragdoll and ragdoll:GetPivot().Position or deathPosition,
		DeathId = self._deadPlayers[player].DeathId,
	})
	
	-- Notify other players about the death (for revival prompts)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not self:IsDead(other) then
			DeathRemote:FireClient(other, "PlayerDied", {
				player = player,
				ragdollPosition = ragdoll and ragdoll:GetPivot().Position or nil,
			})
		end
	end
	
	self:_refreshSpectators(player)
end

local function liveCharacter(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return nil end
	if player:GetAttribute("IsDead") then return nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root then return char, hum, root end
	return nil
end

function DeathService:_canRevive(player, reviver)
	local data = self._deadPlayers[player]
	if GameStateService:IsGameOver() or not data or data.Reviving or player == reviver then return false end
	if player.Parent ~= Players or not data.ragdoll or not data.ragdoll.Parent then return false end
	local char, _, root = liveCharacter(reviver)
	if not char then return false end
	if player.Team and reviver.Team and player.Team ~= reviver.Team then return false end
	local position = data.ragdoll:GetPivot().Position
	if (root.Position - position).Magnitude > REVIVAL_RANGE then return false end
	if not InventoryService:Has(reviver, REVIVE_ITEM, 1) then return false end
	-- Line-of-sight is handled by the prompt itself; avoid strict raycast rejects that can fail due to temporary blockers.
	return true
end

function DeathService:RevivePlayer(player, reviver)
	local hold = self._reviveHolds[reviver]
	if not hold or hold.Target ~= player or os.clock() - hold.StartedAt < REVIVAL_TIME - 0.1 then return false end
	if not self:_canRevive(player, reviver) then return false end
	self._reviveHolds[reviver] = nil
	local data = self._deadPlayers[player]
	-- Reserve the corpse and consume exactly one kit before yielding.
	data.Reviving = true
	if not InventoryService:Consume(reviver, REVIVE_ITEM, 1) then data.Reviving = nil return false end
	local position = data.ragdoll:GetPivot().Position
	player:SetAttribute("IsDead", false)
	-- Clear the old exposure before the new character can receive survival ticks.
	StatsService:SetBaseStats(player, REVIVAL_STATS)
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
		local char = player.Character
		local hum = char and char:WaitForChild("Humanoid", 5)
		if not hum then error("Revived character did not load") end
		StatsService:SetBaseStats(player, REVIVAL_STATS)
		char:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end)
	if not ok then
		data.Reviving = nil
		player:SetAttribute("IsDead", true)
		if player.Character then player.Character:Destroy() end
		local added = reviver.Parent == Players and InventoryService:Give(reviver, REVIVE_ITEM, 1) or 0
		if added == 0 then ItemDropService:SpawnDrop(REVIVE_ITEM, 1, position + Vector3.new(0, 2, 0)) end
		warn("[DeathService] Revival failed:", err)
		return false
	end
	player.ReplicationFocus = nil
	data.ragdoll:Destroy()
	self._deadPlayers[player] = nil
	self._spectating[player] = nil
	local stats = self._runStats[reviver.UserId]
	if stats then stats.Revives += 1 end
	local rewardsModule = script.Parent:FindFirstChild("ExpeditionRewardsService")
	if rewardsModule then
		local rewarded, rewardError = pcall(function() require(rewardsModule):OnRevive(reviver, player, data.DeathId) end)
		if not rewarded then warn("[DeathService] Revival reward failed:", rewardError) end
	end
	DeathRemote:FireClient(player, "Revived", { reviver = reviver.DisplayName })
	DeathRemote:FireAllClients("PlayerRevived", { player = player })
	return true
end
function DeathService:_createRagdoll(character)
	if not character then
		warn("[DeathService] Cannot create ragdoll - character nil")
		return nil
	end
	
	dprint("[DeathService] Attempting to clone character:", character.Name, "Parent:", character.Parent)
	
	-- Try to clone the character
	local success, result = pcall(function()
		-- Make sure character still has a parent before cloning
		if not character.Parent then
			error("Character has no parent")
		end
		local archivable = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = archivable
		return clone
	end)
	
	local ragdoll = nil
	if success and result then
		ragdoll = result
		dprint("[DeathService] Clone successful")
	else
		-- When pcall fails, 'result' contains the error message
		local errorMsg = success and "Clone returned nil" or tostring(result)
		warn("[DeathService] Failed to clone character for ragdoll:", errorMsg)
		-- Create a simple placeholder ragdoll
		ragdoll = self:_createSimpleRagdoll(character)
		if not ragdoll then
			return nil
		end
	end
	
	ragdoll.Name = character.Name .. "_Ragdoll"
	
	local humanoid = ragdoll:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	
	-- Make all parts non-collidable with players but still visible
	for _, part in ipairs(ragdoll:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestorOfClass("Accessory")
			part.Anchored = false
			
			-- Remove scripts and tools
		elseif part:IsA("Script") or part:IsA("LocalScript") or part:IsA("Tool") then
			part:Destroy()
		end
	end
	
	-- Create ball socket joints for ragdoll effect
	self:_setupRagdollJoints(ragdoll)
	
	-- Add revival proximity prompt
	local hrp = ragdoll:FindFirstChild("UpperTorso") or ragdoll:FindFirstChild("Torso") or ragdoll:FindFirstChild("HumanoidRootPart")
	if hrp then
		ragdoll.PrimaryPart = hrp
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive · 1 Revival Kit"
		prompt.ObjectText = character.Name
		prompt.HoldDuration = REVIVAL_TIME
		prompt.MaxActivationDistance = REVIVAL_RANGE
		prompt.RequiresLineOfSight = false
		prompt.Parent = hrp
		
		-- Store original player reference
		ragdoll:SetAttribute("OriginalPlayer", character.Name)
		
		prompt.PromptButtonHoldBegan:Connect(function(reviver)
			local originalPlayer = Players:FindFirstChild(ragdoll:GetAttribute("OriginalPlayer"))
			if originalPlayer then self:_startRevive(reviver, originalPlayer) end
		end)
		prompt.PromptButtonHoldEnded:Connect(function(reviver)
			local hold = self._reviveHolds[reviver]
			if not hold or hold.Target.Name ~= ragdoll:GetAttribute("OriginalPlayer") then return end
			if os.clock() - hold.StartedAt < REVIVAL_TIME - 0.1 then
				self._reviveHolds[reviver] = nil
			else
				task.delay(0.25, function()
					if self._reviveHolds[reviver] == hold then self._reviveHolds[reviver] = nil end
				end)
			end
		end)
		prompt.Triggered:Connect(function(playerWhoTriggered)
			-- Find the original player
			local originalPlayer = Players:FindFirstChild(ragdoll:GetAttribute("OriginalPlayer"))
			if originalPlayer and self:IsDead(originalPlayer) then
				self:RevivePlayer(originalPlayer, playerWhoTriggered)
			end
		end)
	end
	
	local corpseHumanoid = ragdoll:FindFirstChildOfClass("Humanoid")
	if corpseHumanoid then corpseHumanoid:Destroy() end
	ragdoll.Parent = workspace
	for _, part in ipairs(ragdoll:GetDescendants()) do
		if part:IsA("BasePart") then part:SetNetworkOwner(nil) end
	end
	
	-- Apply small downward force to make it fall
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
	end
	
	return ragdoll
end

function DeathService:_setupRagdollJoints(ragdoll)
	local humanoid = ragdoll:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	-- Find all Motor6D joints and convert to BallSocketConstraints
	for _, motor in ipairs(ragdoll:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local attachment0 = Instance.new("Attachment")
			attachment0.CFrame = motor.C0
			attachment0.Parent = motor.Part0
			
			local attachment1 = Instance.new("Attachment")
			attachment1.CFrame = motor.C1
			attachment1.Parent = motor.Part1
			
			local constraint = Instance.new("BallSocketConstraint")
			constraint.Attachment0 = attachment0
			constraint.Attachment1 = attachment1
			constraint.LimitsEnabled = true
			constraint.TwistLimitsEnabled = true
			constraint.UpperAngle = 45
			constraint.TwistLowerAngle = -45
			constraint.TwistUpperAngle = 45
			constraint.Parent = motor.Part0
			
			local noCollision = Instance.new("NoCollisionConstraint")
			noCollision.Part0, noCollision.Part1 = motor.Part0, motor.Part1
			noCollision.Parent = motor.Part0
			motor.Enabled = false
		end
	end
end

-- Fallback: create a simple body-shaped ragdoll if clone fails
function DeathService:_createSimpleRagdoll(character)
	local ragdoll = Instance.new("Model")
	
	-- Get position from original character
	local position = Vector3.new(0, 5, 0)
	local lookVector = Vector3.new(0, 0, -1)
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			position = hrp.Position
			lookVector = hrp.CFrame.LookVector
		else
			local pivot = character:GetPivot()
			position = pivot.Position
		end
		
		-- Try to copy body parts manually (more reliable than full Clone)
		local partsToCopy = {"Head", "Torso", "UpperTorso", "LowerTorso", 
			"LeftArm", "RightArm", "LeftLeg", "RightLeg",
			"LeftUpperArm", "LeftLowerArm", "LeftHand",
			"RightUpperArm", "RightLowerArm", "RightHand",
			"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
			"RightUpperLeg", "RightLowerLeg", "RightFoot"}
		
		local copiedParts = {}
		for _, partName in ipairs(partsToCopy) do
			local part = character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				local success, clone = pcall(function() return part:Clone() end)
				if success and clone then
					clone.Anchored = false
					clone.CanCollide = true
					clone.Parent = ragdoll
					copiedParts[partName] = clone
				end
			end
		end
		
		-- If we copied parts, use those
		if copiedParts["Head"] or copiedParts["Torso"] or copiedParts["UpperTorso"] then
			-- Create HumanoidRootPart if we don't have one
			local rootPart = copiedParts["Torso"] or copiedParts["UpperTorso"] or copiedParts["LowerTorso"]
			if rootPart and not copiedParts["HumanoidRootPart"] then
				local hrpClone = Instance.new("Part")
				hrpClone.Name = "HumanoidRootPart"
				hrpClone.Size = Vector3.new(2, 2, 1)
				hrpClone.CFrame = rootPart.CFrame
				hrpClone.Transparency = 1
				hrpClone.CanCollide = false
				hrpClone.Anchored = false
				hrpClone.Parent = ragdoll
				
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrpClone
				weld.Part1 = rootPart
				weld.Parent = hrpClone
				
				ragdoll.PrimaryPart = hrpClone
			else
				ragdoll.PrimaryPart = rootPart
			end
			
			-- Weld all parts together loosely
			for name, part in pairs(copiedParts) do
				if part ~= ragdoll.PrimaryPart then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = ragdoll.PrimaryPart
					weld.Part1 = part
					weld.Parent = part
				end
			end
			
			dprint("[DeathService] Created ragdoll from copied parts")
			return ragdoll
		end
	end
	
	-- Ultimate fallback: create basic dummy
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = position
	torso.BrickColor = BrickColor.new("Medium stone grey")
	torso.Anchored = false
	torso.CanCollide = true
	torso.Parent = ragdoll
	
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Position = position + Vector3.new(0, 1.6, 0)
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Anchored = false
	head.CanCollide = true
	head.Parent = ragdoll
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = head
	weld.Parent = torso
	
	ragdoll.PrimaryPart = torso
	
	dprint("[DeathService] Created simple ragdoll at", position)
	return ragdoll
end

function DeathService:_getAlivePlayers(excludePlayer)
	local alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer and not self:IsDead(player) then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(alive, player)
			end
		end
	end
	return alive
end

function DeathService:_startSpectate(player, targetPlayer)
	if not self:IsDead(player) or GameStateService:IsGameOver() then return end
	if targetPlayer == player or not liveCharacter(targetPlayer) then
		targetPlayer = self:_getAlivePlayers(player)[1]
	end
	if targetPlayer then
		self._spectating[player] = targetPlayer
		SpectateRemote:FireClient(player, "SpectateTarget", targetPlayer)
	else
		self:_stopSpectate(player)
	end
end

function DeathService:_refreshSpectators(unavailable)
	for spectator, target in pairs(self._spectating) do
		if target == unavailable then self:_startSpectate(spectator) end
	end
end
function DeathService:_cycleSpectate(player, direction)
	if not self:IsDead(player) or GameStateService:IsGameOver() then return end
	
	local alive = self:_getAlivePlayers(player)
	if #alive == 0 then self:_stopSpectate(player) return end
	
	local current = self._spectating[player]
	local currentIndex = 1
	
	for i, p in ipairs(alive) do
		if p == current then
			currentIndex = i
			break
		end
	end
	
	local newIndex = ((currentIndex - 1 + direction) % #alive) + 1
	self._spectating[player] = alive[newIndex]
	SpectateRemote:FireClient(player, "SpectateTarget", alive[newIndex])
end

function DeathService:_stopSpectate(player)
	self._spectating[player] = nil
	SpectateRemote:FireClient(player, "StopSpectate")
end

function DeathService:_startRevive(player, targetPlayer)
	if not self:_canRevive(targetPlayer, player) then
		if liveCharacter(player) and not InventoryService:Has(player, REVIVE_ITEM, 1) then
			DeathRemote:FireClient(player, "ReviveNotice", "Craft a Revival Kit to revive your teammate.")
		end
		return
	end
	self._reviveHolds[player] = { Target = targetPlayer, StartedAt = os.clock() }
end

function DeathService:_cancelRevive(player)
	self._reviveHolds[player] = nil
end
function DeathService:_returnToLobby(player)
	if not RunService:IsStudio() then
		DeathRemote:FireClient(player, "LobbyDisabled")
		return
	end

	if not self:IsDead(player) then
		return
	end

	local data = self._deadPlayers[player]
	if data and data.Reviving then return end
	local respawnPosition = data and data.deathPosition or nil
	player.ReplicationFocus = nil
	if data and data.ragdoll then
		data.ragdoll:Destroy()
	end
	self._deadPlayers[player] = nil
	self._spectating[player] = nil
	
	-- Clear dead flag and respawn with no inventory.
	InventoryService:Clear(player)
	player:SetAttribute("IsDead", false)
	StatsService:SetBase(player, "Health", StatsService:GetStat(player, "MaxHealth") or 100)
	player:LoadCharacter()
	if respawnPosition then
		task.defer(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				hrp.CFrame = CFrame.new(respawnPosition + Vector3.new(0, 3, 0))
			end
		end)
	end
	
	-- Notify client
	DeathRemote:FireClient(player, "ReturnedToLobby")
end

function DeathService:_cleanupPlayer(player)
	self._reviveHolds[player] = nil
	player.ReplicationFocus = nil
	local data = self._deadPlayers[player]
	if data and data.ragdoll then
		data.ragdoll:Destroy()
	end
	self._deadPlayers[player] = nil
	self._spectating[player] = nil
	task.defer(function() self:_refreshSpectators(player) end)
end

function DeathService:CaptureWorldState(player)
	local data = self._deadPlayers[player]
	return {
		Downed = data ~= nil,
		DeathId = data and data.DeathId or nil,
		Transform = data and require(script.Parent.WorldSnapshotCodec).CFrame(data.ragdoll and data.ragdoll:GetPivot() or CFrame.new(data.deathPosition)) or nil,
		DownedFor = data and math.max(0, os.clock() - data.deathTime) or 0,
	}
end

function DeathService:CaptureRunState()
	local state = {}
	for userId, stats in pairs(self._runStats) do state[tostring(userId)] = table.clone(stats) end
	return state
end

function DeathService:RestoreRunState(state)
	local codec, restored = require(script.Parent.WorldSnapshotCodec), {}
	codec.BoundedCount(state, 100)
	for userId, stats in pairs(state) do
		local id = tonumber(userId)
		assert(id and id % 1 == 0, "Invalid run participant")
		restored[id] = { Name = codec.Text(stats.Name, 64), DisplayName = codec.Text(stats.DisplayName, 64), Deaths = codec.Number(stats.Deaths, 0, 1e8), Revives = codec.Number(stats.Revives, 0, 1e8) }
	end
	self._runStats = restored
end

function DeathService:RestoreWorldState(player, state)
	assert(self._initialized, "DeathService must initialize before player restore")
	self:_cleanupPlayer(player)
	player:SetAttribute("IsDead", state.Downed == true)
	if not state.Downed then return end
	local codec, character = require(script.Parent.WorldSnapshotCodec), player.Character
	assert(character, "A loaded character is required to reconstruct the downed body")
	local transform = codec.ReadCFrame(state.Transform)
	character:PivotTo(transform)
	local ragdoll = assert(self:_createRagdoll(character), "Unable to restore downed body")
	ragdoll:PivotTo(transform)
	self._deadPlayers[player] = { DeathId = codec.Text(state.DeathId, 80), ragdoll = ragdoll, deathTime = os.clock() - codec.Number(state.DownedFor, 0, 1e9), deathPosition = transform.Position }
	self:_focusCorpse(player)
	character:Destroy()
	DeathRemote:FireClient(player, "Died", { canSpectate = #self:_getAlivePlayers(player) > 0, ragdoll = ragdoll, ragdollPosition = transform.Position, DeathId = self._deadPlayers[player].DeathId })
	-- No KillPlayer call: inventory was already spilled and the death counted in the saved run.
end

return DeathService
