if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- Restrained edge damage feedback; health itself lives in the shared vitals card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerHealthUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
local edges = {}
for _, right in ipairs({false, true}) do
	local edge = Instance.new("Frame")
	edge.Name = right and "RightDamageEdge" or "LeftDamageEdge"
	edge.Size = UDim2.fromScale(0.1, 1)
	edge.Position = UDim2.fromScale(right and 0.9 or 0, 0)
	edge.BackgroundColor3 = Theme.Colors.Danger
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, right and 1 or 0), NumberSequenceKeypoint.new(1, right and 0 or 1) })
	gradient.Parent = edge
	table.insert(edges, edge)
end
local connection
local function bindCharacter(character)
	if connection then connection:Disconnect() end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local previous = humanoid.Health
	connection = humanoid.HealthChanged:Connect(function(value)
		if value < previous then
			for _, edge in ipairs(edges) do
				edge.BackgroundTransparency = 0.3
				Theme.Tween(edge, { BackgroundTransparency = 1 }, 0.6)
			end
		end
		previous = value
	end)
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end
