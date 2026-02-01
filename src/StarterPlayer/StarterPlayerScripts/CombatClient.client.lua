-- CombatClient.client.lua
-- Handles client weapon input and sends CombatAction requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local CombatRE = Remotes and Remotes:WaitForChild("CombatAction", 3)
local WeaponFactory = require(ReplicatedStorage.Shared.Weapons.WeaponFactory)

local player = Players.LocalPlayer
local activeTool = nil
local activeWeapon = nil
local holdingPrimary = false
local holdingSecondary = false
local lastClientFire = 0
local bowCharging = false

local function raycastFromMouse(maxRange)
	local camera = Workspace.CurrentCamera
	if not camera then return nil, nil end
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Workspace.Terrain }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * maxRange, params)
	return result, ray
end

local function getTargetFromHit(hit)
	if not hit then return nil end
	return hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model") or nil
end

local function buildAimData(maxRange)
	local hit, ray = raycastFromMouse(maxRange)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local origin = head and head.Position or (ray and ray.Origin)
	local dir
	local target
	if hit and origin then
		dir = (hit.Position - origin).Unit
		target = getTargetFromHit(hit)
	elseif ray then
		dir = ray.Direction.Unit
	end
	return {
		Origin = origin,
		Dir = dir,
		Target = target,
		HitPos = hit and hit.Position or nil,
	}
end

local function canUseTool(cooldown)
	local now = os.clock()
	if now - lastClientFire < cooldown then return false end
	lastClientFire = now
	return true
end

local function tryAttack()
	if not activeWeapon or not CombatRE then return end
	local wtype = activeWeapon:GetType():lower()
	if wtype == "sword" or wtype == "swords" then
		local cooldown = activeWeapon:GetCooldown()
		if not canUseTool(cooldown) then return end
		local data = buildAimData(activeWeapon:GetRange() + 6)
		CombatRE:FireServer("Attack", data)
	elseif wtype == "gun" or wtype == "guns" then
		local cooldown = activeWeapon:GetCooldown()
		if not canUseTool(cooldown) then return end
		local data = buildAimData(activeWeapon:GetNumber("Range", 200))
		CombatRE:FireServer("Fire", data)
	elseif wtype == "throwable" or wtype == "throwables" then
		local cooldown = math.max(activeWeapon:GetThrowTime(), 0.2)
		if not canUseTool(cooldown) then return end
		local data = buildAimData(activeWeapon:GetRange())
		CombatRE:FireServer("Throw", data)
	end
end

local function startBowCharge()
	if not activeWeapon or not CombatRE then return end
	local wtype = activeWeapon:GetType():lower()
	if wtype ~= "bow" and wtype ~= "bows" then return end
	bowCharging = true
	CombatRE:FireServer("ChargeStart")
end

local function releaseBowCharge()
	if not bowCharging or not activeWeapon or not CombatRE then return end
	bowCharging = false
	local data = buildAimData(activeWeapon:GetRange())
	CombatRE:FireServer("ChargeRelease", data)
end

local function startBlock()
	if not activeWeapon or not CombatRE then return end
	local wtype = activeWeapon:GetType():lower()
	if wtype ~= "shield" and wtype ~= "shields" then return end
	CombatRE:FireServer("BlockStart")
end

local function endBlock()
	if not CombatRE then return end
	CombatRE:FireServer("BlockEnd")
end

local function bindTool(tool)
	if not tool:IsA("Tool") then return end
	local weapon = WeaponFactory.Create(tool, player)
	if not weapon then return end

	tool.Equipped:Connect(function()
		activeTool = tool
		activeWeapon = weapon
	end)
	tool.Unequipped:Connect(function()
		if activeTool == tool then
			activeTool = nil
			activeWeapon = nil
			bowCharging = false
			endBlock()
		end
	end)
	tool.Activated:Connect(function()
		tryAttack()
	end)
end

local function onCharacter(char)
	activeTool = nil
	activeWeapon = nil
	bowCharging = false
	local backpack = player:WaitForChild("Backpack")
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
			activeWeapon = WeaponFactory.Create(child, player)
		end
	end
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
			activeWeapon = WeaponFactory.Create(child, player)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingPrimary = true
		if activeWeapon and (activeWeapon:GetType():lower() == "bow" or activeWeapon:GetType():lower() == "bows") then
			startBowCharge()
		else
			tryAttack()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		holdingSecondary = true
		startBlock()
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdingPrimary = false
		releaseBowCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		holdingSecondary = false
		endBlock()
	end
end)

-- Continuous fire while holding (guns/swords)

game:GetService("RunService").RenderStepped:Connect(function()
	if not holdingPrimary then return end
	if not activeWeapon then return end
	local wtype = activeWeapon:GetType():lower()
	if wtype == "gun" or wtype == "guns" or wtype == "sword" or wtype == "swords" then
		tryAttack()
	end
end)

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

print("[CombatClient] Initialized")
