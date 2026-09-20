local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Settings = require(ReplicatedStorage.Shared.ClientSettings)
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local isExpedition = require(ReplicatedStorage.Shared.SessionConfig).GetMode() == "Expedition"
local original = setmetatable({}, { __mode = "k" })
local renderDistanceRemote
local renderDistanceValues = {Near=1, Medium=2, Far=3, ["Very Far"]=4}
local function renderDistanceChunks()
	local value = Settings.Get("RenderDistance")
	if value == "Auto" then
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and 1 or 2
	end
	return renderDistanceValues[value] or 2
end
local function applyRenderDistance()
	if renderDistanceRemote then renderDistanceRemote:FireServer(renderDistanceChunks()) end
end
-- Apply to authored and streamed prompts too, including old saved structures.
local function interactionKey(instance)
	if instance:IsA("ProximityPrompt") then instance.KeyboardKeyCode = Enum.KeyCode.F end
end
workspace.DescendantAdded:Connect(interactionKey)
game:GetService("ProximityPromptService").PromptShown:Connect(interactionKey)
for _, instance in ipairs(workspace:GetDescendants()) do interactionKey(instance) end
local function effect(instance)
	if not instance:IsA("PostEffect") then return end
	if original[instance] == nil then original[instance] = instance.Enabled end
	instance.Enabled = Settings.Get("PostEffects") and original[instance] or false
end
local function apply()
	Theme.SetMode(Settings.Get("UITheme"))
	Players.LocalPlayer:SetAttribute("ReducedMotion", Settings.Get("ReducedMotion"))
	Lighting.GlobalShadows = Settings.Get("Shadows") and Settings.Get("GraphicsQuality") ~= "Low"
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Settings.Get("FieldOfView")
		for _, child in ipairs(camera:GetChildren()) do effect(child) end
	end
	for _, child in ipairs(Lighting:GetChildren()) do effect(child) end
end
local cameraConnection
local function cameraChanged()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then cameraConnection = camera.ChildAdded:Connect(effect) end
	apply()
end
Lighting.ChildAdded:Connect(effect)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
Settings.Changed:Connect(function(key)
	apply()
	if key == nil or key == "RenderDistance" then applyRenderDistance() end
end)
if isExpedition then
	task.spawn(function()
		renderDistanceRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RenderDistance", 120)
		applyRenderDistance()
	end)
end
cameraChanged()
