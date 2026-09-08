local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local Schema = require(script.Parent.SettingsConfig)
local player = Players.LocalPlayer
local changed = Instance.new("BindableEvent")
local Settings = { Changed = changed.Event, Status = "Preferences load with your profile." }
local saved, pending, inFlight = Schema.Normalize(), {}, nil
local remote, serial, saveAgain = nil, 0, false
function Settings.Get(key)
	if pending[key] ~= nil then return pending[key] end
	if inFlight and inFlight.Patch[key] ~= nil then return inFlight.Patch[key] end
	return saved[key]
end
function Settings.Key(action) return Enum.KeyCode[Settings.Get("Key" .. action)] end
function Settings.Matches(input, action)
	return not Settings.Capturing and input.KeyCode == Settings.Key(action)
end
function Settings.Snapshot()
	local result = {}
	for _, key in ipairs(Schema.Order) do result[key] = Settings.Get(key) end
	return result
end
function Settings.Set(key, value)
	if not Schema.ValidatePatch({ [key] = value }, Settings.Snapshot()) then return false end
	pending[key] = value
	Settings.Status = "Applied locally. Save preferences to keep them."
	changed:Fire(key)
	return true
end
function Settings.Reset()
	pending = Schema.Normalize()
	Settings.Status = "Defaults applied. Save preferences to keep them."
	changed:Fire()
end
function Settings.Save()
	if inFlight then saveAgain = true; return end
	if not remote or player:GetAttribute("ProfileLoaded") ~= true then
		Settings.Status = "Applied for this session; profile unavailable. Try Save again later."
		changed:Fire(); return
	end
	if not next(pending) then return end
	serial += 1
	inFlight = { Id = serial, Patch = pending }; pending = {}
	Settings.Status = "Saving preferences..."; changed:Fire()
	remote:FireServer("SetSettings", inFlight.Patch, inFlight.Id)
	local request = inFlight
	task.delay(30, function()
		if inFlight ~= request then return end
		for key, value in pairs(request.Patch) do if pending[key] == nil then pending[key] = value end end
		inFlight, saveAgain = nil, false
		Settings.Status = "Save timed out. Preferences still apply locally; try Save again."
		changed:Fire()
	end)
end
local function refresh()
	local raw = player:GetAttribute("PersonalSettings")
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then saved = Schema.Normalize(decoded) end
	end
	changed:Fire()
end
player:GetAttributeChangedSignal("PersonalSettings"):Connect(refresh)
refresh()
task.spawn(function()
	remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ProfilePreference")
	remote.OnClientEvent:Connect(function(action, result)
		if action ~= "Result" or type(result) ~= "table" or not inFlight or result.RequestId ~= inFlight.Id then return end
		for key, value in pairs(inFlight.Patch) do
			if result.Success then saved[key] = value elseif pending[key] == nil then pending[key] = value end
		end
		if result.Success and type(result.Preferences) == "table" then saved = Schema.Normalize(result.Preferences) end
		inFlight = nil
		Settings.Status = result.Success and (next(pending) and "Saved. New changes still need saving." or "Preferences saved.") or "Applied for this session. Save again to retry."
		changed:Fire()
		if saveAgain and result.Success then saveAgain = false; task.delay(.8, Settings.Save) else saveAgain = false end
	end)
end)
-- Every input handler can use this without duplicating keyboard-capture state.
function Settings.CanInput() return not Settings.Capturing and UIS:GetFocusedTextBox() == nil end
return Settings
