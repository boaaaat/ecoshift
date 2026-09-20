-- Authored silhouettes and motion, shared by bow, projectile and impact effects.
-- Only the small arrow body is made on the server. Animated effects are client-owned.
local Visuals = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local TAU = math.pi * 2
local WHITE = Color3.fromRGB(255, 249, 226)
local profiles = {
	HuntingBow = { Kind = "Feather", Tier = 1, Color = Color3.fromRGB(224, 205, 157), Accent = Color3.fromRGB(147, 112, 73), Width = .035, Tail = .12 },
	MarshBow = { Kind = "Wisp", Tier = 2, Color = Color3.fromRGB(147, 239, 164), Accent = Color3.fromRGB(53, 166, 151), Width = .055, Tail = .24 },
	DawnBow = { Kind = "Sun", Tier = 4, Color = Color3.fromRGB(255, 229, 136), Accent = Color3.fromRGB(255, 121, 47), Width = .075, Tail = .3 },
	StormBow = { Kind = "Storm", Tier = 5, Color = Color3.fromRGB(176, 247, 255), Accent = Color3.fromRGB(111, 132, 255), Width = .08, Tail = .22 },
	IronwoodBow = { Kind = "Thorn", Tier = 6, Color = Color3.fromRGB(181, 255, 127), Accent = Color3.fromRGB(235, 178, 73), Width = .09, Tail = .38 },
	StarBow = { Kind = "Star", Tier = 8, Color = Color3.fromRGB(239, 221, 255), Accent = Color3.fromRGB(135, 113, 255), Width = .1, Tail = .48 },
	CrystalBow = { Kind = "Star", Tier = 7, Color = Color3.fromRGB(178, 238, 255), Accent = Color3.fromRGB(172, 135, 255), Width = .08, Tail = .4 },
}

function Visuals.Profile(id, grade)
	if profiles[id] then return profiles[id] end
	local tier = tonumber(grade) or 1
	return profiles[tier >= 7 and "StarBow" or tier >= 6 and "IronwoodBow" or tier >= 5 and "StormBow" or tier >= 4 and "DawnBow" or tier >= 2 and "MarshBow" or "HuntingBow"]
end

