if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- Local weather presentation; damage and resistance remain server-authoritative.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Settings = require(ReplicatedStorage.Shared.ClientSettings)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "EcoShiftWeather"
atmosphere.Density, atmosphere.Haze = 0.18, 0.5
atmosphere.Parent = Lighting
local correction = Instance.new("ColorCorrectionEffect")
correction.Name = "EcoShiftWeather"
correction.Parent = Lighting
local emitterPart = Instance.new("Part")
emitterPart.Name = "LocalWeather"
emitterPart.Anchored, emitterPart.CanCollide, emitterPart.CanQuery, emitterPart.CanTouch = true, false, false, false
emitterPart.Transparency, emitterPart.Size = 1, Vector3.new(60, 1, 60)
emitterPart.Parent = workspace
local particles = Instance.new("ParticleEmitter")
particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
particles.EmissionDirection = Enum.NormalId.Bottom
particles.Lifetime = NumberRange.new(1.2, 2)
particles.Speed = NumberRange.new(20, 28)
particles.SpreadAngle = Vector2.new(8, 8)
particles.Rate = 0
particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
particles.Parent = emitterPart
local styles = {
	Clear = {0.18, 0.5, Color3.fromRGB(224, 230, 210)},
	Overcast = {0.27, 1, Color3.fromRGB(176, 190, 181)},
	Fog = {0.38, 2, Color3.fromRGB(187, 211, 185)},
	Rain = {0.3, 1.4, Color3.fromRGB(163, 191, 200), 110},
	SporeFog = {0.4, 2.5, Color3.fromRGB(173, 190, 113), 25},
	Heatwave = {0.26, 1.8, Color3.fromRGB(239, 205, 158)},
	Sandstorm = {0.4, 2.5, Color3.fromRGB(216, 176, 121), 90},
	Snow = {0.28, 1.3, Color3.fromRGB(192, 216, 235), 60},
	Blizzard = {0.4, 2.5, Color3.fromRGB(191, 208, 226), 130},
	Ashfall = {0.32, 1.8, Color3.fromRGB(192, 169, 159), 65},
	Emberstorm = {0.38, 2.3, Color3.fromRGB(225, 159, 105), 100},
	CrystalHaze = {0.32, 2, Color3.fromRGB(198, 183, 225), 25},
	StaticStorm = {0.38, 2.2, Color3.fromRGB(174, 163, 220), 80},
	DawnSurge = {0.27, 1.8, Color3.fromRGB(174, 233, 189), 25},
	PolarNight = {0.33, 2, Color3.fromRGB(143, 173, 224), 50},
	MeteorShower = {0.31, 2, Color3.fromRGB(230, 177, 123), 65},
	CosmicHaze = {0.38, 2.3, Color3.fromRGB(174, 150, 207), 40},
}
local current
local weatherRate = 0
local function applyQuality()
	local multiplier = ({ Low = 0.2, Medium = 0.5, High = 1 })[Settings.Get("GraphicsQuality")] or 1
	particles.Rate = Settings.Get("WeatherParticles") and weatherRate * multiplier or 0
	if particles.Rate == 0 then particles:Clear() end
end
Settings.Changed:Connect(applyQuality)
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameStateUpdate").OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or current == state.WeatherId then return end
	current = state.WeatherId
	local style = styles[current] or styles.Clear
	TweenService:Create(atmosphere, TweenInfo.new(3), {Density = style[1], Haze = style[2], Color = style[3]}):Play()
	TweenService:Create(correction, TweenInfo.new(3), {TintColor = Color3.new(1, 1, 1):Lerp(style[3], 0.15)}):Play()
	weatherRate = style[4] or 0
	applyQuality()
	particles.Color = ColorSequence.new(style[3])
	particles.Size = NumberSequence.new(current == "Rain" and 0.08 or 0.18)
	particles.Speed = current == "Rain" and NumberRange.new(30, 38) or NumberRange.new(5, 10)
end)
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if camera then emitterPart.Position = camera.CFrame.Position + Vector3.new(0, 16, 0) end
end)
