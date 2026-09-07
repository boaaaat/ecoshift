-- HarvestFeedbackUI.client.lua
-- Shows damage numbers and health bars when harvesting resources
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local C = require(ReplicatedStorage.Shared.UI.UITheme).Colors
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DEBUG = false

local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rFeedback = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.HarvestFeedback)

-- UI Constants
local COLORS = {
	DamageText = C.Amber,
	DamageCrit = C.Danger,
	HealthBar = C.Sage,
	HealthBarLow = C.Danger,
	HealthBarBg = C.Night,
	Text = C.Paper,
}

-- Create main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "HarvestFeedbackUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Track active health bars
local activeHealthBars = {} -- [node] = {Billboard, Fill, Attachment, lastUpdate}

-- Create a floating damage number
local function createDamageNumber(position, damage, destroyed)
	if typeof(position) ~= "Vector3" then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = UDim2.new(0, 140, 0, 70)
	billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 1.6, math.random(-10, 10) / 10)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50
	billboard.Parent = gui
	
	-- Create an attachment point in workspace
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	billboard.Adornee = attachment
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(damage)
	label.TextColor3 = destroyed and COLORS.DamageCrit or COLORS.DamageText
	label.TextSize = destroyed and 28 or 22
	label.Font = Enum.Font.GothamBold
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	
	-- Animate upward and fade out
	local startOffset = billboard.StudsOffset
	local endOffset = startOffset + Vector3.new(0, 2, 0)
	
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, tweenInfo, {StudsOffset = endOffset}):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.3), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}):Play()
	
	-- Scale pop effect (larger, smoother)
	label.TextSize = destroyed and 22 or 18
	TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = destroyed and 28 or 22
	}):Play()
	
	-- Clean up
	task.delay(1, function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

-- Create or update health bar for a node
local function updateHealthBar(node, position, currentHealth, maxHealth, destroyed)
	if typeof(position) ~= "Vector3" then
		return
	end
	if destroyed then
		-- Remove health bar if exists
		if activeHealthBars[node] then
			activeHealthBars[node].Billboard:Destroy()
			if activeHealthBars[node].Attachment then
				activeHealthBars[node].Attachment:Destroy()
			end
			activeHealthBars[node] = nil
		end
		return
	end
	
	local safeMaxHealth = math.max(1, tonumber(maxHealth) or 0)
	local safeCurrentHealth = math.max(0, tonumber(currentHealth) or 0)
	local healthPercent = math.clamp(safeCurrentHealth / safeMaxHealth, 0, 1)
	
	-- Create health bar if doesn't exist
	if not activeHealthBars[node] then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "HealthBar"
		billboard.Size = UDim2.new(0, 140, 0, 28)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 40
		billboard.Parent = gui

		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		billboard.Adornee = attachment
		
		-- Background
		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.new(1, 0, 0, 12)
		bg.Position = UDim2.new(0, 0, 0.5, -6)
		bg.BackgroundColor3 = COLORS.HealthBarBg
		bg.BorderSizePixel = 0
		bg.Parent = billboard
		
		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 4)
		bgCorner.Parent = bg
		
		-- Health fill
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(healthPercent, 0, 1, 0)
		fill.BackgroundColor3 = healthPercent > 0.3 and COLORS.HealthBar or COLORS.HealthBarLow
		fill.BorderSizePixel = 0
		fill.Parent = bg
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = fill
		
		-- Name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.new(0, 0, 0, -4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = node.Name
		nameLabel.TextColor3 = COLORS.Text
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.Parent = billboard
		
		activeHealthBars[node] = {
			Billboard = billboard,
			Fill = fill,
			Attachment = attachment,
			lastUpdate = os.clock()
		}
	end
	
	-- Update health bar
	local data = activeHealthBars[node]
	data.lastUpdate = os.clock()
	if data.Attachment and typeof(position) == "Vector3" then
		data.Attachment.WorldPosition = position
	end
	
	-- Animate health change
	local targetColor = healthPercent > 0.3 and COLORS.HealthBar or COLORS.HealthBarLow
	TweenService:Create(data.Fill, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Size = UDim2.new(healthPercent, 0, 1, 0),
		BackgroundColor3 = targetColor
	}):Play()
end

-- Clean up old health bars
local function cleanupHealthBars()
	local now = os.clock()
	for node, data in pairs(activeHealthBars) do
		-- Remove if node is gone or hasn't been updated in 3 seconds
		if not node or not node.Parent or (now - data.lastUpdate) > 3 then
			if data.Billboard then
				-- Fade out
				TweenService:Create(data.Billboard, TweenInfo.new(0.3), {Size = UDim2.new(0, 60, 0, 15)}):Play()
				task.delay(0.3, function()
					if data.Billboard then
						data.Billboard:Destroy()
					end
					if data.Attachment then
						data.Attachment:Destroy()
					end
				end)
			end
			activeHealthBars[node] = nil
		end
	end
end

local function handleFeedback(data)
	dprint("[HarvestFeedbackUI] Received feedback:", data)
	if type(data) ~= "table" then return end

	local node = data.Node
	local position = data.Position
	local damage = data.Damage or 0
	-- Support both 'Health' and 'CurrentHealth' field names
	local currentHealth = data.Health or data.CurrentHealth or 0
	local maxHealth = data.MaxHealth or 100
	local destroyed = data.Destroyed

	if not position then
		warn("[HarvestFeedbackUI] No position in feedback data")
		return
	end

	if damage > 0 then
		createDamageNumber(position, damage, destroyed)
	end

	if node then
		updateHealthBar(node, position, currentHealth, maxHealth, destroyed)
	end
end

if rFeedback then
	rFeedback.OnClientEvent:Connect(handleFeedback)
	dprint("[HarvestFeedbackUI] Connected to HarvestFeedback remote")
else
	warn("[HarvestFeedbackUI] Missing HarvestFeedback remote:", Config.RemoteNames.HarvestFeedback)
end

-- Cleanup loop (throttled to avoid performance issues)
local lastCleanup = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastCleanup > 0.5 then
		lastCleanup = now
		cleanupHealthBars()
	end
end)

dprint("[HarvestFeedbackUI] Ready")
