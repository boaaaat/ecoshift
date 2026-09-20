if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Settings = require(ReplicatedStorage.Shared.ClientSettings)

local player = Players.LocalPlayer
local flightRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CreativeFlightState")
local SPEED = 100 -- Five times the intended 20 stud/second base movement speed.
local DOUBLE_TAP_WINDOW = 0.32
local flying, lastSpace = false, -math.huge
local attachment, velocity, orientation, humanoid, root
local animateScript, animateWasEnabled

local function eligible()
	return workspace:GetAttribute("WorldType") == "Creative" and player:GetAttribute("CreativeMode") == true
		and not player:GetAttribute("IsDead")
end

local function stopFlight(notifyServer)
	flying = false
	if notifyServer ~= false then flightRemote:FireServer(false) end
	if orientation then orientation:Destroy(); orientation = nil end
	if velocity then velocity:Destroy(); velocity = nil end
	if attachment then attachment:Destroy(); attachment = nil end
	if animateScript and animateScript.Parent then
		animateScript.Enabled = animateWasEnabled ~= false
	end
	animateScript, animateWasEnabled = nil, nil
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(humanoid.FloorMaterial == Enum.Material.Air
			and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.GettingUp)
	end
	if root and root.Parent then root.AssemblyLinearVelocity = Vector3.zero end
	humanoid, root = nil, nil
end

local function startFlight(notifyServer)
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
	orientation = Instance.new("AlignOrientation")
	orientation.Name = "CreativeFlightOrientation"
	orientation.Attachment0 = attachment
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.RigidityEnabled = true
	orientation.MaxTorque = math.huge
	orientation.Responsiveness = 35
	orientation.Parent = root
	local candidateAnimate = character:FindFirstChild("Animate")
	animateScript = candidateAnimate and candidateAnimate:IsA("LocalScript") and candidateAnimate or nil
	if animateScript then
		animateWasEnabled = animateScript.Enabled
		animateScript.Enabled = false
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.12) end
	end
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = Vector3.zero
	flying = true
	if notifyServer ~= false then flightRemote:FireServer(true) end
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
	local facing = Vector3.new(direction.X, 0, direction.Z)
	if facing.Magnitude < 0.05 then
		local camera = workspace.CurrentCamera
		local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
		facing = Vector3.new(look.X, 0, look.Z)
	end
	if facing.Magnitude > 0.05 and orientation then
		orientation.CFrame = CFrame.lookAt(Vector3.zero, facing.Unit, Vector3.yAxis)
	end
	root.AssemblyAngularVelocity = Vector3.zero
end)

local function stateChanged()
	lastSpace = -math.huge
	if flying and not eligible() then stopFlight() end
end
workspace:GetAttributeChangedSignal("WorldType"):Connect(stateChanged)
player:GetAttributeChangedSignal("CreativeMode"):Connect(stateChanged)
player:GetAttributeChangedSignal("IsDead"):Connect(stateChanged)
player:GetAttributeChangedSignal("CreativeFlying"):Connect(function()
	if player:GetAttribute("CreativeFlying") == true then
		if not flying and eligible() then task.defer(function() if not flying then startFlight(false) end end) end
	elseif flying then stopFlight(false) end
end)
-- Death/mode changes already clear the authoritative flag. During a disconnect,
-- keep the last server-owned value intact so the departure snapshot records flight.
player.CharacterRemoving:Connect(function() stopFlight(false) end)
UserInputService.WindowFocusReleased:Connect(function() lastSpace = -math.huge end)
if player:GetAttribute("CreativeFlying") == true then task.defer(function() startFlight(false) end) end
