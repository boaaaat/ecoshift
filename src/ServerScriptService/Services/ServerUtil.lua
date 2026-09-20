-- Shared low-level server helpers. Callers retain their domain-specific checks.
local Players = game:GetService("Players")

local Util = {}

function Util.Root(subject)
	local character = subject and (subject:IsA("Player") and subject.Character or subject)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Util.IsLiving(player, options)
	options = options or {}
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not player or player.Parent ~= Players or not humanoid or humanoid.Health <= 0 or player:GetAttribute("IsDead") then return false end
	if not options.AllowLoading and (player:GetAttribute("WorldPlayerLoading") or player:GetAttribute("WorldPlayerRestoring")) then return false end
	if options.ExcludeInterior and player:GetAttribute("InteriorId") then return false end
	return true
end

function Util.IsNear(player, target, distance, options)
	local root = Util.Root(player)
	if not Util.IsLiving(player, options) or not root or not target or not target.Parent then return false end
	local position = target:IsA("Model") and target:GetPivot().Position or target.Position
	return (root.Position - position).Magnitude <= (distance or 12)
end

function Util.Part(parent, name, size, transform, properties)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	if typeof(transform) == "CFrame" then part.CFrame = transform else part.Position = transform end
	part.Anchored = true
	for key, value in pairs(properties or {}) do part[key] = value end
	part.Parent = parent
	return part
end

function Util.Prompt(parent, action, objectText, callback, options)
	options = options or {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = options.KeyCode or Enum.KeyCode.F
	prompt.RequiresLineOfSight = options.RequiresLineOfSight == true
	prompt.MaxActivationDistance = options.MaxActivationDistance or 10
	prompt.HoldDuration = options.HoldDuration or 1
	prompt.Parent = parent
	if callback then prompt.Triggered:Connect(callback) end
	return prompt
end

return Util
