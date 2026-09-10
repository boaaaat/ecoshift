if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- DeathClient.client.lua
-- Handles death UI, spectate camera, and revival feedback
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("UITheme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local DeathRemote = Remotes and Remotes:WaitForChild("Death", 5)
local SpectateRemote = Remotes and Remotes:WaitForChild("Spectate", 5)
local ReviveRemote = Remotes and Remotes:WaitForChild("Revive", 5)
local GameStateRemote = Remotes and Remotes:WaitForChild("GameStateUpdate", 5)
local RewardsRemote = Remotes and Remotes:WaitForChild("ExpeditionRewards", 10)
local LobbyRemote = Remotes and Remotes:WaitForChild("Lobby", 10)

-- State
local isDead = false
local isGameOver = false
local isSpectating = false
local spectateTarget = nil
local spectateConnection = nil
local deathUI = nil
local canReturnToLobby = RunService:IsStudio()
local lastCanSpectate = false
local teamResults = nil
local rewardSummaries = {}
local currencyName = "Field Marks"
local returnRequest, returnAccepted, returnMessage = nil, false, ""
local corpse = nil
local corpsePosition = nil
local corpseDeathId = nil
local corpseRecovery = nil
local stopSpectateCamera
local updateDeathUI

-- Camera
local camera = workspace.CurrentCamera
local originalCameraType = nil
local originalCameraSubject = nil

local function followCorpse()
	if not isDead or isSpectating then return true end
	camera = workspace.CurrentCamera
	if not corpse or not corpse:IsDescendantOf(workspace) then
		local candidate = workspace:FindFirstChild(player.Name .. "_Ragdoll")
		if candidate and candidate:IsA("Model") and (not corpseDeathId or candidate:GetAttribute("DeathId") == corpseDeathId) then
			corpse = candidate
		end
	end
	local root = corpse and corpse:IsDescendantOf(workspace) and (corpse.PrimaryPart or corpse:FindFirstChild("HumanoidRootPart") or corpse:FindFirstChildWhichIsA("BasePart"))
	if camera and root then
		corpsePosition = root.Position
		if camera.CameraSubject ~= root then
			camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 7, 12), root.Position)
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = root
		return true
	elseif camera and corpsePosition then
		-- Instance references may arrive after the remote; keep a useful view meanwhile.
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(corpsePosition + Vector3.new(0, 7, 12), corpsePosition)
		camera.Focus = CFrame.new(corpsePosition)
	end
	return false
end

local function recoverCorpseCamera()
	if not isDead or isSpectating or corpseRecovery then return end
	local ticket = {}
	corpseRecovery = ticket
	task.spawn(function()
		for attempt = 1, 80 do
			if corpseRecovery ~= ticket or not isDead or isSpectating then break end
			if followCorpse() then break end
			if DeathRemote and (attempt == 8 or attempt == 24 or attempt == 48) then
				DeathRemote:FireServer("RequestState")
			end
			task.wait(0.25)
		end
		if corpseRecovery == ticket then corpseRecovery = nil end
	end)
end

local function clearCorpseCamera()
	corpse, corpsePosition, corpseDeathId, corpseRecovery = nil, nil, nil, nil
end

