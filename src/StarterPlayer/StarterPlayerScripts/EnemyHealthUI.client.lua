-- EnemyHealthUI.client.lua
-- Shows health bars above enemies when damaged
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Track active health bars
local healthBars = {} -- [model] = { gui, lastDamageTime }
local HIDE_DELAY = 5 -- Seconds before hiding health bar after no damage

-- Create a health bar for an enemy
local function createHealthBar(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	
	-- Find the head or root to attach to
	local adornee = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not adornee then return nil end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyHealthBar"
	billboard.Size = UDim2.new(0, 80, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 100
	billboard.Adornee = adornee
	billboard.Parent = model
	
	-- Background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 0.5, 0)
	bg.Position = UDim2.new(0, 0, 0.5, 0)
	bg.AnchorPoint = Vector2.new(0, 0.5)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0.5, 0)ff
	bgCorner.Parent = bg
	
	-- Health fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.Position = UDim2.new(0, 2, 0, 2)
	fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	
	-- Enemy name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = model.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard
	
	-- Start hidden
	billboard.Enabled = false
	
	return {
		gui = billboard,
		fill = fill,
		humanoid = humanoid,
		lastDamageTime = 0,
		lastHealth = humanoid.Health,
	}
end

-- Update a health bar
local function updateHealthBar(model, data)
	local humanoid = data.humanoid
	if not humanoid or humanoid.Health <= 0 then
		-- Enemy dead, remove health bar
		if data.gui then
			data.gui:Destroy()
		end
		healthBars[model] = nil
		return
	end
	
	local percent = humanoid.MaxHealth > 0 and (humanoid.Health / humanoid.MaxHealth) or 0
	percent = math.clamp(percent, 0, 1)
	
	-- Animate fill
	TweenService:Create(data.fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(percent, -4, 1, -4)
	}):Play()
	
	-- Color based on health
	local color
	if percent > 0.6 then
		color = Color3.fromRGB(80, 200, 120)
	elseif percent > 0.3 then
		color = Color3.fromRGB(255, 200, 80)
	else
		color = Color3.fromRGB(255, 80, 80)
	end
	data.fill.BackgroundColor3 = color
	
	-- Check if damaged
	if humanoid.Health < data.lastHealth then
		data.lastDamageTime = tick()
		data.gui.Enabled = true
	end
	data.lastHealth = humanoid.Health
	
	-- Hide after delay
	if tick() - data.lastDamageTime > HIDE_DELAY then
		data.gui.Enabled = false
	end
end

-- Find or create health bar for an enemy
local function getOrCreateHealthBar(model)
	if healthBars[model] then
		return healthBars[model]
	end
	
	-- Check if it's an enemy (has humanoid, not a player)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then return nil end -- It's a player, not enemy
	
	local data = createHealthBar(model)
	if data then
		healthBars[model] = data
		
		-- Connect health changed
		humanoid.HealthChanged:Connect(function()
			updateHealthBar(model, data)
		end)
		
		-- Clean up when destroyed
		model.AncestryChanged:Connect(function(_, parent)
			if not parent then
				if data.gui then
					data.gui:Destroy()
				end
				healthBars[model] = nil
			end
		end)
	end
	return data
end

-- Scan workspace for enemies
local function scanForEnemies(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			local plr = Players:GetPlayerFromCharacter(child)
			if not plr then
				getOrCreateHealthBar(child)
			end
		elseif child:IsA("Folder") then
			scanForEnemies(child)
		end
	end
end

-- Watch for new enemies spawning
local function watchFolder(folder)
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.wait(0.1) -- Wait for humanoid to be added
			local humanoid = child:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local plr = Players:GetPlayerFromCharacter(child)
				if not plr then
					getOrCreateHealthBar(child)
				end
			end
		elseif child:IsA("Folder") then
			watchFolder(child)
			scanForEnemies(child)
		end
	end)
end

-- Initialize
local function init()
	-- Scan existing
	scanForEnemies(Workspace)
	
	-- Watch GeneratedWorld for new enemies
	local genWorld = Workspace:FindFirstChild("GeneratedWorld")
	if genWorld then
		watchFolder(genWorld)
		scanForEnemies(genWorld)
	end
	
	-- Watch for GeneratedWorld being created
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "GeneratedWorld" then
			watchFolder(child)
			scanForEnemies(child)
		end
	end)
	
	-- Also watch EnemySpawns
	local enemySpawns = Workspace:FindFirstChild("EnemySpawns")
	if enemySpawns then
		watchFolder(enemySpawns)
	end
	
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "EnemySpawns" then
			watchFolder(child)
		end
	end)
end

init()
print("[EnemyHealthUI] Initialized - Enemy health bars enabled")
