-- MainHUD.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- OPTIMIZED: Try immediate lookup first, use shorter timeout
local remotesFolder = Util.GetDescendant(Config.Paths.Remotes) 
	or Util.WaitForDescendant(Config.Paths.Remotes, 5)
local rProfile = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ProfileUpdate)
local rRole = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.RoleUpdate)
local rRoleSelect = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.RoleSelect)
local rGame = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.GameStateUpdate)
local rEvent = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.EventBroadcast)
local rObjective = remotesFolder and Util.GetRemote(remotesFolder, Config.RemoteNames.ObjectiveUpdate)

local gui = Instance.new("ScreenGui")
gui.Name = "EcoshiftHUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "TopLeft"
panel.Size = UDim2.new(0, 320, 0, 160)
panel.Position = UDim2.new(0, 10, 0, 10)
panel.BackgroundTransparency = 0.25
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BorderSizePixel = 0
panel.Parent = gui

local function makeLabel(name, y)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, -12, 0, 22)
	label.Position = UDim2.new(0, 6, 0, y)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Text = ""
	label.Parent = panel
	return label
end

local lblBiome = makeLabel("Biome", 8)
local lblTime = makeLabel("Time", 32)
local lblRole = makeLabel("Role", 56)
local lblEvent = makeLabel("Event", 80)
local lblObjective = makeLabel("Objective", 104)

local roleButton = Instance.new("TextButton")
roleButton.Name = "RoleButton"
roleButton.Size = UDim2.new(0, 140, 0, 22)
roleButton.Position = UDim2.new(0, 6, 0, 128)
roleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
roleButton.BorderSizePixel = 0
roleButton.Font = Enum.Font.GothamBold
roleButton.TextSize = 12
roleButton.TextColor3 = Color3.fromRGB(230, 230, 230)
roleButton.Text = "Change Role"
roleButton.Parent = panel

local activeEvents = {}
local objectives = {}
local profile = { Role = "", Level = 1, XP = 0 }
local roleList = {}
for roleId in pairs(Config.ROLES.Definitions or {}) do
	roleList[#roleList + 1] = roleId
end
table.sort(roleList)
local roleIndex = 1

local function syncRoleIndex(roleId)
	if type(roleId) ~= "string" then return end
	for i, id in ipairs(roleList) do
		if id == roleId then
			roleIndex = i
			return
		end
	end
end

local function formatTime(sec)
	sec = math.floor(sec)
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end


local function renderEvents()
	local list = {}
	for id in pairs(activeEvents) do
		list[#list + 1] = id
	end
	table.sort(list)
	lblEvent.Text = "Event: " .. (#list > 0 and table.concat(list, ", ") or "None")
end

local function renderObjectives()
	local list = {}
	for id, data in pairs(objectives) do
		local pct = math.floor((data.Progress or 0) * 100)
		list[#list + 1] = string.format("%s %d%%", id, pct)
	end
	table.sort(list)
	lblObjective.Text = "Objective: " .. (#list > 0 and table.concat(list, " | ") or "None")
end


if rProfile then
	rProfile.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			profile = data
			syncRoleIndex(profile.Role)
			lblRole.Text = string.format("Role: %s  |  Lv %d", profile.Role or "", profile.Level or 1)
		end
	end)
end

if rRole then
	rRole.OnClientEvent:Connect(function(roleId)
		if roleId then
			profile.Role = roleId
			syncRoleIndex(roleId)
			lblRole.Text = string.format("Role: %s  |  Lv %d", profile.Role or "", profile.Level or 1)
		end
	end)
end

if roleButton and rRoleSelect then
	roleButton.MouseButton1Click:Connect(function()
		if #roleList == 0 then return end
		roleIndex += 1
		if roleIndex > #roleList then roleIndex = 1 end
		local roleId = roleList[roleIndex]
		rRoleSelect:FireServer(roleId)
	end)
end

if rGame then
	rGame.OnClientEvent:Connect(function(state)
		if type(state) ~= "table" then return end
		if state.Biome then
			lblBiome.Text = "Biome: " .. tostring(state.Biome)
		end
		if state.Elapsed then
			lblTime.Text = "Time: " .. formatTime(state.Elapsed)
		end
	end)
end

if rEvent then
	rEvent.OnClientEvent:Connect(function(kind, id, payload)
		if kind == "Minor_Start" or kind == "Major_Start" then
			activeEvents[id] = true
		elseif kind == "Minor_End" or kind == "Major_End" then
			activeEvents[id] = nil
		end
		renderEvents()
	end)
end

if rObjective then
	rObjective.OnClientEvent:Connect(function(kind, id, data)
		if kind == "Start" then
			objectives[id] = { Progress = 0 }
		elseif kind == "Progress" then
			objectives[id] = objectives[id] or {}
			objectives[id].Progress = data or 0
		elseif kind == "End" then
			objectives[id] = nil
		end
		renderObjectives()
	end)
end