local function showReviveNotice(message)
	local gui = playerGui:FindFirstChild("ReviveNotice") or Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ReviveNotice", false, 110
	gui.Parent = playerGui
	local old = gui:FindFirstChild("Notice")
	if old then old:Destroy() end
	local panel = Instance.new("Frame")
	panel.Name = "Notice"
	panel.Size = UDim2.fromOffset(380, 60)
	panel.Position = UDim2.new(0.5, 0, 0.18, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Parent = gui
	local label = Theme.Label(panel, message, UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 15, Theme.Colors.Paper)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = true
	Theme.Panel(panel, true)
	Theme.Fit(panel, 380, 60)
	task.delay(3, function() if panel.Parent then panel:Destroy() end end)
end

-------------------------------------------------------------------
-- UI CREATION
-------------------------------------------------------------------
local function mobileDeathLayout(container)
	if not Theme.IsMobile() then return end
	local title, subtitle = container:FindFirstChild("DeathText"), container:FindFirstChild("Subtitle")
	if title then title.Position=UDim2.fromOffset(20,20); title.Size=UDim2.new(1,-40,0,64); title.TextSize=24; title.TextWrapped=true end
	if subtitle then subtitle.Position=UDim2.fromOffset(20,88); subtitle.Size=UDim2.new(1,-40,0,54); subtitle.TextSize=17 end
	local rewards=container:FindFirstChild("RunRewards")
	if rewards then
		rewards.Size=UDim2.new(1,-40,0,106); rewards.Position=UDim2.fromOffset(20,154)
		rewards.RewardTitle.TextSize=14; rewards.RewardTitle.Size=UDim2.new(1,-24,0,20)
		rewards.RewardValue.Position=UDim2.fromOffset(12,32); rewards.RewardValue.TextSize=18; rewards.RewardValue.TextWrapped=true
		rewards.RewardStatus.Position=UDim2.fromOffset(12,62); rewards.RewardStatus.Size=UDim2.new(1,-24,0,38); rewards.RewardStatus.TextSize=14
	end
	local results=container:FindFirstChild("TeamResults")
	if results then results.Position=UDim2.fromOffset(20,274); results.Size=UDim2.new(1,-40,0,204); results.ScrollBarThickness=6 end
	local buttons=container:FindFirstChild("Buttons")
	if buttons then buttons.Position=UDim2.fromOffset(20,isGameOver and 492 or 166) end
	local travel=container:FindFirstChild("TravelStatus")
	if travel then travel.Position=UDim2.fromOffset(20,550); travel.Size=UDim2.new(1,-40,0,44); travel.TextSize=14 end
end

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
	Theme.CaptureCursor(container); Theme.Panel(container, true)

	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = container
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Moss
	stroke.Thickness = 2
	stroke.Parent = container
	
	-- "YOU DIED" text
	local deathText = Instance.new("TextLabel")
	deathText.Name = "DeathText"
	deathText.Size = UDim2.new(1, 0, 0, 60)
	deathText.Position = UDim2.new(0, 0, 0, 30)
	deathText.BackgroundTransparency = 1
	deathText.Text = "EXPEDITION INTERRUPTED"
	deathText.TextColor3 = Theme.Colors.Amber
	deathText.TextSize = 25
	deathText.Font = Enum.Font.GothamBold
	deathText.Parent = container
	
	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -40, 0, 40)
	subtitle.Position = UDim2.new(0, 20, 0, 90)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "A teammate can revive you with a crafted Revival Kit."
	subtitle.TextColor3 = Theme.Colors.Paper
	subtitle.TextSize = 16
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextWrapped = true
	subtitle.Parent = container

	local rewards = Instance.new("Frame")
	rewards.Name = "RunRewards"
	rewards.Size = UDim2.new(1, -40, 0, 82)
	rewards.Position = UDim2.fromOffset(20, 142)
	rewards.Visible = false
	rewards.Parent = container
	Theme.Panel(rewards, true)
	local rewardTitle = Theme.Label(rewards, "EARNED THIS EXPEDITION", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 8), 10, Theme.Colors.Paper, true)
	rewardTitle.Name = "RewardTitle"
	local rewardValue = Theme.Label(rewards, "", UDim2.new(1, -24, 0, 25), UDim2.fromOffset(12, 25), 19, Theme.Colors.Amber, true)
	rewardValue.Name = "RewardValue"
	local rewardStatus = Theme.Label(rewards, "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 51), 11, Theme.Colors.Paper)
	rewardStatus.Name = "RewardStatus"
	rewardStatus.TextWrapped = true
	
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
	spectateBtn.Text = "SPECTATE TEAMMATES"
	spectateBtn.TextColor3 = Color3.new(1, 1, 1)
	spectateBtn.TextSize = 18
	spectateBtn.Font = Enum.Font.GothamBold
	spectateBtn.AutoButtonColor = true
	spectateBtn.Parent = buttonsFrame
	Theme.Button(spectateBtn, true)
	
	local specCorner = Instance.new("UICorner")
	specCorner.CornerRadius = UDim.new(0, 8)
	specCorner.Parent = spectateBtn
	
	-- Return to lobby button
	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "LobbyButton"
	lobbyBtn.Size = UDim2.new(1, 0, 0, 50)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
	lobbyBtn.BorderSizePixel = 0
	lobbyBtn.Text = "RETURN TO LOBBY"
	lobbyBtn.TextColor3 = Color3.new(1, 1, 1)
	lobbyBtn.TextSize = 18
	lobbyBtn.Font = Enum.Font.GothamBold
	lobbyBtn.AutoButtonColor = true
	lobbyBtn.Visible = RunService:IsStudio()
	lobbyBtn.Parent = buttonsFrame
	Theme.Button(lobbyBtn, false)
	
	local lobbyCorner = Instance.new("UICorner")
	lobbyCorner.CornerRadius = UDim.new(0, 8)
	lobbyCorner.Parent = lobbyBtn
	local results = Instance.new("ScrollingFrame")
	results.Name = "TeamResults"
	results.Size = UDim2.new(1, -40, 0, 190)
	results.Position = UDim2.fromOffset(20, 238)
	results.BackgroundTransparency = 1
	results.BorderSizePixel = 0
	results.ScrollBarThickness = 3
	results.ScrollBarImageColor3 = Theme.Colors.Amber
	results.AutomaticCanvasSize = Enum.AutomaticSize.Y
	results.CanvasSize = UDim2.new()
	results.Visible = false
	results.Parent = container
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 6)
	rows.Parent = results
	local travelStatus = Theme.Label(container, "", UDim2.fromOffset(400, 26), UDim2.fromOffset(20, 493), 11, Theme.Colors.Paper)
	travelStatus.Name = "TravelStatus"
	travelStatus.TextWrapped = true
	travelStatus.Visible = false
	
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.FitMenu(container,440,525,{MobileWidth=360,MobileHeight=610,HideClose=true,OnResize=function(_,_,mobile)
		screenGui.IgnoreGuiInset = not mobile
		if mobile then mobileDeathLayout(container)
		elseif updateDeathUI then updateDeathUI(lastCanSpectate) end
	end})
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
	Theme.Panel(topBar, true)
	
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 8)
	topCorner.Parent = topBar
	
	local spectateLabel = Instance.new("TextLabel")
	spectateLabel.Name = "SpectateLabel"
	spectateLabel.Size = UDim2.new(1, 0, 0, 20)
	spectateLabel.Position = UDim2.new(0, 0, 0, 5)
	spectateLabel.BackgroundTransparency = 1
	spectateLabel.Text = "SPECTATING"
	spectateLabel.TextColor3 = Theme.Colors.Amber
	spectateLabel.TextSize = 12
	spectateLabel.Font = Enum.Font.GothamBold
	spectateLabel.Parent = topBar
	
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Name = "TargetLabel"
	targetLabel.Size = UDim2.new(1, 0, 0, 25)
	targetLabel.Position = UDim2.new(0, 0, 0, 22)
	targetLabel.BackgroundTransparency = 1
	targetLabel.Text = "Player Name"
	targetLabel.TextColor3 = Theme.Colors.Paper
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
	Theme.Panel(controlsBar, true)

	
	local ctrlCorner = Instance.new("UICorner")
	ctrlCorner.CornerRadius = UDim.new(0, 8)
	ctrlCorner.Parent = controlsBar
	
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "ControlsLabel"
	controlsLabel.Size = UDim2.new(1, 0, 1, 0)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "[Q] Previous   |   [E] Next   |   [X] Stop Spectating"
	controlsLabel.TextColor3 = Theme.Colors.Paper
	controlsLabel.TextSize = 14
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.Parent = controlsBar
	local touchButtons={}
	for index,entry in ipairs({{"Previous", "PrevTarget"},{"Next", "NextTarget"},{"Stop", "StopSpectate"}}) do
		local button=Instance.new("TextButton")
		button.Name,button.Text=entry[2].."Button",entry[1]
		button.Font,button.TextSize=Enum.Font.GothamBold,16
		button.Size=UDim2.new(1/3,-10,1,-12); button.Position=UDim2.new((index-1)/3,6,0,6)
		button.Visible=false; button.Parent=controlsBar; Theme.Button(button,index==3)
		button.Activated:Connect(function()
			if not isSpectating then return end
			if SpectateRemote then SpectateRemote:FireServer(entry[2]) end
			if entry[2]=="StopSpectate" and stopSpectateCamera then stopSpectateCamera() end
		end)
		table.insert(touchButtons,button)
	end
	
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.BindResponsive(controlsBar,function(mobile,safe)
		screenGui.IgnoreGuiInset=not mobile
		controlsLabel.Visible=not mobile
		for _,button in ipairs(touchButtons) do button.Visible=mobile end
		if mobile then
			controlsBar.Size=UDim2.fromOffset(math.min(480,safe.X-24),60)
			controlsBar.Position,controlsBar.AnchorPoint=UDim2.new(.5,0,1,-12),Vector2.new(.5,1)
			topBar.Size=UDim2.fromOffset(math.min(360,safe.X-24),56); topBar.Position=UDim2.new(.5,0,0,8)
			spectateLabel.TextSize=14
		else
			controlsBar.Size=UDim2.fromOffset(400,40); controlsBar.Position,controlsBar.AnchorPoint=UDim2.new(.5,0,1,-60),Vector2.new(.5,0)
			topBar.Size=UDim2.fromOffset(300,50); topBar.Position=UDim2.new(.5,0,0,20); spectateLabel.TextSize=12
		end
	end)
	return screenGui
