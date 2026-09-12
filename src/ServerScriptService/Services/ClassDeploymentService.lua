-- Temporary Builder constructions. Kept outside saved/salvageable player builds.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ClassConfig = require(game:GetService("ReplicatedStorage").Shared.ClassConfig)

local Service = { _active = {}, _byModel = {} }
local COLORS = { Frame = Color3.fromRGB(67, 83, 53), Metal = Color3.fromRGB(112, 119, 99), Amber = Color3.fromRGB(225, 176, 73) }

local function alive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player and player.Parent == Players and not player:GetAttribute("IsDead") and humanoid and humanoid.Health > 0
end

local function root(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
end

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < 1e7
end

local function part(model, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanTouch = true, true, false
	p.Color, p.Material = color or COLORS.Frame, Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function Service:_remove(record)
	if not record then return end
	self._active[record.Owner] = nil
	self._byModel[record.Model] = nil
	if record.Model then record.Model:Destroy() end
end

function Service:RemoveForPlayer(player)
	self:_remove(self._active[player])
end

function Service:Damage(model, damage)
	local record = self._byModel[model]
	if not record or not finite(damage) or damage <= 0 then return false end
	record.Health = math.max(0, record.Health - damage)
	model:SetAttribute("Health", record.Health)
	if record.Health <= 0 then self:_remove(record) end
	return true
end

function Service:_recordFromPart(p)
	while p and p ~= Workspace do
		if self._byModel[p] then return self._byModel[p] end
		p = p.Parent
	end
	return nil
end

-- Ground must be natural terrain, never a station, resource, or another deployment.
function Service:_placement(player, position, rotation, kind)
	if typeof(position) ~= "Vector3" or not finite(position.X) or not finite(position.Y) or not finite(position.Z) then
		return nil, "Choose a valid ground position."
	end
	local characterRoot = root(player.Character)
	if not characterRoot or (characterRoot.Position - position).Magnitude > 16 then return nil, "Place within 16 studs." end
	local half = kind == "Shelter" and 6 or 2
	local height = kind == "Shelter" and 10 or 5
	local angle = finite(rotation) and math.rad(rotation % 360) or 0
	local cf = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = { Workspace.Terrain }
	local lowest, highest = math.huge, -math.huge
	for _, offset in ipairs({ Vector3.zero, Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, half), Vector3.new(half, 0, half) }) do
		local point = cf:PointToWorldSpace(offset)
		local hit = Workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), groundParams)
		if not hit or hit.Material == Enum.Material.Water or hit.Normal.Y < .8 then return nil, "Choose clear, supported ground." end
		lowest, highest = math.min(lowest, hit.Position.Y), math.max(highest, hit.Position.Y)
	end
	if highest - lowest > 2 then return nil, "The ground is too steep." end
	position = Vector3.new(position.X, highest, position.Z)
	if (characterRoot.Position - position).Magnitude > 16 then return nil, "Place within 16 studs." end
	cf = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {}
	for _, obstacle in ipairs(Workspace:GetPartBoundsInBox(cf * CFrame.new(0, height / 2 + .1, 0), Vector3.new(half * 2, height, half * 2), overlap)) do
		if obstacle.CanCollide or obstacle:FindFirstAncestorOfClass("Model") then
			return nil, "Leave room around players, resources, and structures."
		end
	end
	return cf
end

