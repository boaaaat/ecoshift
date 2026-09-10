if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- CombatClient.client.lua
-- Handles client weapon input and sends CombatAction requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local CombatRE = Remotes and Remotes:WaitForChild("CombatAction", 3)
local WeaponFactory = require(ReplicatedStorage.Shared.Weapons.WeaponFactory)
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)

local player = Players.LocalPlayer
local activeTool = nil
local activeWeapon = nil
local holdingPrimary = false
local holdingSecondary = false
local lastClientFire = 0
local bowCharging = false
local boundTools = setmetatable({}, { __mode = "k" })
local characterConnections = {}

local function inputBlocked()
	local gui = player:FindFirstChildOfClass("PlayerGui")
	return player:GetAttribute("IsDead") == true
		or (gui and gui:GetAttribute("MenuCursorOpen") == true)
		or (gui and gui:GetAttribute("BuildPlacementActive") == true)
		or UserInputService:GetFocusedTextBox() ~= nil
end

local function disconnectCharacterConnections()
	for _, conn in ipairs(characterConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(characterConnections)
end

local function raycastFromMouse(maxRange)
	local camera = Workspace.CurrentCamera
	if not camera then return nil, nil end
	local mousePos = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	local aim = Theme.IsMobile() and camera.ViewportSize * 0.5 or Vector2.new(mousePos.X - inset.X, mousePos.Y - inset.Y)
	local ray = camera:ViewportPointToRay(aim.X, aim.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	-- Range is measured from the player on the server, not from the camera.
	-- Include the camera offset so zooming out cannot make a nearby target unclickable.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cameraOffset = root and (ray.Origin - root.Position).Magnitude or 0
	local result = Workspace:Raycast(ray.Origin, ray.Direction * (maxRange + cameraOffset), params)
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
		Touch = Theme.IsMobile(),
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
	if inputBlocked() or not activeWeapon or not CombatRE then return end
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
	if inputBlocked() or bowCharging or not activeWeapon or not CombatRE then return end
	local wtype = activeWeapon:GetType():lower()
	if wtype ~= "bow" and wtype ~= "bows" then return end
	bowCharging = true
	CombatRE:FireServer("ChargeStart")
end

local function releaseBowCharge()
	if not bowCharging or not activeWeapon or not CombatRE then return end
	bowCharging = false
	if inputBlocked() then
		CombatRE:FireServer("ChargeCancel")
		return
	end
	local data = buildAimData(activeWeapon:GetRange())
	CombatRE:FireServer("ChargeRelease", data)
end

local function startBlock()
	if inputBlocked() or not activeWeapon or not CombatRE then return end
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
	if boundTools[tool] then return end
	boundTools[tool] = true
	local weapon = WeaponFactory.Create(tool, player)
	if not weapon then return end

	tool.Equipped:Connect(function()
		activeTool = tool
		activeWeapon = weapon
	end)
	tool.Unequipped:Connect(function()
		if activeTool == tool then
			if bowCharging and CombatRE then CombatRE:FireServer("ChargeCancel") end
			activeTool = nil
			activeWeapon = nil
			bowCharging = false
			holdingPrimary = false
			holdingSecondary = false
			endBlock()
		end
	end)
	tool.Activated:Connect(function()
		if activeTool ~= tool or inputBlocked() then return end
		tool:SetAttribute("CancelMobileRelease", nil)
		holdingPrimary = true
		local kind = activeWeapon and activeWeapon:GetType():lower()
		if Theme.IsMobile() and (kind == "shield" or kind == "shields") then holdingSecondary = true; startBlock() end
		startBowCharge()
		tryAttack()
	end)
	tool.Deactivated:Connect(function()
		if activeTool ~= tool then return end
		holdingPrimary = false
		if holdingSecondary then holdingSecondary = false; endBlock() end
		if tool:GetAttribute("CancelMobileRelease") then
			if bowCharging and CombatRE then CombatRE:FireServer("ChargeCancel") end
			bowCharging = false
			return
		end
		releaseBowCharge()
	end)
end

local function onCharacter(char)
	disconnectCharacterConnections()
	activeTool = nil
	activeWeapon = nil
	bowCharging = false
	holdingPrimary = false
	holdingSecondary = false
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
	characterConnections[#characterConnections + 1] = backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	characterConnections[#characterConnections + 1] = char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
			activeWeapon = WeaponFactory.Create(child, player)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or inputBlocked() or Theme.IsMobile() then return end
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
	if Theme.IsMobile() then return end
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
	if inputBlocked() then
		holdingPrimary = false
		if holdingSecondary then holdingSecondary = false; endBlock() end
		if bowCharging then
			bowCharging = false
			if CombatRE then CombatRE:FireServer("ChargeCancel") end
		end
		return
	end
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