end

updateDeathUI = function(canSpectate)
	lastCanSpectate = canSpectate == true
	local ui = playerGui:FindFirstChild("DeathUI")
	if not ui then return end
	local container = ui:FindFirstChild("Container", true)
	if not container then return end
	local deathText = container:FindFirstChild("DeathText")
	local subtitle = container:FindFirstChild("Subtitle")
	local buttons = container:FindFirstChild("Buttons")
	local spectateBtn = buttons and buttons:FindFirstChild("SpectateButton")
	local lobbyBtn = buttons and buttons:FindFirstChild("LobbyButton")

	if deathText then
		deathText.Text = isGameOver and "EXPEDITION COMPLETE" or "EXPEDITION INTERRUPTED"
	end

	if subtitle then
		if isGameOver then
			local seconds = math.floor(teamResults and teamResults.Elapsed or 0)
			subtitle.Text = string.format("TEAM SURVIVAL  %02d:%02d\nYour team has fallen. This run has ended.", math.floor(seconds / 60), seconds % 60)
		else
			subtitle.Text = "A teammate can revive you with a crafted Revival Kit."
		end
	end
	if not Theme.IsMobile() then container.Size = UDim2.fromOffset(440, isGameOver and 525 or 300) end
	if buttons then buttons.Position = UDim2.fromOffset(20, isGameOver and 440 or 150) end
	local travelStatus = container:FindFirstChild("TravelStatus")
	if travelStatus then
		travelStatus.Visible = isGameOver and not RunService:IsStudio()
		travelStatus.Text = returnMessage
	end
	local rewards = container:FindFirstChild("RunRewards")
	if rewards then
		rewards.Visible = isGameOver
		local summary = rewardSummaries[player.UserId]
		local earned = summary and summary.EarnedCurrency or player:GetAttribute("RunFieldMarksEarned") or 0
		local xp = summary and summary.EarnedXP or player:GetAttribute("RunXPEarned") or 0
		local pending = summary and summary.PendingClaims or player:GetAttribute("ExpeditionRewardsPending") or 0
		local complete = summary and summary.TotalsComplete
		if complete == nil then complete = player:GetAttribute("RunRewardTotalsComplete") ~= false end
		local preview = RunService:IsStudio()
		rewards.RewardTitle.Text = preview and "EXPEDITION REWARD PREVIEW" or (complete and "EARNED THIS EXPEDITION" or "RECORDED EXPEDITION REWARDS")
		rewards.RewardValue.Text = string.format("+%d %s   ·   +%d XP", earned, currencyName, xp)
		if preview then
			rewards.RewardStatus.Text = "Studio preview · your permanent balance is unchanged."
		elseif pending > 0 then
			rewards.RewardStatus.Text = "Saving earned rewards to your permanent balance…"
		elseif not complete then
			rewards.RewardStatus.Text = "Includes the rewards recorded in this older saved world."
		else
			rewards.RewardStatus.Text = earned + xp > 0 and "Added to your permanent balance." or "Survive, complete objectives, and revive teammates to earn rewards."
		end
	end
	local results = container:FindFirstChild("TeamResults")
	if results then
		results.Visible = isGameOver
		for _, child in ipairs(results:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		if isGameOver and teamResults then
			local header = Theme.Label(results, "EXPEDITION CREW  ·  " .. string.upper(currencyName), UDim2.new(1, -8, 0, Theme.IsMobile() and 38 or 24), UDim2.new(), Theme.IsMobile() and 15 or 11, Theme.Colors.Amber, true)
			header.Name = "CrewHeader"
			header.LayoutOrder = 0
			for index, entry in ipairs(teamResults.Players or {}) do
				local summary = rewardSummaries[entry.UserId]
				local marks = summary and string.format("+%d%s", summary.EarnedCurrency, summary.TotalsComplete == false and " recorded" or "") or "…"
				local text = string.format("%s\n%d revives  ·  %d falls  ·  %s marks", entry.DisplayName or entry.Name, entry.Revives or 0, entry.Deaths or 0, marks)
				local row = Theme.Label(results, text, UDim2.new(1, -8, 0, Theme.IsMobile() and 58 or 40), UDim2.new(), Theme.IsMobile() and 16 or 13, Theme.Colors.Paper)
				row.TextWrapped = true
				row.Name = "CrewMember_" .. tostring(entry.UserId)
				row.LayoutOrder = index
			end
		end
	end

	if spectateBtn then
		spectateBtn.Visible = (not isGameOver) and canSpectate == true
	end

	if lobbyBtn then
		local studio = RunService:IsStudio()
		local enabled = isGameOver and not studio and LobbyRemote ~= nil and returnRequest == nil
			or studio and (not isGameOver or canReturnToLobby)
		-- The pre-wipe live state disables this button. Restore Active as well as
		-- Interactable: Activated does not fire while Active remains false.
		lobbyBtn.Active = enabled
		lobbyBtn.Interactable = enabled
		lobbyBtn.Selectable = enabled
		lobbyBtn.AutoButtonColor = enabled
		if isGameOver and not RunService:IsStudio() then
			lobbyBtn.Visible = true
			lobbyBtn.Text = returnRequest and "RETURNING…" or "RETURN TO OBSERVATORY"
		elseif isGameOver then
			lobbyBtn.Visible = canReturnToLobby
			lobbyBtn.BackgroundColor3 = Theme.Colors.SlotEmpty
			lobbyBtn.TextColor3 = Theme.Colors.Text
			lobbyBtn.Text = "RESPAWN (STUDIO)"
		else
			lobbyBtn.Visible = RunService:IsStudio()
			lobbyBtn.BackgroundColor3 = Theme.Colors.SlotEmpty
			lobbyBtn.TextColor3 = Theme.Colors.Text
			lobbyBtn.Text = "RESPAWN (STUDIO)"
		end
	end
	mobileDeathLayout(container)
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
		-- Repeated game-state/results updates refresh the open panel without
		-- restarting its entrance tween and moving it down again.
		if ui.Enabled then return end
		ui.Enabled = true

		local overlay = ui:FindFirstChild("Overlay")
		local container = ui:FindFirstChild("Container", true)
		if overlay then
			overlay.BackgroundTransparency = 1
			TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.4}):Play()
		end
		if container and not Theme.IsMobile() then
			container.Position = UDim2.new(0.5, 0, 0.6, 0)
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		end
	end
