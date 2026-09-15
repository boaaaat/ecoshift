if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Settings = require(ReplicatedStorage.Shared.ClientSettings)

local player = Players.LocalPlayer
local SPEED = 100 -- Five times the intended 20 stud/second base movement speed.
local DOUBLE_TAP_WINDOW = 0.32
local flying, lastSpace = false, -math.huge
local attachment, velocity, humanoid, root

local gui = Instance.new("ScreenGui")
gui.Name = "CreativeFlightUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")
local status = Theme.Label(gui, "FLYING  ·  SPACE UP  ·  SHIFT DOWN", UDim2.fromOffset(300, 32), UDim2.new(.5, -150, 0, 92), 12, nil, true)
status.BackgroundTransparency = .28
status.Visible = false
Theme.Bind(status, "BackgroundColor3", "Panel")
Theme.Bind(status, "TextColor3", "Amber")
Theme.Corner(status, 8)

local function eligible()
	return workspace:GetAttribute("WorldType") == "Creative" and player:GetAttribute("CreativeMode") == true
		and not player:GetAttribute("IsDead")
end

local function stopFlight()
	flying = false
	player:SetAttribute("CreativeFlying", nil)
	status.Visible = false
	if velocity then velocity:Destroy(); velocity = nil end
	if attachment then attachment:Destroy(); attachment = nil end
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	if root and root.Parent then root.AssemblyLinearVelocity = Vector3.zero end
	humanoid, root = nil, nil
end

local function startFlight()
	if not eligible() then return end
	local character = player.Character
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then humanoid, root = nil, nil; return end
	attachment = Instance.new("Attachment")
	attachment.Name = "CreativeFlightAttachment"
	attachment.Parent = root
	velocity = Instance.new("LinearVelocity")
	velocity.Name = "CreativeFlightVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = Vector3.zero
	flying = true
	player:SetAttribute("CreativeFlying", true)
	status.Visible = true
end

local function toggleFlight()
	if flying then stopFlight() else startFlight() end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode ~= Enum.KeyCode.Space then return end
	if processed or UserInputService:GetFocusedTextBox() or not Settings.CanInput() or not eligible() then return end
	local now = os.clock()
	if now - lastSpace <= DOUBLE_TAP_WINDOW then
		lastSpace = -math.huge
		toggleFlight()
	else
		lastSpace = now
	end
end)

RunService.RenderStepped:Connect(function()
	if not flying then return end
	if not eligible() or not humanoid or not humanoid.Parent or not root or not root.Parent or not velocity or not velocity.Parent then
		stopFlight()
		return
	end
	local direction = humanoid.MoveDirection
	if direction.Magnitude > 1 then direction = direction.Unit end
	local vertical = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then vertical -= 1 end
	local desired = direction * SPEED + Vector3.new(0, vertical * SPEED, 0)
	if desired.Magnitude > SPEED then desired = desired.Unit * SPEED end
	velocity.VectorVelocity = desired
	root.AssemblyAngularVelocity = Vector3.zero
end)

local function stateChanged()
	lastSpace = -math.huge
	if flying and not eligible() then stopFlight() end
end
workspace:GetAttributeChangedSignal("WorldType"):Connect(stateChanged)
player:GetAttributeChangedSignal("CreativeMode"):Connect(stateChanged)
player:GetAttributeChangedSignal("IsDead"):Connect(stateChanged)
player.CharacterRemoving:Connect(stopFlight)
UserInputService.WindowFocusReleased:Connect(function() lastSpace = -math.huge end)
