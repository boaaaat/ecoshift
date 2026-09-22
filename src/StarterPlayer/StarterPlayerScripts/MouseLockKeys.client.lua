-- Shift lock starts disabled, toggles with Control, and yields cursor ownership to menus.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local gameSettings = UserSettings().GameSettings
local locked = false
local currentHumanoid
local originalCameraOffset = Vector3.zero
local originalMouseIcon = mouse.Icon

-- Disable the stock toggle so its internal off-by-default state cannot fight this one.
local scripts = player:WaitForChild("PlayerScripts")
local playerModule = scripts:WaitForChild("PlayerModule", 30)
local cameraModule = playerModule and playerModule:WaitForChild("CameraModule", 10)
local stockController = cameraModule and cameraModule:WaitForChild("MouseLockController", 10)
if stockController then
	local boundKeys = stockController:FindFirstChild("BoundKeys")
	if not boundKeys or not boundKeys:IsA("StringValue") then
		if boundKeys then boundKeys:Destroy() end
		boundKeys = Instance.new("StringValue")
		boundKeys.Name = "BoundKeys"
		boundKeys.Parent = stockController
	end
	boundKeys.Value = ""
end

local function restoreHumanoid()
	if currentHumanoid and currentHumanoid.Parent then
		currentHumanoid.CameraOffset = originalCameraOffset
	end
	currentHumanoid = nil
end

local function getHumanoid()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= currentHumanoid then
		restoreHumanoid()
		currentHumanoid = humanoid
		originalCameraOffset = humanoid and humanoid.CameraOffset or Vector3.zero
	end
	return humanoid
end

local function toggle(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	locked = not locked
	if not locked then
		restoreHumanoid()
		mouse.Icon = originalMouseIcon
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		gameSettings.RotationType = Enum.RotationType.MovementRelative
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"EcoShiftMouseLockToggle",
	toggle,
	false,
	Enum.ContextActionPriority.Medium.Value,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl
)

RunService:BindToRenderStep("EcoShiftDefaultMouseLock", Enum.RenderPriority.Camera.Value + 1, function()
	local keyboardAndMouse = UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
	if not locked or not keyboardAndMouse then
		if currentHumanoid then restoreHumanoid() end
		mouse.Icon = originalMouseIcon
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		gameSettings.RotationType = Enum.RotationType.MovementRelative
		return
	end

	local humanoid = getHumanoid()
	if humanoid then
		local camera = workspace.CurrentCamera
		local firstPerson = camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
		humanoid.CameraOffset = firstPerson and originalCameraOffset or originalCameraOffset + Vector3.new(1.75, 0, 0)
	end

	gameSettings.RotationType = Enum.RotationType.CameraRelative
	if playerGui:GetAttribute("MenuCursorOpen") or GuiService.MenuIsOpen then
		mouse.Icon = originalMouseIcon
		return
	end

	mouse.Icon = "rbxasset://textures/MouseLockedCursor.png"
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end)

script.Destroying:Connect(function()
	ContextActionService:UnbindAction("EcoShiftMouseLockToggle")
	RunService:UnbindFromRenderStep("EcoShiftDefaultMouseLock")
	restoreHumanoid()
	mouse.Icon = originalMouseIcon
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)
