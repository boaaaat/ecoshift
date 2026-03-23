-- DeathClient.client.lua
-- Handles death UI, spectate camera, and revival feedback
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local DeathRemote = Remotes and Remotes:WaitForChild("Death", 5)
local SpectateRemote = Remotes and Remotes:WaitForChild("Spectate", 5)
local ReviveRemote = Remotes and Remotes:WaitForChild("Revive", 5)
local GameStateRemote = Remotes and Remotes:WaitForChild("GameStateUpdate", 5)

-- State
local isDead = false
local isGameOver = false
local isSpectating = false
local spectateTarget = nil
local spectateConnection = nil
local deathUI = nil
local canReturnToLobby = RunService:IsStudio()
local lastCanSpectate = false

-- Camera
local camera = workspace.CurrentCamera
local originalCameraType = nil
local originalCameraSubject = nil

-------------------------------------------------------------------
-- UI CREATION
-------------------------------------------------------------------
local function createDeathUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeathUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	
	-- Dark overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui
	
	-- Death message container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 400, 0, 300)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	container.BackgroundTransparency = 0.1
	container.BorderSizePixel = 0
	container.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 50, 50)
	stroke.Thickness = 2
	stroke.Parent = container
	
	-- "YOU DIED" text
	local deathText = Instance.new("TextLabel")
	deathText.Name = "DeathText"
	deathText.Size = UDim2.new(1, 0, 0, 60)
	deathText.Position = UDim2.new(0, 0, 0, 30)
	deathText.BackgroundTransparency = 1
	deathText.Text = "YOU DIED"
	deathText.TextColor3 = Color3.fromRGB(200, 60, 60)
	deathText.TextSize = 42
	deathText.Font = Enum.Font.GothamBold
	deathText.Parent = container
	
	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -40, 0, 40)
	subtitle.Position = UDim2.new(0, 20, 0, 90)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Wait for a teammate to revive you..."
	subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	subtitle.TextSize = 16
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextWrapped = true
	subtitle.Parent = container
	
	-- Buttons container
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, -40, 0, 120)
	buttonsFrame.Position = UDim2.new(0, 20, 0, 150)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = container
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = buttonsFrame
	
	-- Spectate button
	local spectateBtn = Instance.new("TextButton")
	spectateBtn.Name = "SpectateButton"
	spectateBtn.Size = UDim2.new(1, 0, 0, 50)
	spectateBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
	spectateBtn.BorderSizePixel = 0
	spectateBtn.Text = "👁 SPECTATE TEAMMATES"
	spectateBtn.TextColor3 = Color3.new(1, 1, 1)
	spectateBtn.TextSize = 18
	spectateBtn.Font = Enum.Font.GothamBold
	spectateBtn.AutoButtonColor = true
	spectateBtn.Parent = buttonsFrame
	
	local specCorner = Instance.new("UICorner")
	specCorner.CornerRadius = UDim.new(0, 8)
	specCorner.Parent = spectateBtn
	
	-- Return to lobby button
	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "LobbyButton"
	lobbyBtn.Size = UDim2.new(1, 0, 0, 50)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
	lobbyBtn.BorderSizePixel = 0
	lobbyBtn.Text = "🏠 RETURN TO LOBBY"
	lobbyBtn.TextColor3 = Color3.new(1, 1, 1)
	lobbyBtn.TextSize = 18
	lobbyBtn.Font = Enum.Font.GothamBold
	lobbyBtn.AutoButtonColor = true
	lobbyBtn.Visible = RunService:IsStudio()
	lobbyBtn.Parent = buttonsFrame
	
	local lobbyCorner = Instance.new("UICorner")
	lobbyCorner.CornerRadius = UDim.new(0, 8)
	lobbyCorner.Parent = lobbyBtn
	
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	
	return screenGui
end

