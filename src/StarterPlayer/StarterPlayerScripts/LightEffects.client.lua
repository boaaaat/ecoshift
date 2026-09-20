-- Cosmetics are client-only: graphics quality never changes a fixture's useful light radius.
local Collection = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("LightConfig"))
local Settings = require(Shared:WaitForChild("ClientSettings"))
local sources, active = {}, {}
local quality, reducedMotion, shadows
local elapsed, scanTime = 0, 0
local budgets = {
	Medium = { Distance = 85, Count = 24, Rate = 4 },
	High = { Distance = 150, Count = 40, Rate = 10 },
}

local function removeEffects(source)
	local effect = active[source]
	if not effect then return end
	active[source] = nil
	for _, rotor in ipairs(effect.Rotors) do
		if rotor.Model.Parent then rotor.Model:PivotTo(rotor.Origin) end
	end
	for _, object in ipairs(effect.Objects) do
		if object:IsA("Attachment") then
			for _, emitter in ipairs(object:GetChildren()) do
				if emitter:IsA("ParticleEmitter") then emitter.Enabled = false; emitter:Clear() end
			end
		end
		object:Destroy()
	end
end

local function makeEmitter(attachment, def, rate, isFlame)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LightMotes"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(def.Color, def.Accent)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(.5, isFlame and 1.1 or 1.8)
	emitter.Speed = NumberRange.new(isFlame and .9 or .25, isFlame and 2 or .7)
	emitter.Acceleration = Vector3.new(0, isFlame and 1 or .25, 0)
	emitter.SpreadAngle = Vector2.new(isFlame and 20 or 110, isFlame and 20 or 110)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .04),
		NumberSequenceKeypoint.new(.25, isFlame and .13 or .18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.15, .15),
		NumberSequenceKeypoint.new(.65, .35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return emitter
end

local function addEffects(source, model, def, budget)
	local effect = { Objects = {}, Rotors = {}, Started = elapsed }
	active[source] = effect
	local attachment = Instance.new("Attachment")
	attachment.Name = "LocalLightEffects"
	attachment.Position = Vector3.new(0, source.Size.Y * .35, 0)
	attachment.Parent = source
	table.insert(effect.Objects, attachment)
	makeEmitter(attachment, def, budget.Rate, def.Effect == "Flame")
	if quality == "High" then
		if def.Effect == "Flame" then
			local fire = Instance.new("Fire")
			fire.Name = "LocalTorchFlame"
			fire.Color, fire.SecondaryColor = def.Color, def.Accent
			fire.Size, fire.Heat = def.FlameSize, 3
			fire.Parent = source
			table.insert(effect.Objects, fire)
		elseif def.Grade >= 4 then
			-- Rare fixtures get a second, slow field of glints around their core.
			local glints = makeEmitter(attachment, def, 3, false)
			glints.Name = "RareLightGlints"
			glints.Speed = NumberRange.new(.7, 1.2)
			glints.Lifetime = NumberRange.new(1.2, 2.2)
			glints.SpreadAngle = Vector2.new(180, 180)
		end
		if not reducedMotion then
			for _, child in ipairs(model:GetChildren()) do
				local speed = child:GetAttribute("LightOrbitSpeed")
				if child:IsA("Model") and type(speed) == "number" then
					table.insert(effect.Rotors, { Model = child, Origin = child:GetPivot(), Speed = speed })
				end
			end
		end
	end
end

local function reconcile()
	local budget = budgets[quality]
	local camera = workspace.CurrentCamera
	local candidates = {}
	for source in pairs(sources) do
		local def = Config.Definitions[source:GetAttribute("LightId")]
		local model = source.Parent
		if def and source:IsDescendantOf(workspace) and model and model:IsA("Model")
			and model:GetAttribute("BuildType") == def.Id and Collection:HasTag(model, "Structure") then
			local lamp = source:FindFirstChild("FixtureLight")
			if lamp and lamp:IsA("PointLight") then lamp.Shadows = shadows and quality ~= "Low" end
			if budget and camera then
				local distance = (camera.CFrame.Position - source.Position).Magnitude
				if distance <= budget.Distance then
					table.insert(candidates, { Source = source, Model = model, Def = def, Distance = distance })
				end
			end
		end
	end
	table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
	local wanted = {}
	for i = 1, math.min(#candidates, budget and budget.Count or 0) do
		local candidate = candidates[i]
		wanted[candidate.Source] = true
		if not active[candidate.Source] then addEffects(candidate.Source, candidate.Model, candidate.Def, budget) end
	end
	for source in pairs(active) do if not wanted[source] then removeEffects(source) end end
end

local function register(source)
	if source:IsA("BasePart") then sources[source] = true; scanTime = .25 end
end
Collection:GetInstanceAddedSignal(Config.SourceTag):Connect(register)
Collection:GetInstanceRemovedSignal(Config.SourceTag):Connect(function(source)
	sources[source] = nil
	removeEffects(source)
end)
for _, source in ipairs(Collection:GetTagged(Config.SourceTag)) do register(source) end

local function refreshSettings(key)
	if key and key ~= "GraphicsQuality" and key ~= "ReducedMotion" and key ~= "Shadows" then return end
	local nextQuality = Settings.Get("GraphicsQuality")
	local nextMotion = Settings.Get("ReducedMotion") == true
	if nextQuality ~= quality or nextMotion ~= reducedMotion then
		for source in pairs(active) do removeEffects(source) end
	end
	quality, reducedMotion, shadows = nextQuality, nextMotion, Settings.Get("Shadows") == true
	reconcile()
end
Settings.Changed:Connect(refreshSettings)
refreshSettings()

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	scanTime += dt
	if scanTime >= .25 then scanTime = 0; reconcile() end
	for source, effect in pairs(active) do
		if not source:IsDescendantOf(workspace) then
			removeEffects(source)
		else
			for _, rotor in ipairs(effect.Rotors) do
				if rotor.Model.Parent then
					rotor.Model:PivotTo(rotor.Origin * CFrame.Angles(0, (elapsed - effect.Started) * rotor.Speed, 0))
				end
			end
		end
	end
end)
