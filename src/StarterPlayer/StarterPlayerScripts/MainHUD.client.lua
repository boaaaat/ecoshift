if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- Expedition instruments and local field-kit navigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.UI.UITheme)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local C = Theme.Colors
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "EcoshiftHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "ExpeditionCard"
card.Size = UDim2.fromOffset(272, 188)
card.Position = UDim2.fromOffset(18, 14)
card.Parent = gui
Theme.Panel(card, true)
Theme.Fit(card, 730, 610)
Theme.Label(card, "ECO / SHIFT", UDim2.fromOffset(165, 26), UDim2.fromOffset(16, 12), 21, C.Paper, true)
Theme.Label(card, "EXPEDITION RECORD", UDim2.fromOffset(230, 14), UDim2.fromOffset(16, 40), 9, C.Sage, true)
local runLabel = Theme.Label(card, "00:00", UDim2.fromOffset(72, 18), UDim2.fromOffset(182, 16), 12, C.Amber, true)
runLabel.TextXAlignment = Enum.TextXAlignment.Right
local biomeLabel = Theme.Label(card, "Surveying world...", UDim2.fromOffset(242, 29), UDim2.fromOffset(16, 66), 20, C.Paper, true)
local weatherLabel = Theme.Label(card, "Awaiting conditions", UDim2.fromOffset(240, 17), UDim2.fromOffset(16, 96), 11, C.Sage)
local shiftLabel = Theme.Label(card, "SHIFT TIME UNKNOWN", UDim2.fromOffset(152, 18), UDim2.fromOffset(16, 127), 10, C.Sage, true)
local countdown = Theme.Label(card, "--:--", UDim2.fromOffset(90, 22), UDim2.fromOffset(166, 124), 19, C.Amber, true)
countdown.TextXAlignment = Enum.TextXAlignment.Right
local track = Instance.new("Frame")
track.Name = "ShiftTrack"
track.Size = UDim2.new(1, -32, 0, 5)
track.Position = UDim2.fromOffset(16, 155)
track.BackgroundColor3 = C.Moss
track.BorderSizePixel = 0
track.Parent = card
Theme.Corner(track, 3)
local fill = Instance.new("Frame")
fill.Name = "ShiftFill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = C.Amber
fill.BorderSizePixel = 0
fill.Parent = track
Theme.Corner(fill, 3)
local cycleLabel = Theme.Label(card, "SHIFT 00  /  THREAT 1", UDim2.fromOffset(238, 14), UDim2.fromOffset(16, 166), 9, C.Sage, true)

local notes = Instance.new("Frame")
notes.Name = "FieldNotes"
notes.Size = UDim2.fromOffset(272, 100)
notes.Position = UDim2.fromOffset(0, 200)
notes.Parent = card
Theme.Panel(notes, true)
Theme.Label(notes, "FIELD NOTES", UDim2.fromOffset(170, 16), UDim2.fromOffset(16, 12), 10, C.Amber, true)
local objectiveLabel = Theme.Label(notes, "Gather supplies. Keep your team alive.", UDim2.fromOffset(240, 34), UDim2.fromOffset(16, 33), 11, C.Paper)
objectiveLabel.TextWrapped = true
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
objectiveLabel.TextTruncate = Enum.TextTruncate.None
local eventLabel = Theme.Label(notes, "No active anomalies", UDim2.fromOffset(240, 17), UDim2.fromOffset(16, 73), 10, C.Sage)

local roleButton = Instance.new("TextButton")
roleButton.Name = "RoleButton"
roleButton.Size = UDim2.fromOffset(272, 28)
roleButton.Position = UDim2.fromOffset(0, 308)
roleButton.Text = "FIELD ROLE  /  Select role"
roleButton.Font = Enum.Font.GothamBold
roleButton.TextSize = 10
roleButton.Parent = card
Theme.Button(roleButton, true)

local kit = Instance.new("Frame")
kit.Name = "FieldKitNavigation"
kit.Size = UDim2.fromOffset(376, 32)
kit.AnchorPoint = Vector2.new(0.5, 1)
kit.Position = UDim2.new(0.5, 0, 1, -94)
kit.BackgroundTransparency = 1
kit.Parent = gui
Theme.Fit(kit, 730, 610)
for index, entry in ipairs({ { "Pack", "G" }, { "Craft", "C" }, { "Build", "B" }, { "Map", "M" }, { "Survey", "V" } }) do
	local button = Instance.new("TextButton")
	button.Name = entry[1]
	button.Size = UDim2.fromOffset(70, 28)
	button.Position = UDim2.fromOffset((index - 1) * 76, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 10
	button.Text = entry[2] .. "  " .. string.upper(entry[1])
	button.Parent = kit
	Theme.Button(button, true)
	button.Activated:Connect(function()
		local attribute = "FieldKit" .. entry[1]
		player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)
	end)
end