function Service:Activate(player, payload, level)
	if not alive(player) then return false, "You must be alive to deploy." end
	if self._active[player] then return false, "Your previous deployment is still active." end
	if type(payload) ~= "table" then return false, "Choose turret or shelter." end
	local kind = payload.Deployment or payload.Mode or payload.Kind
	if kind ~= "Turret" and kind ~= "Shelter" then return false, "Choose turret or shelter." end
	level = math.clamp(math.floor(tonumber(level) or 1), 1, 5)
	if level < 3 then return false, "Field Deployment unlocks at class level 3." end
	local cf, reason = self:_placement(player, payload.Position, payload.Rotation, kind)
	if not cf then return false, reason end
	local ability = ClassConfig.GetAbility("Builder", level)
	local model = Instance.new("Model")
	model.Name = "Field" .. kind
	model:SetAttribute("ClassDeployment", true)
	model:SetAttribute("DeploymentKind", kind)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Temporary", true)
	local health = kind == "Turret" and ability.TurretHealth or ability.ShelterHealth
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("ExpiresAt", Workspace:GetServerTimeNow() + ability.Duration)
	local record = { Model = model, Owner = player, Kind = kind, Health = health, Expires = os.clock() + ability.Duration, NextShot = 0,
		Damage = ability.Damage, Range = ability.Range }
	if kind == "Turret" then
		model.PrimaryPart = part(model, "Base", Vector3.new(4, .5, 4), cf * CFrame.new(0, .25, 0))
		part(model, "Mast", Vector3.new(1, 3, 1), cf * CFrame.new(0, 2, 0), COLORS.Metal)
		record.Head = part(model, "TurretHead", Vector3.new(2, 1.2, 2), cf * CFrame.new(0, 4, 0))
		record.Barrel = part(model, "Barrel", Vector3.new(.5, .5, 2.5), cf * CFrame.new(0, 4, -1.8), COLORS.Amber)
	else
		model.PrimaryPart = part(model, "Floor", Vector3.new(12, .3, 12), cf * CFrame.new(0, .15, 0))
		part(model, "Roof", Vector3.new(12, .4, 12), cf * CFrame.new(0, 9.8, 0))
		part(model, "BackWall", Vector3.new(12, 9.4, .4), cf * CFrame.new(0, 5, 5.8))
		part(model, "LeftWall", Vector3.new(.4, 9.4, 12), cf * CFrame.new(-5.8, 5, 0))
		part(model, "RightWall", Vector3.new(.4, 9.4, 12), cf * CFrame.new(5.8, 5, 0))
		part(model, "FrontLeft", Vector3.new(3.8, 9.4, .4), cf * CFrame.new(-3.9, 5, -5.8))
		part(model, "FrontRight", Vector3.new(3.8, 9.4, .4), cf * CFrame.new(3.9, 5, -5.8))
		part(model, "DoorLintel", Vector3.new(4, 2.4, .4), cf * CFrame.new(0, 8.5, -5.8))
		local door = part(model, "Door", Vector3.new(4, 7, .4), cf * CFrame.new(-3.9, 3.8, -6.1), COLORS.Amber)
		door.CanCollide, door.CanQuery, door.Transparency = false, false, .55
		model:SetAttribute("DoorOpen", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Close", "Field shelter"
		prompt.KeyboardKeyCode, prompt.HoldDuration = Enum.KeyCode.F, 0
		prompt.RequiresLineOfSight, prompt.MaxActivationDistance = false, 8
		prompt.Parent = door
		prompt.Triggered:Connect(function(visitor)
			local visitorRoot = visitor.Character and root(visitor.Character)
			if not alive(visitor) or not visitorRoot or (visitorRoot.Position - door.Position).Magnitude > 10 or not model.Parent then return end
			local open = not model:GetAttribute("DoorOpen")
			if not open then
				local box = OverlapParams.new()
				box.FilterType, box.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {}
				local characters = {}
				for _, member in ipairs(Players:GetPlayers()) do if member.Character then table.insert(characters, member.Character) end end
				box.FilterDescendantsInstances = characters
				if #Workspace:GetPartBoundsInBox(cf * CFrame.new(0, 3.8, -5.8), Vector3.new(4, 7, 1), box) > 0 then return end
			end
			model:SetAttribute("DoorOpen", open)
			door.CanCollide, door.CanQuery, door.Transparency = not open, not open, open and .55 or 0
			door.CFrame = cf * (open and CFrame.new(-3.9, 3.8, -6.1) or CFrame.new(0, 3.8, -5.8))
			prompt.ActionText = open and "Close" or "Open"
		end)
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name, billboard.Size, billboard.StudsOffset = "DeploymentStatus", UDim2.fromOffset(190, 40), Vector3.new(0, kind == "Shelter" and 11 or 6, 0)
	billboard.MaxDistance, billboard.AlwaysOnTop, billboard.Parent = 70, false, model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), .2
	label.BackgroundColor3, label.TextColor3 = COLORS.Frame, Color3.fromRGB(242, 239, 214)
	label.Font, label.TextSize, label.Parent = Enum.Font.GothamBold, 14, billboard
	record.Label = label
	model.Parent = self._folder or Workspace
	self._active[player], self._byModel[model] = record, record
	return true, kind .. " deployed for 60 seconds."
end

local function ray(origin, target, excluded)
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excluded
	params.RespectCanCollide = true
	return Workspace:Raycast(origin, target - origin, params)
end

function Service:_shoot(record)
	local best, bestDistance = nil, record.Range
	local origin = record.Head.Position
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		local targetRoot, humanoid = root(model), model:FindFirstChildOfClass("Humanoid")
		if targetRoot and humanoid and humanoid.Health > 0 and model:IsDescendantOf(Workspace) then
			local distance = (targetRoot.Position - origin).Magnitude
			if distance <= bestDistance then
				local hit = ray(origin, targetRoot.Position, { record.Model })
				if not hit or hit.Instance:IsDescendantOf(model) then best, bestDistance = model, distance end
			end
		end
	end
	if not best then return end
	local target = root(best).Position
	record.Head.CFrame = CFrame.lookAt(origin, target)
	record.Barrel.CFrame = record.Head.CFrame * CFrame.new(0, 0, -1.8)
	local beam = part(record.Model, "Tracer", Vector3.new(.08, .08, (target - origin).Magnitude), CFrame.lookAt((origin + target) / 2, target), COLORS.Amber)
	beam.CanCollide, beam.CanQuery, beam.Material = false, false, Enum.Material.Neon
	Debris:AddItem(beam, .08)
	require(script.Parent.CombatService):ApplyDamage(record.Owner, best, record.Damage, "ClassTurret")
