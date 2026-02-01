-- CombatClient.client.lua
-- Handles player attacks on enemies
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local DamageRE = Remotes and Remotes:WaitForChild("Damage", 3)
local ToolConfig = require(ReplicatedStorage.Modules.ToolConfig)

local player = Players.LocalPlayer
local activeTool = nil
local lastAttack = 0

-- Raycast to find what we're clicking on
local function raycastTarget(range)
	local camera = Workspace.CurrentCamera
	if not camera then return nil, nil end
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Workspace.Terrain }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * range, params)
	return result and result.Instance or nil, result and result.Position or nil
end

-- Find the enemy model from a hit part
local function findEnemy(hit)
	if not hit then return nil end
	local current = hit
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			-- Check if it's an enemy (has humanoid but isn't a player)
			if humanoid then
				local plr = Players:GetPlayerFromCharacter(current)
				if not plr then
					-- It's an NPC/enemy!
					return current, humanoid
				end
			end
		end
		current = current.Parent
	end
	return nil, nil
end

-- Check if tool is a weapon (has Damage attribute)
local function isWeapon(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local dmg = tool:GetAttribute("Damage")
	if typeof(dmg) == "number" and dmg > 0 then return true end
	local child = tool:FindFirstChild("Damage")
	return child and child:IsA("ValueBase") and typeof(child.Value) == "number" and child.Value > 0
end

-- Get tool stats
local function getToolStats(tool)
	local cfg = ToolConfig.Read(tool)
	return {
		Damage = cfg.Damage or 10,
		Range = math.max(cfg.Range or 8, 4),
		Cooldown = math.max(cfg.Cooldown or 0.5, 0.1),
	}
end

-- Show damage number popup
local function showDamageNumber(position, damage, isCrit)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = nil
	
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position + Vector3.new(math.random(-1, 1), 1, math.random(-1, 1))
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = Workspace
	
	billboard.Adornee = part
	billboard.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damage))
	label.TextColor3 = isCrit and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 200, 100)
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
	
	-- Animate upward and fade out
	local startPos = part.Position
	local endPos = startPos + Vector3.new(0, 3, 0)
	
	task.spawn(function()
		local duration = 0.8
		local startTime = tick()
		while tick() - startTime < duration do
			local alpha = (tick() - startTime) / duration
			part.Position = startPos:Lerp(endPos, alpha)
			label.TextTransparency = alpha
			label.TextStrokeTransparency = 0.5 + alpha * 0.5
			task.wait()
		end
		part:Destroy()
	end)
end

-- Play attack animation/effect
local function playAttackEffect(tool)
	-- Simple swing sound (if tool has one)
	local swingSound = tool:FindFirstChild("SwingSound") or tool:FindFirstChild("Swing")
	if swingSound and swingSound:IsA("Sound") then
		swingSound:Play()
	end
	
	-- You could add animation here if tools have attack animations
end

-- Attack an enemy
local function attackEnemy(tool, enemy, humanoid, hitPosition)
	local stats = getToolStats(tool)
	local damage = stats.Damage
	
	-- Check if in range
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	
	local enemyRoot = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
	if not enemyRoot then return false end
	
	local distance = (hrp.Position - enemyRoot.Position).Magnitude
	if distance > stats.Range + 5 then return false end -- Small buffer for lag
	
	-- Send damage to server
	if DamageRE then
		DamageRE:FireServer(enemy, damage, "Melee")
	end
	
	-- Play attack effect
	playAttackEffect(tool)
	
	-- Show damage number locally (server will do actual damage)
	showDamageNumber(hitPosition or enemyRoot.Position, damage, false)
	
	print(string.format("[Combat] Attacked %s for %d damage", enemy.Name, damage))
	return true
end

-- Main attack function
local function tryAttack()
	if not activeTool or not isWeapon(activeTool) then return false end
	
	local stats = getToolStats(activeTool)
	local now = tick()
	if now - lastAttack < stats.Cooldown then return false end
	
	local hit, hitPos = raycastTarget(stats.Range + 10)
	local enemy, humanoid = findEnemy(hit)
	
	if enemy and humanoid and humanoid.Health > 0 then
		lastAttack = now
		return attackEnemy(activeTool, enemy, humanoid, hitPos)
	end
	
	return false
end

-- Bind tool events
local function bindTool(tool)
	if not tool:IsA("Tool") then return end
	if not isWeapon(tool) then return end
	
	tool.Equipped:Connect(function()
		activeTool = tool
	end)
	
	tool.Unequipped:Connect(function()
		if activeTool == tool then
			activeTool = nil
		end
	end)
	
	tool.Activated:Connect(function()
		tryAttack()
	end)
end

-- Input handling for continuous attacks while holding click
local holding = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	holding = true
	
	-- Try attack immediately
	tryAttack()
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	holding = false
end)

-- Setup for character
local function onCharacter(char)
	activeTool = nil
	
	local backpack = player:WaitForChild("Backpack")
	
	-- Bind existing tools
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
		end
	end
	
	-- Bind new tools
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
		end
	end)
end

-- Initialize
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

print("[CombatClient] Initialized - Click on enemies to attack!")