local function part(parent, name, size, frame, color, material, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Color, p.Material = color, material or Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

function Visuals.CreateArrow(id, grade, special, origin, direction)
	local p = Visuals.Profile(id, grade)
	local model = Instance.new("Model")
	model.Name = id .. (special and " Piercing Arrow" or " Arrow")
	local frame = CFrame.lookAt(origin, origin + direction)
	local shaft = part(model, "Shaft", V(.09, .09, 2.7), frame, Color3.fromRGB(101, 74, 51), Enum.Material.Wood)
	model.PrimaryPart = shaft
	local radiant = p.Tier >= 4
	part(model, "Broadhead", V(.3, .5, .12), frame * CF(0, 0, -1.5) * A(math.pi / 2, 0, 0), p.Color, Enum.Material.Metal, "WedgePart")
	for i = 1, (p.Kind == "Star" and 4 or 3) do
		local rotation = A(0, 0, i * TAU / (p.Kind == "Star" and 4 or 3))
		part(model, "Fletching", V(.055, .32, .65), frame * rotation * CF(0, .17, 1.04), p.Accent, radiant and Enum.Material.Neon or Enum.Material.SmoothPlastic, "WedgePart")
	end
	if radiant then
		part(model, "EnergySpine", V(.055, .055, 2.4), frame * CF(0, .07, -.1), p.Color)
	end
	if p.Kind == "Thorn" or p.Kind == "Storm" then
		for side = -1, 1, 2 do
			part(model, "BarbedHead", V(.12, .44, .14), frame * CF(side * .21, 0, -1.2) * A(math.pi / 2, side * .55, 0), p.Accent, Enum.Material.Metal, "WedgePart")
		end
	end
	model:SetAttribute("BowVisualId", id)
	model:SetAttribute("BowVisualGrade", grade)
	model:SetAttribute("BowVisualSpecial", special)
	model:SetAttribute("BowInFlight", true)
	return model
end

local function attachment(root, position)
	local a = Instance.new("Attachment")
	a.Position, a.Parent = position or Vector3.zero, root
	return a
end

local function line(state, color, width)
	local a, b = attachment(state.Root), attachment(state.Root)
	local beam = Instance.new("Beam")
	beam.Name = "BowEnergy"
	beam.Attachment0, beam.Attachment1 = a, b
	beam.Color, beam.Width0, beam.Width1 = ColorSequence.new(color), width, width
	beam.FaceCamera, beam.LightEmission, beam.Segments = true, 1, 1
	beam.Parent = state.Root
	local edge = { A = a, B = b, Beam = beam, Width = width }
	return edge
end

local function draw(edge, a, b, opacity, width)
	edge.A.Position, edge.B.Position = a, b
	local alpha = math.floor(math.clamp(opacity or 1, 0, 1) * 40 + .5) / 40
	if edge.Alpha ~= alpha then
		edge.Alpha = alpha
		edge.Beam.Transparency = NumberSequence.new(1 - alpha)
	end
	local thickness = edge.Width * (width or 1)
	if edge.Thickness ~= thickness then
		edge.Thickness = thickness
		edge.Beam.Width0, edge.Beam.Width1 = thickness, thickness
	end
end

local function path(state, count, color, width)
	local edges = {}
	for i = 1, count do edges[i] = line(state, color, width) end
	return edges
end

local function curve(edges, sample, opacity, width)
	local previous = sample(0)
	for i, edge in ipairs(edges) do
		local nextPoint = sample(i / #edges)
		draw(edge, previous, nextPoint, opacity, width)
		previous = nextPoint
	end
end

local function circle(edges, radius, frame, phase, opacity, width, sweep)
	curve(edges, function(u)
		local theta = phase + u * (sweep or TAU)
		return frame:PointToWorldSpace(V(math.cos(theta) * radius, math.sin(theta) * radius, 0))
	end, opacity, width)
end

local function tail(state, width, lifetime, color)
	local a, b = attachment(state.Root, V(-width / 2, 0, 1)), attachment(state.Root, V(width / 2, 0, 1))
	local trail = Instance.new("Trail")
	trail.Name = "BowWake"
	trail.Attachment0, trail.Attachment1, trail.FaceCamera = a, b, true
	trail.Lifetime, trail.MinLength, trail.LightEmission = lifetime, .04, 1
	trail.Color = ColorSequence.new(color, state.Profile.Accent)
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.3, .65), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new(.15, 1)
	trail.Parent = state.Root
	return { A = a, B = b, Trail = trail, Width = width }
end

local function seed(state, color, size, shape)
	local p = part(state.Root, "OrbitSeed", Vector3.one * size, state.Root.CFrame, color, nil, shape == "Leaf" and "WedgePart" or nil)
	if shape == "Leaf" then p.Size = V(size * .45, size * 1.8, size)
	else p.Shape = Enum.PartType.Ball end
	return p
end

local function stateRoot(parent, profile, frame)
	local root = part(parent, "BowEffects_" .. profile.Kind, Vector3.one * .05, frame, profile.Color)
	root.Transparency = 1
	local state = { Root = root, Profile = profile }
	function state:Destroy() self.Root:Destroy() end
	return state
end

-- Persistent motifs are deliberately different geometries, not identical recolored emitters.
function Visuals.Attach(source, id, grade, mode, special, quality, parent)
	local p = Visuals.Profile(id, grade)
	local state = stateRoot(parent, p, source.CFrame)
	local flight, low = mode == "Flight", quality < .6
	local count = low and 10 or 16
	local scale = (special and 1.35 or 1) * (1 + math.max(0, (grade or p.Tier) - p.Tier) * .07)
	local paths, seeds, tails = {}, {}, {}
	local function addPath(n, color, width)
		local result = path(state, n, color or p.Color, width or p.Width)
		paths[#paths + 1] = result
		return result
	end
	local span = 2.3
	if not flight then
		-- Account for custom prefab scales while keeping effect geometry bounded.
		local extent = 0
		for _, child in ipairs(source.Parent:GetDescendants()) do
			if child:IsA("BasePart") then
				extent = math.max(extent, math.abs(source.CFrame:PointToObjectSpace(child.Position).Y) + child.Size.Y * .5)
			end
		end
		span = math.clamp(extent, 1.5, 3)
		state.Strings = { line(state, p.Color, .025), line(state, p.Color, .025) }
	end
	if flight then
		tails[1] = tail(state, (.07 + p.Tier * .026) * scale, p.Tail, p.Color)
	end
	if p.Kind == "Feather" then
		addPath(5)
		for i = 1, 3 do seeds[i] = seed(state, p.Color, .09, "Leaf") end
	elseif p.Kind == "Wisp" then
		addPath(count, p.Accent, .03)
		for i = 1, (low and 2 or 4) do
			seeds[i] = seed(state, i % 2 == 0 and p.Accent or p.Color, .1)
			if flight then tails[#tails + 1] = tail(state, .06, .3, p.Accent) end
		end
	elseif p.Kind == "Sun" then
		addPath(count, p.Accent, .055)
		addPath(count, p.Color, .035)
		for i = 1, (low and 6 or 10) do addPath(1, i % 2 == 0 and p.Accent or p.Color, .075) end
	elseif p.Kind == "Storm" then
		for i = 1, (low and 2 or 3) do addPath(7, i == 1 and WHITE or p.Accent, i == 1 and .055 or .035) end
		for i = 1, 2 do addPath(3, p.Color, .035) end
	elseif p.Kind == "Thorn" then
		addPath(count, p.Color, .075)
		addPath(count, p.Accent, .045)
		for i = 1, (low and 4 or 8) do seeds[i] = seed(state, i % 2 == 0 and p.Accent or p.Color, .16, "Leaf") end
		addPath(count, p.Accent, .04)
	elseif p.Kind == "Star" then
		for i = 1, (low and 2 or 3) do addPath(count, i == 2 and p.Color or p.Accent, .04 + i * .009) end
		for i = 1, (low and 3 or 6) do
			seeds[i] = seed(state, p.Color, i % 2 == 0 and .12 or .18)
			addPath(2, p.Color, .025)
		end
		state.OrbitCount = low and 2 or 3
		if flight then
			tails[2] = tail(state, .11, .45, p.Accent)
			tails[3] = tail(state, .11, .45, p.Color)
		end
	end
	if p.Tier >= 4 and not low then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = p.Color, 5 + p.Tier * .4, .5, false
		light.Parent = state.Root
		state.Light = light
	end
	function state:Update(time, charge)
		self.Root.CFrame = source.CFrame
		charge = charge or 0
		local strength = flight and 1 or .25 + charge * .75
		local radius = (flight and .3 + p.Tier * .025 or .52 + charge * .28) * scale
		if p.Kind == "Star" and not flight then radius = (span * .55 + charge * .35) * scale end
		local frame = flight and CF(0, 0, -.5) or CF(.17, 0, -.25)
		local opacity = flight and .85 or .25 + charge * .7
		if self.Light then self.Light.Brightness = strength * (.4 + p.Tier * .09) end
		if self.Strings then
			local nock = V(.17 - charge * .55, 0, 0)
			draw(self.Strings[1], V(.17, span, 0), nock, .35 + charge * .6)
			draw(self.Strings[2], nock, V(.17, -span, 0), .35 + charge * .6)
		end
		if p.Kind == "Feather" then
			circle(paths[1], radius, frame * A(0, .6, .3), time * 1.7, opacity * .55, 1, math.pi * .75)
			for i, leaf in ipairs(seeds) do
				local u = (time * .6 + i / 3) % 1
				leaf.CFrame = self.Root.CFrame * frame * CF((i - 2) * .23, .12 * math.sin(u * TAU), flight and .8 + u * 1.4 or -u * .8) * A(u * 3, 0, i)
				leaf.Transparency = 1 - math.sin(u * math.pi) * strength * .7
			end
		elseif p.Kind == "Wisp" then
			curve(paths[1], function(u)
				local angle = u * TAU + time * 1.4
				return frame:PointToWorldSpace(V(math.sin(angle) * radius, math.sin(angle * 2) * radius * .65, flight and u * 1.9 or 0))
			end, opacity * .5)
			for i, mote in ipairs(seeds) do
				local angle = time * (1.2 + i * .12) + i * TAU / #seeds
				local pos = V(math.sin(angle) * radius, math.sin(angle * 2) * radius * .8, flight and .8 + i * .32 or math.cos(angle) * .3)
				mote.CFrame = self.Root.CFrame * frame * CF(pos)
				mote.Transparency = .15 + (1 - strength) * .5
				if tails[i + 1] then
					tails[i + 1].A.Position = pos - V(.03, 0, 0)
					tails[i + 1].B.Position = pos + V(.03, 0, 0)
				end
			end
		elseif p.Kind == "Sun" then
			circle(paths[1], radius, frame, time * .5, opacity)
			circle(paths[2], radius * 1.3, frame * A(.4, 0, 0), -time * .8, opacity * .7, 1, TAU * .8)
			for i = 3, #paths do
				local angle = (i - 3) * TAU / (#paths - 2) + time * .5
				local ray = V(math.cos(angle), math.sin(angle), 0)
				local length = radius * (1.4 + .35 * math.sin(time * 4 + i))
				draw(paths[i][1], frame:PointToWorldSpace(ray * radius), frame:PointToWorldSpace(ray * length + V(0, 0, flight and .55 or 0)), opacity, strength)
			end
		elseif p.Kind == "Storm" then
			local tick = math.floor(time * 14)
			for j, edges in ipairs(paths) do
				curve(edges, function(u)
					local jag = math.sin(u * 94 + tick * 13 + j * 7) * math.sin(u * math.pi)
					if flight then return V(jag * radius + (j - 2) * .16, math.cos(u * 83 + tick + j) * radius * math.sin(u * math.pi), -1.3 + u * (j > 3 and 1.5 or 3.5)) end
					return V(.17 + jag * radius, (u * 2 - 1) * span * (j > 3 and .6 or 1), math.sin(u * 61 + tick) * radius * .5)
				end, opacity * (j == 1 and 1 or .55), strength)
			end
		elseif p.Kind == "Thorn" then
			for j = 1, 2 do
				curve(paths[j], function(u)
					local angle = u * TAU * 1.5 + time * 1.8 + j * math.pi
					if flight then return V(math.cos(angle) * radius, math.sin(angle) * radius, -1.2 + u * 3) end
					return V(.17 + math.cos(angle) * radius * .55, (u * 2 - 1) * span, math.sin(angle) * radius * .55)
				end, opacity)
			end
			for i, leaf in ipairs(seeds) do
				local u, angle = i / (#seeds + 1), i / (#seeds + 1) * TAU * 1.5 + time * 1.8
				local pos = flight and V(math.cos(angle) * radius, math.sin(angle) * radius, -1.2 + u * 3) or V(.17 + math.cos(angle) * radius * .55, (u * 2 - 1) * span, math.sin(angle) * radius * .55)
				leaf.CFrame = self.Root.CFrame * CF(pos) * A(angle, time + i, .6)
				leaf.Transparency = 1 - opacity
			end
			circle(paths[3], radius * 1.25, frame * A(0, time * .4, .5), -time, opacity * .5)
		elseif p.Kind == "Star" then
			for j = 1, self.OrbitCount do
				circle(paths[j], radius * (1 + j * .22), frame * A(j * .7, time * .25 + j, time * .2), time * (j % 2 == 0 and -1 or 1), opacity, 1, TAU * .88)
			end
			for i, star in ipairs(seeds) do
				local angle = time * (i % 2 == 0 and -1.6 or 1.1) + i * TAU / #seeds
				local orbit = frame * A(i * .7, time * .25 + i, time * .2)
				local pos = orbit:PointToWorldSpace(V(math.cos(angle) * radius * 1.5, math.sin(angle) * radius * 1.5, 0))
				star.CFrame, star.Transparency = self.Root.CFrame * CF(pos), 1 - opacity
				local edges = paths[self.OrbitCount + i]
				draw(edges[1], pos - V(.16, 0, 0), pos + V(.16, 0, 0), opacity)
				draw(edges[2], pos - V(0, .16, 0), pos + V(0, .16, 0), opacity)
			end
			for i = 2, #tails do
				local angle = time * 8 + i * math.pi
				local pos = V(math.cos(angle) * radius, math.sin(angle) * radius, 1)
				tails[i].A.Position, tails[i].B.Position = pos - V(.055, 0, 0), pos + V(.055, 0, 0)
			end
		end
	end
	function state:Stop()
		-- Let the existing wake dissolve at the final position instead of popping.
		for _, wake in ipairs(tails) do wake.Trail.Enabled = false end
		for _, child in ipairs(self.Root:GetDescendants()) do
			if child:IsA("Beam") then child.Enabled = false
			elseif child:IsA("BasePart") then child.Transparency = 1
			elseif child:IsA("PointLight") then child.Enabled = false end
		end
		self.Duration = .55
		self.Update = function() end
	end
	return state
end

-- Impact choreography: feathers scatter, marsh bubbles rise, sun rays erupt,
-- lightning branches, roots grow, and the highest tier collapses before exploding.
function Visuals.Burst(id, grade, special, position, normal, release, quality, parent)
	local p = Visuals.Profile(id, grade)
	local state = stateRoot(parent, p, CFrame.lookAt(position, position + (normal.Magnitude > .01 and normal.Unit or Vector3.yAxis)))
	local low = quality < .6
	local count = low and 8 or 14
	local scale = (release and .45 or 1) * (special and 1.4 or 1)
	local radius = (.65 + p.Tier * .34) * scale
	state.Duration = release and .35 or p.Kind == "Star" and 1.15 or p.Kind == "Thorn" and 1 or .75
	local rings, rays, seeds = {}, {}, {}
	local ringCount = p.Kind == "Star" and 3 or p.Kind == "Wisp" and 2 or p.Kind == "Sun" and 2 or 0
	for i = 1, ringCount do rings[i] = path(state, count, i % 2 == 0 and p.Accent or p.Color, .045 + p.Tier * .009) end
	local rayCount = p.Kind == "Feather" and 5 or p.Kind == "Wisp" and 6 or low and 7 or 12
	for i = 1, rayCount do
		if p.Kind == "Storm" or p.Kind == "Thorn" then rays[i] = path(state, 4, i % 2 == 0 and p.Accent or p.Color, p.Kind == "Thorn" and .09 or .055)
		else rays[i] = path(state, 1, p.Color, .055) end
		seeds[i] = seed(state, i % 2 == 0 and p.Accent or p.Color, p.Kind == "Feather" and .1 or .15, (p.Kind == "Thorn" or p.Kind == "Feather") and "Leaf" or nil)
	end
	local core
	if p.Kind == "Star" then
		core = seed(state, Color3.fromRGB(38, 24, 68), .6)
		core.Material = Enum.Material.SmoothPlastic
	end
	function state:Update(age)
		local u = math.clamp(age / self.Duration, 0, 1)
		local fade = (1 - u) ^ 1.4
		local growth = 1 - (1 - u) ^ 3
		local nova = p.Kind == "Star" and math.clamp((u - .25) / .75, 0, 1) or u
		if core then
			core.Size = Vector3.one * math.max(.05, u < .25 and 1.1 * (1 - u * 3) * scale or (1 + nova * 6) * scale)
			core.Color = u < .25 and Color3.fromRGB(38, 24, 68) or p.Color
			core.Material = u < .25 and Enum.Material.SmoothPlastic or Enum.Material.Neon
			core.Transparency = u < .25 and .15 or .6 + nova * .4
			core.CFrame = self.Root.CFrame
		end
		for i, ring in ipairs(rings) do
			local r = radius * growth * (1 + i * .2)
			local frame = CF(0, 0, -.06 - i * .07)
			if p.Kind == "Wisp" then r = radius * math.clamp((u - (i - 1) * .15) * 2, 0, 1)
			elseif p.Kind == "Star" then
				r = radius * (u < .25 and (1 - u * 3) or .25 + nova * (1 + i * .5))
				frame *= A(i * .6, i * .8, age)
			end
			circle(ring, math.max(.03, r), frame, i + age, fade, 1 - u * .7)
		end
		for i, edges in ipairs(rays) do
			local angle = i * TAU / #rays
			local direction = V(math.cos(angle), math.sin(angle), -.2 - (i % 3) * .2)
			local point = direction * radius * growth
			if p.Kind == "Feather" then
				point += self.Root.CFrame:VectorToObjectSpace(V(0, -u * u, 0))
				draw(edges[1], point * .8, point, fade * .5)
			elseif p.Kind == "Wisp" then
				point += self.Root.CFrame:VectorToObjectSpace(V(math.sin(age * 5 + i) * .2, u * 2.5, 0))
				draw(edges[1], point, point + V(.04, .08, 0), fade * .5)
			elseif p.Kind == "Storm" or p.Kind == "Thorn" then
				curve(edges, function(t)
					local jag = math.sin(t * 19 + i * 8 + (p.Kind == "Storm" and math.floor(age * 18) or 0)) * math.sin(t * math.pi)
					return direction * radius * growth * t + V(-direction.Y, direction.X, 0) * jag * .45 + V(0, 0, p.Kind == "Thorn" and -math.sin(t * math.pi) * .6 or 0)
				end, fade, 1 - u * .5)
			else
				if p.Kind == "Star" then point = direction * radius * (u < .25 and (1 - u * 3) or .25 + nova * 1.7) end
				draw(edges[1], point * (p.Kind == "Sun" and .35 or .8), point, fade)
			end
			local s = seeds[i]
			s.CFrame = self.Root.CFrame * CF(point) * A(age * 4 + i, i, age * 3)
			s.Transparency = 1 - fade
			if p.Kind == "Wisp" then s.Size = Vector3.one * (.1 + growth * .18) end
		end
	end
	return state
end

function Visuals.Chain(from, to, parent)
	local state = stateRoot(parent, profiles.StormBow, CFrame.lookAt(from, to))
	local length = (to - from).Magnitude
	local edges = path(state, 9, profiles.StormBow.Color, .09)
	state.Duration = .28
	function state:Update(age)
		curve(edges, function(u)
			local jitter = math.sin(u * math.pi) * .65
			return V(math.sin(u * 93 + math.floor(age * 20)) * jitter, math.cos(u * 71) * jitter, -length * u)
		end, 1 - age / self.Duration)
	end
	return state
end

return Visuals