end

local function nearestPoint(p, position)
	local localPosition = p.CFrame:PointToObjectSpace(position)
	local h = p.Size / 2
	return p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPosition.X, -h.X, h.X), math.clamp(localPosition.Y, -h.Y, h.Y), math.clamp(localPosition.Z, -h.Z, h.Z)))
end

-- Called before every hostile AI class, including Wolf's independent Step override.
function Service:StepEnemy(controller)
	if not controller.Root or not controller:IsAlive() then return false end
	if controller.Config.EntityType ~= "Monster" then return false end
	local now = os.clock()
	local model = controller.Model
	local tauntUntil = tonumber(model:GetAttribute("ClassTauntUntil")) or 0
	local taunted = false
	if tauntUntil > now and not model:GetAttribute("IsBoss") and not model:GetAttribute("Boss") and not CollectionService:HasTag(model, "Boss") then
		local userId = tonumber(model:GetAttribute("ClassTauntUserId"))
		local player = userId and Players:GetPlayerByUserId(userId)
		if alive(player) then
			controller.Target, taunted = player, true
			controller._classTauntActive = true
		end
	end
	if not taunted and controller._classTauntActive then
		controller._classTauntActive = nil
		controller:AcquireTarget()
	end
	if not controller:IsTargetValid() then controller:AcquireTarget() end
	local targetPart, targetRecord
	local character = controller.Target and controller.Target.Character
	local targetRoot = character and root(character)
	if targetRoot then
		local hit = ray(controller.Root.Position, targetRoot.Position, { model })
		local record = hit and self:_recordFromPart(hit.Instance)
		if record and record.Kind == "Shelter" then targetPart, targetRecord = hit.Instance, record end
	end
	if not targetRecord and not taunted then
		local closest = math.min(tonumber(controller.Config.DetectionDistance) or 60, 60)
		for _, record in pairs(self._active) do
			if record.Kind == "Turret" and record.Model.Parent then
				local distance = (record.Head.Position - controller.Root.Position).Magnitude
				if distance < closest then
					local hit = ray(controller.Root.Position, record.Head.Position, { model })
					if not hit or hit.Instance:IsDescendantOf(record.Model) then
						closest, targetPart, targetRecord = distance, record.Model.PrimaryPart, record
					end
				end
			end
		end
	end
	if not targetPart then return false end
	local point = nearestPoint(targetPart, controller.Root.Position)
	local distance = (point - controller.Root.Position).Magnitude
	controller:SetSpeed(controller:GetMoveSpeed())
	if distance <= (tonumber(controller.Config.AttackRange) or 4) then
		controller:MoveTo(controller.Root.Position)
		if now >= (controller.NextAttack or 0) then
			local hit = ray(controller.Root.Position, point, { model })
			if not hit or hit.Instance:IsDescendantOf(targetRecord.Model) then
				controller.NextAttack = now + (controller.Config.AttackCooldown or 1.2)
				self:Damage(targetRecord.Model, tonumber(controller.Config.Damage) or 8)
			end
		end
	else
		controller:UpdatePath(point)
		controller:FollowPath()
	end
	return true
end

function Service:Init()
	if self._initialized then return end
	self._initialized = true
	self._folder = Instance.new("Folder")
	self._folder.Name, self._folder.Parent = "ClassDeployments", Workspace
	Players.PlayerRemoving:Connect(function(player) self:RemoveForPlayer(player) end)
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.BiomeChangedCallbacks = _G.Ecoshift.BiomeChangedCallbacks or {}
	table.insert(_G.Ecoshift.BiomeChangedCallbacks, function()
		local records = table.clone(self._active)
		for _, record in pairs(records) do self:_remove(record) end
	end)
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, record in pairs(self._active) do
				if not alive(record.Owner) or not record.Model.Parent or now >= record.Expires then
					self:_remove(record)
				else
					local remaining = math.max(0, math.ceil(record.Expires - now))
					record.Label.Text = record.Kind .. "  " .. math.ceil(record.Health) .. " HP  ·  " .. remaining .. "s"
					record.Label.TextColor3 = remaining <= 5 and math.floor(now * 4) % 2 == 0 and Color3.fromRGB(255, 135, 85) or Color3.fromRGB(242, 239, 214)
					if record.Kind == "Turret" and now >= record.NextShot then
						record.NextShot = now + 1
						self:_shoot(record)
					end
				end
			end
			task.wait(.2)
		end
	end)
end

return Service