end

-------------------------------------------------------------------
-- SPECTATE CAMERA
-------------------------------------------------------------------
local function bindSpectateTarget(target)
	if spectateConnection then
		spectateConnection:Disconnect()
		spectateConnection = nil
	end

	spectateTarget = target

	if target and target.Character then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid") or target.Character
	end

	if target then
		spectateConnection = target.CharacterAdded:Connect(function(newChar)
			if isSpectating and spectateTarget == target then
				camera.CameraSubject = newChar:FindFirstChildOfClass("Humanoid") or newChar
			end
		end)
	end

	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		spectateUI.Enabled = true
		local targetLabel = spectateUI:FindFirstChild("TopBar") and spectateUI.TopBar:FindFirstChild("TargetLabel")
		if targetLabel then
			targetLabel.Text = target and target.Name or "No target"
		end
	end
end

local function startSpectateCamera(target)
	if not target then return end
	if not isSpectating then
		originalCameraType = camera.CameraType
		originalCameraSubject = camera.CameraSubject
	end
	isSpectating = true

	bindSpectateTarget(target)
	
	-- Hide death UI while spectating
	local deathUIRef = playerGui:FindFirstChild("DeathUI")
	if deathUIRef then
		deathUIRef.Enabled = false
	end
end

stopSpectateCamera = function()
	local restoreType = originalCameraType
	local restoreSubject = originalCameraSubject

	isSpectating = false
	spectateTarget = nil
	
	if spectateConnection then
		spectateConnection:Disconnect()
		spectateConnection = nil
	end
	
	-- Restore camera
	if restoreType then
		camera.CameraType = restoreType
	end
	if restoreSubject and restoreSubject.Parent then
		camera.CameraSubject = restoreSubject
	end
	originalCameraType = nil
	originalCameraSubject = nil
	
	-- Hide spectate UI
	local spectateUI = playerGui:FindFirstChild("SpectateUI")
	if spectateUI then
		spectateUI.Enabled = false
	end
	
	-- Show death UI if still dead
	if isDead then
		recoverCorpseCamera()
		local deathUIRef = playerGui:FindFirstChild("DeathUI")
		if deathUIRef then
			deathUIRef.Enabled = true
		end
	end
