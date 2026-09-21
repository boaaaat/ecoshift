local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
if require(Shared:WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Visuals = require(Shared.Weapons.BowVisuals)
local SpecialVisuals = require(Shared.Weapons.BowSpecialVisuals)
local Settings = require(Shared.ClientSettings)
local localPlayer = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "LocalBowEffects", workspace
local active, bursts, arrows = {}, {}, {}
local zones, zoneEffects = {}, {}
local quality = 1
local projectileFolder
local specialFolder
local dirty = true
local MAX_ACTIVE, MAX_BURSTS = 24, 20

local function updateQuality()
	local nextQuality = Settings.Get("GraphicsQuality") == "Low" and .4 or Settings.Get("GraphicsQuality") == "Medium" and .7 or 1
	if nextQuality == quality then return end
	quality = nextQuality
	for source, record in pairs(active) do record.Effect:Destroy(); active[source] = nil end
	for model, effect in pairs(zoneEffects) do effect:Destroy(); zoneEffects[model] = nil end
	dirty = true
end
Settings.Changed:Connect(updateQuality)
updateQuality()

local function near(position)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - position).Magnitude < (quality < .6 and 160 or 300)
end

local function addBurst(effect)
	if #bursts >= MAX_BURSTS then table.remove(bursts, 1).Effect:Destroy() end
	bursts[#bursts + 1] = { Effect = effect, Started = os.clock() }
	effect:Update(0)
end

local function watchProjectiles(instance)
	if instance.Name == "BowSpecialEffects" and specialFolder ~= instance then
		specialFolder = instance
		local function added(child) if child:IsA("Model") then zones[child] = true; dirty = true end end
		instance.ChildAdded:Connect(added)
		instance.ChildRemoved:Connect(function(child) zones[child] = nil; dirty = true end)
		for _, child in ipairs(instance:GetChildren()) do added(child) end
		return
	end
	if instance.Name ~= "CombatProjectiles" or projectileFolder == instance then return end
	projectileFolder = instance
	local function added(child)
		if child:IsA("Model") then arrows[child] = true; dirty = true end
	end
	instance.ChildAdded:Connect(added)
	instance.ChildRemoved:Connect(function(child) arrows[child] = nil end)
	for _, child in ipairs(instance:GetChildren()) do added(child) end
end
workspace.ChildAdded:Connect(watchProjectiles)
for _, child in ipairs(workspace:GetChildren()) do watchProjectiles(child) end

-- Rediscover nearby sources at a modest rate; the per-frame loop only animates
-- admitted effects. This also handles respawns, streaming and equipment swaps.
local elapsed = 0
local function removeEffect(source, record)
	if record.Mode == "Flight" and record.Owner:GetAttribute("BowInFlight") == false then
		record.Effect:Stop()
		addBurst(record.Effect)
	else record.Effect:Destroy() end
	active[source] = nil
end
local function reconcile()
	local nearby = {}
	for model in pairs(zones) do
		if model.Parent and model.PrimaryPart and model:GetAttribute("BowId") and near(model.PrimaryPart.Position) then
			table.insert(nearby, model)
		end
	end
	local camera = workspace.CurrentCamera
	if camera then table.sort(nearby, function(a,b)
		return (a.PrimaryPart.Position-camera.CFrame.Position).Magnitude < (b.PrimaryPart.Position-camera.CFrame.Position).Magnitude
	end) end
	local wantedZones = {}
	for i, model in ipairs(nearby) do
		if i > (quality < .6 and 6 or 12) then break end
		wantedZones[model] = true
		if not zoneEffects[model] then zoneEffects[model] = SpecialVisuals.Zone(model, quality, folder) end
	end
	for model, effect in pairs(zoneEffects) do
		if not wantedZones[model] then effect:Destroy(); zoneEffects[model] = nil end
	end
	local wanted, admitted = {}, 0
	local function admit(source, owner, id, grade, mode, special, player)
		if admitted >= MAX_ACTIVE or not source or not near(source.Position) then return end
		admitted += 1
		wanted[source] = true
		local record = active[source]
		if record and (record.Id ~= id or record.Grade ~= grade) then record.Effect:Destroy(); active[source] = nil; record = nil end
		if not record then
			active[source] = {
				Effect = Visuals.Attach(source, id, grade, mode, special, quality, folder),
				Owner = owner, Id = id, Grade = grade, Mode = mode, Player = player,
			}
		end
	end
	local function bow(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local tool = character:FindFirstChildOfClass("Tool")
		if tool and (tool:GetAttribute("WeaponType") == "Bow" or tool:GetAttribute("WeaponFamily") == "Bow") then
			admit(tool:FindFirstChild("Handle"), tool, tool:GetAttribute("InventoryItemId") or tool.Name, tool:GetAttribute("GearGrade") or 1, "Bow", false, player)
		end
	end
	bow(localPlayer)
	for arrow in pairs(arrows) do
		if arrow.Parent and arrow:GetAttribute("BowInFlight") == true then
			admit(arrow.PrimaryPart, arrow, arrow:GetAttribute("BowVisualId"), arrow:GetAttribute("BowVisualGrade") or 1, "Flight", arrow:GetAttribute("BowVisualSpecial") == true)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do if player ~= localPlayer then bow(player) end end
	for source, record in pairs(active) do
		if not wanted[source] then removeEffect(source, record) end
	end
end

RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if dirty or elapsed >= .1 then elapsed = 0; dirty = false; reconcile() end
	local now = os.clock()
	for model, effect in pairs(zoneEffects) do
		if not model.Parent or not model.PrimaryPart then effect:Destroy(); zoneEffects[model] = nil
		else effect:Update(math.max(0, workspace:GetServerTimeNow() - (model:GetAttribute("Started") or workspace:GetServerTimeNow()))) end
	end
	for source, record in pairs(active) do
		local live = source:IsDescendantOf(workspace) and record.Owner.Parent ~= nil
		if record.Mode == "Flight" then live = live and record.Owner:GetAttribute("BowInFlight") == true
		else
			local character = record.Player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			live = live and record.Owner.Parent == character and humanoid ~= nil and humanoid.Health > 0
		end
		if not live then
			removeEffect(source, record)
		else
			local charge = 0
			if record.Mode == "Bow" then
				if record.Player == localPlayer then
					local started = localPlayer:GetAttribute("BowChargeStarted")
					charge = started and math.clamp((now - started) / 1.3, 0, 1) or 0
				else
					local started = record.Owner:GetAttribute("BowDrawStarted")
					charge = started and math.clamp((workspace:GetServerTimeNow() - started) / 1.3, 0, 1) or 0
				end
				if record.Player:GetAttribute("IsDead") or (ReplicatedStorage:GetAttribute("WorldShifting") and not record.Player:GetAttribute("InteriorId")) then charge = 0 end
			end
			record.Effect:Update(record.Mode == "Bow" and Settings.Get("ReducedMotion") and 0 or now, charge)
		end
	end
	for i = #bursts, 1, -1 do
		local record = bursts[i]
		local age = now - record.Started
		if age >= record.Effect.Duration then record.Effect:Destroy(); table.remove(bursts, i)
		else record.Effect:Update(age) end
	end
end)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BowEffect")
remote.OnClientEvent:Connect(function(kind, id, grade, special, position, normal)
	if kind == "Special" then
		local packet = id
		if not near(packet.Position) then return end
		addBurst(SpecialVisuals.Pulse(packet, quality, folder))
		return
	end
	if not near(position) then return end
	if kind == "Release" or kind == "Impact" then
		addBurst(Visuals.Burst(id, grade, special, position, normal, kind == "Release", quality, folder))
	end
end)