local function createSpectateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpectateUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 99
	
	-- Top bar showing who you're spectating
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0, 300, 0, 50)
	topBar.Position = UDim2.new(0.5, 0, 0, 20)
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	topBar.BackgroundTransparency = 0.3
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui
	
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 8)
	topCorner.Parent = topBar
	
	local spectateLabel = Instance.new("TextLabel")
	spectateLabel.Name = "SpectateLabel"
	spectateLabel.Size = UDim2.new(1, 0, 0, 20)
	spectateLabel.Position = UDim2.new(0, 0, 0, 5)
	spectateLabel.BackgroundTransparency = 1
	spectateLabel.Text = "SPECTATING"
	spectateLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	spectateLabel.TextSize = 12
	spectateLabel.Font = Enum.Font.GothamBold
	spectateLabel.Parent = topBar
	
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Name = "TargetLabel"
	targetLabel.Size = UDim2.new(1, 0, 0, 25)
	targetLabel.Position = UDim2.new(0, 0, 0, 22)
	targetLabel.BackgroundTransparency = 1
	targetLabel.Text = "Player Name"
	targetLabel.TextColor3 = Color3.new(1, 1, 1)
	targetLabel.TextSize = 18
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.Parent = topBar
	
	-- Bottom controls hint
	local controlsBar = Instance.new("Frame")
	controlsBar.Name = "ControlsBar"
	controlsBar.Size = UDim2.new(0, 400, 0, 40)
	controlsBar.Position = UDim2.new(0.5, 0, 1, -60)
	controlsBar.AnchorPoint = Vector2.new(0.5, 0)
	controlsBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	controlsBar.BackgroundTransparency = 0.3
	controlsBar.BorderSizePixel = 0
	controlsBar.Parent = screenGui
	
	local ctrlCorner = Instance.new("UICorner")
	ctrlCorner.CornerRadius = UDim.new(0, 8)
	ctrlCorner.Parent = controlsBar
	
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "ControlsLabel"
	controlsLabel.Size = UDim2.new(1, 0, 1, 0)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "[Q] Previous   |   [E] Next   |   [X] Stop Spectating"
	controlsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	controlsLabel.TextSize = 14
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.Parent = controlsBar
	
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	
	return screenGui
end

local function updateDeathUI(canSpectate)
	lastCanSpectate = canSpectate == true
	local ui = playerGui:FindFirstChild("DeathUI")
	if not ui then return end
	local container = ui:FindFirstChild("Container")
	if not container then return end
	local deathText = container:FindFirstChild("DeathText")
	local subtitle = container:FindFirstChild("Subtitle")
	local buttons = container:FindFirstChild("Buttons")
	local spectateBtn = buttons and buttons:FindFirstChild("SpectateButton")
	local lobbyBtn = buttons and buttons:FindFirstChild("LobbyButton")

	if deathText then
		deathText.Text = isGameOver and "GAME OVER" or "YOU DIED"
	end

	if subtitle then
		if isGameOver then
			if canReturnToLobby then
				subtitle.Text = "The run ended in a full wipe. Return when ready."
			else
				subtitle.Text = "The run ended in a full wipe. Return is only available in Studio."
			end
		else
			subtitle.Text = "Wait for a teammate to revive you..."
		end
	end

	if spectateBtn then
		spectateBtn.Visible = (not isGameOver) and canSpectate == true
	end

	if lobbyBtn then
		if isGameOver then
			lobbyBtn.Visible = true
			lobbyBtn.Active = canReturnToLobby
			lobbyBtn.Selectable = canReturnToLobby
			lobbyBtn.AutoButtonColor = canReturnToLobby
			lobbyBtn.BackgroundColor3 = canReturnToLobby and Color3.fromRGB(80, 80, 85) or Color3.fromRGB(55, 55, 60)
			lobbyBtn.Text = canReturnToLobby and "RETURN TO LOBBY" or "RETURN UNAVAILABLE"
		else
			lobbyBtn.Visible = RunService:IsStudio()
			lobbyBtn.Active = RunService:IsStudio()
			lobbyBtn.Selectable = RunService:IsStudio()
			lobbyBtn.AutoButtonColor = RunService:IsStudio()
			lobbyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
			lobbyBtn.Text = "RETURN TO LOBBY"
		end
	end
end

local function showOverlayUI(canSpectate)
	if not playerGui:FindFirstChild("DeathUI") then
		createDeathUI()
	end
	if not playerGui:FindFirstChild("SpectateUI") then
		createSpectateUI()
	end

	local ui = playerGui:FindFirstChild("DeathUI")
	if ui then
		updateDeathUI(canSpectate)
		ui.Enabled = true

		local overlay = ui:FindFirstChild("Overlay")
		local container = ui:FindFirstChild("Container")
		if overlay then
			overlay.BackgroundTransparency = 1
			TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.4}):Play()
		end
		if container then
			container.Position = UDim2.new(0.5, 0, 0.6, 0)
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		end
	end
end