end

local function updateSpectateTarget(target)
	if not isSpectating then return end

	bindSpectateTarget(target)
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
		returnRequest, returnAccepted, returnMessage = nil, false, ""
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
		if type(data) ~= "table" then return end
		print("[DeathClient] Showing death UI")
		if data.DeathId and data.DeathId ~= corpseDeathId then clearCorpseCamera() end
		corpseDeathId = data.DeathId or corpseDeathId
		if typeof(data.ragdoll) == "Instance" and data.ragdoll:IsA("Model") then corpse = data.ragdoll end
		local position = data.ragdollPosition
		if typeof(position) == "Vector3" and position.X == position.X and position.Y == position.Y and position.Z == position.Z
			and math.abs(position.X) < math.huge and math.abs(position.Y) < math.huge and math.abs(position.Z) < math.huge then corpsePosition = position end
		showDeathUI(data.canSpectate)
		recoverCorpseCamera()
	elseif action == "Revived" then
		clearCorpseCamera()
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
		clearCorpseCamera()
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
		local subtitle = ui and ui:FindFirstChild("Container", true)
			and ui:FindFirstChild("Container", true):FindFirstChild("Subtitle")
		if subtitle then
			subtitle.Text = "Return to lobby is only available in Studio."
		end
		
	elseif action == "TeamResults" and type(data) == "table" then
		teamResults = data
		isGameOver = true
		showGameOverUI()
		if RewardsRemote then RewardsRemote:FireServer("RequestSummary") end
	elseif action == "ReviveNotice" and type(data) == "string" then
		showReviveNotice(data)
	elseif action == "PlayerDied" or action == "PlayerRevived" then
		if isDead and not isGameOver then
			local alive = false
			for _, teammate in ipairs(Players:GetPlayers()) do
				local hum = teammate.Character and teammate.Character:FindFirstChildOfClass("Humanoid")
				if teammate ~= player and not teammate:GetAttribute("IsDead") and hum and hum.Health > 0 then alive = true break end
			end
			updateDeathUI(alive)
		end
	end