local remotes = Util.GetDescendant(Config.Paths.Remotes) or Util.WaitForDescendant(Config.Paths.Remotes, 15)
local function remote(name) return remotes and Util.GetRemote(remotes, Config.RemoteNames[name]) end
local rProfile, rRole, rRoleSelect = remote("ProfileUpdate"), remote("RoleUpdate"), remote("RoleSelect")
local rGame, rEvent, rObjective = remote("GameStateUpdate"), remote("EventBroadcast"), remote("ObjectiveUpdate")
local profile = { Level = 1 }
local roles, roleIndex = {}, 1
for roleId in pairs(Config.ROLES.Definitions or {}) do table.insert(roles, roleId) end
table.sort(roles)
local function readable(value)
	-- gsub also returns a replacement count; callers need only the label.
	return (tostring(value):gsub("_", " "):gsub("(%l)(%u)", "%1 %2"))
end
local function updateRole()
	for index, id in ipairs(roles) do if id == profile.Role then roleIndex = index end end
	roleButton.Text = string.format("%s  /  LV %d  /  CHANGE", string.upper(readable(profile.Role or "FIELD ROLE")), profile.Level or 1)
end
if rProfile then rProfile.OnClientEvent:Connect(function(data)
	if type(data) == "table" then profile = data; updateRole() end
end) end
if rRole then rRole.OnClientEvent:Connect(function(id)
	if type(id) == "string" then profile.Role = id; updateRole() end
end) end
roleButton.Activated:Connect(function()
	if not rRoleSelect or #roles == 0 then return end
	roleIndex = roleIndex % #roles + 1
	rRoleSelect:FireServer(roles[roleIndex])
end)

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local deadline, shiftDuration, elapsed, receivedAt = nil, 300, 0, os.clock()
if rGame then rGame.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	if state.Biome then biomeLabel.Text = state.BiomeDisplayName or readable(state.Biome) end
	if type(state.Elapsed) == "number" then elapsed = state.Elapsed; receivedAt = os.clock() end
	if state.HasFieldClock == false then
		deadline = nil
		countdown.Text = "--:--"
		shiftLabel.Text = "FIELD CLOCK REQUIRED"
		fill.Size = UDim2.fromScale(0, 1)
	elseif type(state.ShiftRemaining) == "number" then
		deadline = os.clock() + state.ShiftRemaining
	end
	if type(state.ShiftDuration) == "number" then shiftDuration = math.max(1, state.ShiftDuration) end
	local weather = type(state.Weather) == "table" and (state.Weather.Name or state.Weather.Id) or state.Weather
	if weather then
		weatherLabel.Text = readable(weather) .. (state.UpcomingWeather and "  >  " .. readable(state.UpcomingWeather) or "  /  CONDITIONS")
	end
	cycleLabel.Text = string.format("SHIFT %02d  /  THREAT %s", tonumber(state.ShiftCount) or 0, tostring(state.Difficulty or 1))
end) end
local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick < 0.1 then return end
	lastTick = now
	runLabel.Text = clock(elapsed + now - receivedAt)
	if deadline then
		local remaining = math.max(0, deadline - now)
		countdown.Text = clock(math.ceil(remaining))
		local urgent = remaining <= 15
		countdown.TextColor3 = urgent and Color3.fromRGB(241, 139, 101) or C.Amber
		fill.BackgroundColor3 = countdown.TextColor3
		Theme.Tween(fill, { Size = UDim2.fromScale(math.clamp(remaining / shiftDuration, 0, 1), 1) }, 0.15)
		shiftLabel.Text = urgent and "SHIFT IMMINENT" or "NEXT SHIFT"
	end
end)

local events, objectives = {}, {}
if rEvent then rEvent.OnClientEvent:Connect(function(kind, id)
	if kind == "Minor_Start" or kind == "Major_Start" then events[id] = true
	elseif kind == "Minor_End" or kind == "Major_End" then events[id] = nil end
	local names = {}
	for eventId in pairs(events) do table.insert(names, readable(eventId)) end
	table.sort(names)
	eventLabel.Text = #names > 0 and table.concat(names, " / ") or "No active anomalies"
	eventLabel.TextColor3 = #names > 0 and C.Amber or C.Sage
end) end
if rObjective then rObjective.OnClientEvent:Connect(function(kind, id, data)
	if kind == "Start" then objectives[id] = 0
	elseif kind == "Progress" then objectives[id] = tonumber(data) or 0
	elseif kind == "End" then objectives[id] = nil end
	local names = {}
	for objectiveId, progress in pairs(objectives) do
		table.insert(names, string.format("%s  %d%%", readable(objectiveId), math.floor(progress * 100)))
	end
	table.sort(names)
	objectiveLabel.Text = #names > 0 and (names[1] .. (#names > 1 and "\n+" .. tostring(#names - 1) .. " active objectives" or "")) or "Gather supplies. Keep your team alive."
end) end

task.defer(function()
	for _, request in ipairs({ {rProfile, "RequestProfile"}, {rRole, "RequestRole"}, {rGame, "RequestState"}, {rEvent, "RequestActive"}, {rObjective, "RequestActive"} }) do
		if request[1] then request[1]:FireServer(request[2]) end
	end
end)
