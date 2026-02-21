-- DeathService.lua
-- Handles player death, ragdoll, revival, and spectate coordination
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DEBUG = false

local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local DeathService = {}
DeathService._deadPlayers = {} -- [player] = { ragdoll: Model, deathTime: number }
DeathService._spectating = {} -- [player] = targetPlayer

-- Remotes (created on init)
local Remotes = nil
local DeathRemote = nil -- Server -> Client death events
local ReviveRemote = nil -- Client -> Server revival requests
local SpectateRemote = nil -- Client -> Server spectate requests

local REVIVAL_TIME = 3 -- seconds to hold E to revive
local REVIVAL_RANGE = 8 -- studs from body
local REVIVAL_HP_PERCENT = 0.25 -- revive with 25% HP

function DeathService:Init()
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
	
	dprint("[DeathService] Initialized")
end

function DeathService:IsDead(player)
	return self._deadPlayers[player] ~= nil
end

function DeathService:GetRagdoll(player)
	local data = self._deadPlayers[player]
	return data and data.ragdoll or nil
end

function DeathService:KillPlayer(player)
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
		ragdoll = ragdoll,
		deathTime = os.clock(),
		deathPosition = deathPosition,
	}
	
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
		ragdollPosition = ragdoll and ragdoll:GetPivot().Position or deathPosition,
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
	
	dprint("[DeathService]", player.Name, "died successfully")
end

function DeathService:RevivePlayer(player, reviver)
	if not self:IsDead(player) then return false end
	
	local data = self._deadPlayers[player]
	local ragdoll = data and data.ragdoll
	
	-- Get revival position from ragdoll
	local revivePosition = ragdoll and ragdoll:GetPivot().Position or data.deathPosition
	
	-- Clean up ragdoll
	if ragdoll then
		ragdoll:Destroy()
	end
	
	-- Clear death state
	self._deadPlayers[player] = nil
	self._spectating[player] = nil
	
	-- Clear dead flag and respawn
	player:SetAttribute("IsDead", false)
	player:LoadCharacter()
	
	-- Wait for character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 5)
	
	if humanoid then
		-- Set to low HP
		local maxHP = humanoid.MaxHealth
		humanoid.Health = maxHP * REVIVAL_HP_PERCENT
		
		-- Move to revival position
		task.wait(0.1) -- small delay for character to fully load
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(revivePosition + Vector3.new(0, 3, 0))
		end
	end
	
	-- Notify client of revival
	DeathRemote:FireClient(player, "Revived", {
		reviver = reviver and reviver.Name or "Unknown",
	})
	
	-- Notify other clients
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			DeathRemote:FireClient(other, "PlayerRevived", {
				player = player,
			})
		end
	end
	
	dprint("[DeathService]", player.Name, "was revived by", reviver and reviver.Name or "system")
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
		return character:Clone()
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
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	
	-- Make all parts non-collidable with players but still visible
	for _, part in ipairs(ragdoll:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
			part.Anchored = false
			
			-- Remove scripts and tools
		elseif part:IsA("Script") or part:IsA("LocalScript") or part:IsA("Tool") then
			part:Destroy()
		end
	end
	
	-- Create ball socket joints for ragdoll effect
	self:_setupRagdollJoints(ragdoll)
	
	-- Add revival proximity prompt
	local hrp = ragdoll:FindFirstChild("HumanoidRootPart")
	if hrp then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = character.Name
		prompt.HoldDuration = REVIVAL_TIME
		prompt.MaxActivationDistance = REVIVAL_RANGE
		prompt.RequiresLineOfSight = true
		prompt.Parent = hrp
		
		-- Store original player reference
		ragdoll:SetAttribute("OriginalPlayer", character.Name)
		
		prompt.Triggered:Connect(function(playerWhoTriggered)
			-- Find the original player
			local originalPlayer = Players:FindFirstChild(ragdoll:GetAttribute("OriginalPlayer"))
			if originalPlayer and self:IsDead(originalPlayer) then
				self:RevivePlayer(originalPlayer, playerWhoTriggered)
			end
		end)
	end
	
	ragdoll.Parent = workspace
	
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
	if not self:IsDead(player) then return end
	
	-- Validate target
	if targetPlayer and not self:IsDead(targetPlayer) then
		self._spectating[player] = targetPlayer
		SpectateRemote:FireClient(player, "SpectateTarget", targetPlayer)
	else
		-- Auto-select first alive player
		local alive = self:_getAlivePlayers(player)
		if #alive > 0 then
			self._spectating[player] = alive[1]
			SpectateRemote:FireClient(player, "SpectateTarget", alive[1])
		end
	end
end

function DeathService:_cycleSpectate(player, direction)
	if not self:IsDead(player) then return end
	
	local alive = self:_getAlivePlayers(player)
	if #alive == 0 then return end
	
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
	-- Handled by ProximityPrompt on ragdoll
end

function DeathService:_cancelRevive(player)
	-- Handled by ProximityPrompt
end

function DeathService:_returnToLobby(player)
	-- Teleport player to lobby or reset
	-- For now, just respawn at normal spawn
	if self:IsDead(player) then
		local data = self._deadPlayers[player]
		if data and data.ragdoll then
			data.ragdoll:Destroy()
		end
		self._deadPlayers[player] = nil
		self._spectating[player] = nil
	end
	
	-- Clear dead flag and respawn
	player:SetAttribute("IsDead", false)
	player:LoadCharacter()
	
	-- Notify client
	DeathRemote:FireClient(player, "ReturnedToLobby")
end

function DeathService:_cleanupPlayer(player)
	local data = self._deadPlayers[player]
	if data and data.ragdoll then
		data.ragdoll:Destroy()
	end
	self._deadPlayers[player] = nil
	self._spectating[player] = nil
end

return DeathService