end

local function onSpectateRemote(action, data)
	if action == "SpectateTarget" then
		if data and typeof(data) == "Instance" and data:IsA("Player") then
			if isSpectating then
				updateSpectateTarget(data)
			else
				startSpectateCamera(data)
			end
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
	
	local container = ui:FindFirstChild("Container", true)
	if not container then return end
	
	local buttons = container:WaitForChild("Buttons", 5)
	if not buttons then return end
	
	local spectateBtn = buttons:FindFirstChild("SpectateButton")
	local lobbyBtn = buttons:FindFirstChild("LobbyButton")
	
	if spectateBtn then
		spectateBtn.Activated:Connect(function()
			if SpectateRemote then
				SpectateRemote:FireServer("StartSpectate")
			end
		end)
	end
	
	if lobbyBtn then
		lobbyBtn.Activated:Connect(function()
			if isGameOver and not RunService:IsStudio() then
				if not LobbyRemote or returnRequest then return end
				local requestId = "DeathReturn:" .. HttpService:GenerateGUID(false)
				returnRequest, returnAccepted, returnMessage = requestId, false, "Arranging your return to the observatory…"
				updateDeathUI(lastCanSpectate)
				LobbyRemote:FireServer("ReturnLobby", {RequestId = requestId})
				task.delay(15, function()
					if returnRequest ~= requestId or returnAccepted then return end
					returnRequest, returnMessage = nil, "No reply yet. You can try returning again."
					updateDeathUI(lastCanSpectate)
				end)
			elseif ReviveRemote then
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
	local cameraConnections = {}
	local function cameraChanged()
		for _, connection in ipairs(cameraConnections) do connection:Disconnect() end
		cameraConnections = {}
		camera = workspace.CurrentCamera
		if camera then
			for _, property in ipairs({ "CameraSubject", "CameraType" }) do
				table.insert(cameraConnections, camera:GetPropertyChangedSignal(property):Connect(recoverCorpseCamera))
			end
			if isSpectating and spectateTarget and spectateTarget.Character then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = spectateTarget.Character:FindFirstChildOfClass("Humanoid") or spectateTarget.Character
			else recoverCorpseCamera() end
		end
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == player.Name .. "_Ragdoll" then recoverCorpseCamera() end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child == corpse then corpse = nil; recoverCorpseCamera() end
	end)
	cameraChanged()
	
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
		DeathRemote:FireServer("RequestState")
	else
		warn("[DeathClient] DeathRemote NOT FOUND!")
	end

	if GameStateRemote then
		GameStateRemote.OnClientEvent:Connect(onGameStateRemote)
	end
	if LobbyRemote then
		LobbyRemote.OnClientEvent:Connect(function(action, data)
			if not returnRequest or type(data) ~= "table" then return end
			if action == "Result" and data.Action == "ReturnLobby" and data.RequestId == returnRequest then
				returnAccepted = data.Success == true
				returnMessage = data.Message or (returnAccepted and "Returning to the observatory…" or "Could not return. Please try again.")
				if not returnAccepted then returnRequest = nil end
			elseif action == "Notice" and returnAccepted then
				returnMessage = data.Message or returnMessage
			else return end
			updateDeathUI(lastCanSpectate)
		end)
	end
	if RewardsRemote then
		RewardsRemote.OnClientEvent:Connect(function(action, data)
			if action ~= "Summary" or type(data) ~= "table" or type(data.Players) ~= "table" then return end
			currencyName = data.CurrencyName or currencyName
			rewardSummaries = {}
			for _, summary in ipairs(data.Players) do rewardSummaries[summary.UserId] = summary end
			if isGameOver then updateDeathUI(lastCanSpectate) end
		end)
		RewardsRemote:FireServer("RequestSummary")
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
