-- Shared validation: only these personal preferences can enter a profile.
local Settings = {}
Settings.Order = { "UITheme", "StartingTutorial", "GraphicsQuality", "Shadows", "WeatherParticles", "PostEffects", "ReducedMotion", "FieldOfView", "ShowFieldNotes", "ShowNavigation", "SprintMode" }
Settings.Definitions = {
	ControlSchemeVersion = { Default = 2, Values = { 2 } },
	UITheme = { Label = "Appearance", Default = "Dark", Values = { "Dark", "Light" }, Section = "Gameplay" },
	StartingTutorial = { Label = "Show tutorial at expedition start", Default = true, Section = "Gameplay" },
	ShowFieldNotes = { Label = "Field notes on HUD", Default = true, Section = "Gameplay" },
	ShowNavigation = { Label = "Field kit shortcuts on HUD", Default = true, Section = "Gameplay" },
	SprintMode = { Label = "Sprint mode", Default = "Hold", Values = { "Hold", "Toggle" }, Section = "Gameplay" },
	GraphicsQuality = { Label = "Effects quality", Default = "High", Values = { "Low", "Medium", "High" }, Section = "Graphics" },
	Shadows = { Label = "World shadows", Default = true, Section = "Graphics" },
	WeatherParticles = { Label = "Weather particles", Default = true, Section = "Graphics" },
	PostEffects = { Label = "Post processing", Default = true, Section = "Graphics" },
	ReducedMotion = { Label = "Reduce menu motion", Default = false, Section = "Graphics" },
	FieldOfView = { Label = "Camera field of view", Default = 70, Values = { 60, 70, 80, 90 }, Section = "Graphics" },
}
Settings.Actions = { "Pack", "Craft", "Build", "Map", "Survey", "Settings", "Sprint", "Salvage", "Ability" }
local defaults = { Pack = "E", Craft = "C", Build = "B", Map = "M", Survey = "V", Settings = "F4", Sprint = "LeftShift", Salvage = "R", Ability = "G" }
-- Movement, interaction, hotbar, chat, camera lock and spectating keys stay reserved.
Settings.AllowedKeys = { "B", "C", "E", "G", "H", "J", "K", "L", "M", "N", "O", "P", "R", "U", "V", "Y", "Z", "F4", "F6", "F7", "LeftShift", "RightShift" }
for _, action in ipairs(Settings.Actions) do
	Settings.Definitions["Key" .. action] = { Label = action, Default = defaults[action], Values = Settings.AllowedKeys, Section = "Keybinds" }
	table.insert(Settings.Order, "Key" .. action)
end
function Settings.Valid(key, value)
	local def = Settings.Definitions[key]
	if not def then return false end
	if (value == "LeftShift" or value == "RightShift") and key ~= "KeySprint" then return false end
	if def.Values then return table.find(def.Values, value) ~= nil end
	return type(value) == "boolean"
end
function Settings.Normalize(raw)
	local result, used = {}, {}
	raw = type(raw) == "table" and raw or {}
	if raw.ControlSchemeVersion ~= 2 and raw.KeyPack == "G" then
		raw = table.clone(raw)
		raw.KeyPack = "E"
	end
	for key, def in pairs(Settings.Definitions) do
		if Settings.Valid(key, raw[key]) then result[key] = raw[key] else result[key] = def.Default end
	end
	-- Repair legacy/corrupt conflicting bindings as one set.
	for _, action in ipairs(Settings.Actions) do
		local key = result["Key" .. action]
		if action == "Ability" and used[key] then
			for _, candidate in ipairs({"G", "H", "J", "K", "L"}) do
				if not used[candidate] then key = candidate; result.KeyAbility = candidate; break end
			end
		end
		if used[key] then
			for _, id in ipairs(Settings.Actions) do result["Key" .. id] = defaults[id] end
			break
		end
		used[key] = true
	end
	return result
end
function Settings.ValidatePatch(patch, current)
	if type(patch) ~= "table" then return false end
	local merged = Settings.Normalize(current)
	local count = 0
	for key, value in pairs(patch) do
		if not Settings.Valid(key, value) then return false end
		count += 1; merged[key] = value
	end
	if count == 0 or count > #Settings.Order then return false end
	local used = {}
	for _, action in ipairs(Settings.Actions) do
		local key = merged["Key" .. action]
		if used[key] then return false end
		used[key] = true
	end
	return true
end
return Settings