-------------------------------------------------------------------
-- SPECTATE CAMERA
-------------------------------------------------------------------
local function startSpectateCamera(target)
	if not target then return end
	
	spectateTarget = target
	isSpectating = true
	
	-- Store original camera settings
	originalCameraType = camera.CameraType
	originalCameraSubject = camera.CameraSubject
	
	-- Set camera to follow target
	local targetChar = target.Character
	if targetChar then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = targetChar:FindFirstChildOfClass("Humanoid") or targetChar
	end
	
	-- Update spectate UI
	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		spectateUI.Enabled = true
		local targetLabel = spectateUI:FindFirstChild("TopBar") and spectateUI.TopBar:FindFirstChild("TargetLabel")
		if targetLabel then
			targetLabel.Text = target.Name
		end
	end
	
	-- Hide death UI while spectating
	local deathUIRef = playerGui:FindFirstChild("DeathUI")
	if deathUIRef then
		deathUIRef.Enabled = false
	end
	
	-- Update camera if target character changes
	spectateConnection = target.CharacterAdded:Connect(function(newChar)
		if isSpectating and spectateTarget == target then
			camera.CameraSubject = newChar:FindFirstChildOfClass("Humanoid") or newChar
		end
	end)
end

local function stopSpectateCamera()
	isSpectating = false
	spectateTarget = nil
	
	if spectateConnection then
		spectateConnection:Disconnect()
		spectateConnection = nil
	end
	
	-- Restore camera
	if originalCameraType then
		camera.CameraType = originalCameraType
	end
	if originalCameraSubject then
		camera.CameraSubject = originalCameraSubject
	end
	
	-- Hide spectate UI
	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		spectateUI.Enabled = false
	end
	
	-- Show death UI if still dead
	if isDead then
		local deathUIRef = playerGui:FindFirstChild("DeathUI")
		if deathUIRef then
			deathUIRef.Enabled = true
		end
	end
end

local function updateSpectateTarget(target)
	if not isSpectating then return end
	
	spectateTarget = target
	
	if target and target.Character then
		camera.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid") or target.Character
	end
	
	-- Update UI
	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		local targetLabel = spectateUI:FindFirstChild("TopBar") and spectateUI.TopBar:FindFirstChild("TargetLabel")
		if targetLabel then
			targetLabel.Text = target and target.Name or "No target"
		end
	end
end

-------------------------------------------------------------------
-- DEATH HANDLING
-------------------------------------------------------------------
local function showDeathUI(canSpectate)
	isDead = true
	showOverlayUI(canSpectate)
end

local function showGameOverUI()
	if isSpectating then
		stopSpectateCamera()
	end
	showOverlayUI(false)
end

local function hideDeathUI()
	isDead = false
	stopSpectateCamera()
	if isGameOver then
		showGameOverUI()
		return
	end
	
	local ui = playerGui:FindFirstChild("DeathUI")
	if ui then
		ui.Enabled = false
	end
	
	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		spectateUI.Enabled = false
	end
end

local function onGameStateRemote(state)
	if type(state) ~= "table" then
		return
	end
	canReturnToLobby = state.CanReturnToLobby == true
	local wasGameOver = isGameOver
	isGameOver = state.MatchState == "GameOver"
	if isGameOver then
		showGameOverUI()
	elseif wasGameOver then
		updateDeathUI(lastCanSpectate)
		if not isDead then
			local ui = playerGui:FindFirstChild("DeathUI")
			if ui then
				ui.Enabled = false
			end
		end
	end
end

-------------------------------------------------------------------
-- INPUT HANDLING
-------------------------------------------------------------------
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	
	if isSpectating then
		if input.KeyCode == Enum.KeyCode.Q then
			-- Previous target
			if SpectateRemote then
				SpectateRemote:FireServer("PrevTarget")
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			-- Next target
			if SpectateRemote then
				SpectateRemote:FireServer("NextTarget")
			end
		elseif input.KeyCode == Enum.KeyCode.X then
			-- Stop spectating
			if SpectateRemote then
				SpectateRemote:FireServer("StopSpectate")
			end
			stopSpectateCamera()
		end
	end
end

-------------------------------------------------------------------
-- REMOTE HANDLERS
-------------------------------------------------------------------
local function onDeathRemote(action, data)
	print("[DeathClient] Received DeathRemote:", action, data)
	
	if action == "Died" then
		print("[DeathClient] Showing death UI")
		showDeathUI(data.canSpectate)
	elseif action == "Revived" then
		print("[DeathClient] Revived - resetting camera")
		-- Stop spectating first
		isSpectating = false
		spectateTarget = nil
		if spectateConnection then
			spectateConnection:Disconnect()
			spectateConnection = nil
		end
		
		-- Hide UIs
		hideDeathUI()
		local spectateUI = playerGui:FindFirstChild("SpectateUI")
		if spectateUI then
			spectateUI.Enabled = false
		end
		
		-- Reset camera to follow our new character
		task.defer(function()
			-- Wait for character to exist
			local char = player.Character or player.CharacterAdded:Wait()
			local humanoid = char:WaitForChild("Humanoid", 5)
			
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid or char
			
			-- Update stored originals to new character
			originalCameraType = Enum.CameraType.Custom
			originalCameraSubject = humanoid or char
			
			print("[DeathClient] Camera reset to new character")
		end)
		
	elseif action == "ReturnedToLobby" then
		print("[DeathClient] Returned to lobby - resetting camera")
		-- Stop spectating
		isSpectating = false
		spectateTarget = nil
		if spectateConnection then
			spectateConnection:Disconnect()
			spectateConnection = nil
		end
		
		hideDeathUI()
		local spectateUI = playerGui:FindFirstChild("SpectateUI")
		if spectateUI then
			spectateUI.Enabled = false
		end
		
		-- Reset camera to follow our new character
		task.defer(function()
			local char = player.Character or player.CharacterAdded:Wait()
			local humanoid = char:WaitForChild("Humanoid", 5)
			
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid or char
			
			originalCameraType = Enum.CameraType.Custom
			originalCameraSubject = humanoid or char
		end)
	elseif action == "LobbyDisabled" then
		local ui = playerGui:FindFirstChild("DeathUI")
		local subtitle = ui and ui:FindFirstChild("Container")
			and ui.Container:FindFirstChild("Subtitle")
		if subtitle then
			subtitle.Text = "Return to lobby is only available in Studio."
		end
		
	elseif action == "PlayerDied" then
		-- Another player died - could show notification
	elseif action == "PlayerRevived" then
		-- Another player was revived
	end
end

local function onSpectateRemote(action, data)
	if action == "SpectateTarget" then
		if data and typeof(data) == "Instance" and data:IsA("Player") then
			startSpectateCamera(data)
		end
	elseif action == "StopSpectate" then
		stopSpectateCamera()
	end
end

-------------------------------------------------------------------
-- UI BUTTON HANDLERS
-------------------------------------------------------------------
local function setupButtonHandlers()
	local ui = playerGui:WaitForChild("DeathUI", 10)
	if not ui then return end
	
	local container = ui:WaitForChild("Container", 5)
	if not container then return end
	
	local buttons = container:WaitForChild("Buttons", 5)
	if not buttons then return end
	
	local spectateBtn = buttons:FindFirstChild("SpectateButton")
	local lobbyBtn = buttons:FindFirstChild("LobbyButton")
	
	if spectateBtn then
		spectateBtn.MouseButton1Click:Connect(function()
			if SpectateRemote then
				SpectateRemote:FireServer("StartSpectate")
			end
		end)
	end
	
	if lobbyBtn then
		lobbyBtn.MouseButton1Click:Connect(function()
			if ReviveRemote then
				ReviveRemote:FireServer("ReturnToLobby")
			end
		end)
	end
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------
local function init()
	print("[DeathClient] Starting initialization...")
	
	-- Create UIs
	createDeathUI()
	createSpectateUI()
	print("[DeathClient] UIs created")
	
	-- Setup button handlers
	setupButtonHandlers()
	print("[DeathClient] Button handlers set up")
	
	-- Connect remotes
	if DeathRemote then
		print("[DeathClient] DeathRemote found, connecting...")
		DeathRemote.OnClientEvent:Connect(onDeathRemote)
	else
		warn("[DeathClient] DeathRemote NOT FOUND!")
	end

	if GameStateRemote then
		GameStateRemote.OnClientEvent:Connect(onGameStateRemote)
	end
	
	if SpectateRemote then
		SpectateRemote.OnClientEvent:Connect(onSpectateRemote)
	else
		warn("[DeathClient] SpectateRemote NOT FOUND!")
	end
	
	-- Connect input
	UserInputService.InputBegan:Connect(onInputBegan)
	
	print("[DeathClient] Initialized successfully")
end

init()
