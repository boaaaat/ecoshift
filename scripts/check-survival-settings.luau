-- Run with Lune. Pure-data regression checks and compilation of affected code.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local function compileTree(path)
	local count = 0
	for _, name in ipairs(fs.readDir(path)) do
		local full = path .. "/" .. name
		if fs.isDir(full) then count += compileTree(full)
		elseif name:match("%.lua$") then luau.load(fs.readFile(full), { debugName = full }); count += 1 end
	end
	return count
end
local compiled = compileTree("src/ReplicatedStorage/Shared") + compileTree("src/StarterPlayer")
luau.load(fs.readFile("src/ServerScriptService/Services/ProfileService.lua"))
print("Compiled " .. (compiled + 1) .. " shared/client/profile Luau source files")
local function loadModule(path, environment)
	return luau.load(fs.readFile(path), { debugName = path, environment = environment or {}, injectGlobals = true })()
end
local root = "src/ReplicatedStorage/Shared/"
local schema = loadModule(root .. "SettingsConfig.lua")
local defaults = schema.Normalize()
assert(defaults.StartingTutorial and defaults.KeyPack == "G")
local off = schema.Normalize({ StartingTutorial = false, Shadows = false, WeatherParticles = false, PostEffects = false, ShowNavigation = false })
assert(off.StartingTutorial == false and off.Shadows == false and off.WeatherParticles == false and off.PostEffects == false and off.ShowNavigation == false, "false preferences must survive migration")
assert(schema.Normalize({ UITheme = "Light" }).UITheme == "Light", "legacy theme retained")
assert(schema.Normalize({ KeyPack = "C" }).KeyPack == "G", "duplicate stored bindings repaired")
assert(schema.ValidatePatch({ KeyPack = "H" }, defaults))
assert(not schema.ValidatePatch({ KeyPack = "C" }, defaults), "duplicate rejected")
assert(not schema.ValidatePatch({ KeyPack = "W" }, defaults), "movement reserved")
assert(not schema.Valid("KeyPack", "RightShift"), "quick-transfer modifiers reserved")
assert(not schema.ValidatePatch({ Currency = 999 }, defaults), "unknown preference rejected")
assert(not schema.ValidatePatch({ FieldOfView = 0/0 }, defaults), "NaN rejected")
assert(not schema.ValidatePatch({ StartingTutorial = "false" }, defaults), "wrong type rejected")
assert(not schema.ValidatePatch({}, defaults))
assert(schema.ValidatePatch({ KeyPack = "C", KeyCraft = "G" }, defaults), "atomic swaps allowed")
print("Settings defaults, migration, validation and binding conflicts passed")
local biomes = loadModule(root .. "BiomeConfig.lua", {
	Random = { new = function() return { NextInteger = function() return 12345 end } end },
	Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
})
local survival = loadModule(root .. "SurvivalConfig.lua")
local recipes = loadModule(root .. "WorkbenchConfig.lua")
local item = loadModule(root .. "Items/Item.lua")
local descriptions = loadModule(root .. "Items/ItemDescriptions.lua", {
	script = { Parent = { Parent = { WorkbenchConfig = recipes, SurvivalConfig = survival } } },
	require = function(module) return module end,
})
local storage = { FindFirstChild = function() return nil end }
local items = loadModule(root .. "Items/ItemDatabase.lua", {
	game = { GetService = function() return storage end },
	script = { Parent = { Item = item, ItemDescriptions = descriptions } },
	require = function(module) return module end,
	Color3 = roblox.Color3,
})
local described = 0
for _, definition in ipairs(items:All()) do
	assert(type(definition.Description) == "string" and #definition.Description > 0, "missing description: " .. definition.Id)
	assert(#definition.Description <= 160, "description too long: " .. definition.Id)
	assert(items:Get(definition.Id).Description == definition.Description, "lookup/list mismatch")
	described += 1
end
assert(items:Get("StaminaRation").Description:find("24 hunger"))
for _, id in ipairs({ "ThreatMeter", "ResourceCompass", "EventSeismograph", "PathfinderBeacon", "HazardAnalyzer" }) do
	assert(items:Get(id).Description:find("Not active yet", 1, true))
end
print("All " .. described .. " items have short descriptions in both item lookup and listing")
local shared = { BiomeConfig = biomes, SurvivalConfig = survival, Items = { ItemDatabase = items }, WorkbenchConfig = recipes }
local guide = loadModule(root .. "SurvivalGuide.lua", { script = { Parent = shared }, require = function(module) return module end })
local biomeCount, weatherCount = 0, 0
for id in pairs(biomes.biomes) do
	biomeCount += 1
	assert(guide.Biomes[id], "missing biome " .. id)
	for _, weather in ipairs(survival.WEATHER_BY_BIOME[id]) do
		weatherCount += 1
		assert(guide.Weather(id, weather.Id) == weather)
		local exposure = guide.Exposure(id, weather.Id)
		assert(exposure.Temp == biomes.biome_metadata[id].env.Temp + weather.Temp)
		assert(#guide.Hazards(exposure) > 0)
		local armor, tools = guide.Recommendations(id, weather.Id, true)
		for _, list in ipairs({armor, tools}) do
			for _, equipment in ipairs(list) do
				assert(items:Get(equipment), "missing item " .. equipment)
				assert(recipes.RECIPES[equipment], "missing recipe " .. equipment)
				assert(#guide.RecipeText(equipment) > 0)
			end
		end
	end
end
assert(guide.Exposure("Desert", "Clear").Temp == 1)
assert(math.abs(guide.Exposure("Desert", "Heatwave").Temp - 1.6) < .001)
assert(guide.ArmorText("ReedSunwrap"):find("70%%"))
assert(guide.RecipeText("ReedSunwrap"):find("6 Reed Fiber"))
assert(guide.RecipeText("ReedSunwrap"):find("2 Moss Bloom"))
assert(guide.RecipeText("ReedSunwrap"):find("2 Sap Resin"))
assert(guide.RecipeText("ReedSunwrap"):find("Hand"))
assert(#guide.Hazards(guide.Exposure("Unknown", "Unknown")) > 0)
assert(guide.ArmorText(nil) == "No survival armor equipped.")
print("Survival guide covers " .. biomeCount .. " biomes and " .. weatherCount .. " biome/weather combinations; every recommended item and recipe exists")

-- Exercise the actual profile reducer through its normal write-through path.
local serde = require("@lune/serde")
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
end
local stored = { Currency = 25, Preferences = { UITheme = "Light" } }
local store = {
	GetAsync = function() return copy(stored) end,
	UpdateAsync = function(_, _, callback)
		local nextValue = callback(copy(stored))
		if nextValue then stored = copy(nextValue) end
		return copy(nextValue)
	end,
}
local players = {}
local economy = loadModule(root .. "EconomyConfig.lua")
local modules = {
	Config = { DATASTORE = { ProfileStore = "Test" }, ROLES = { Default = "Survivor", Definitions = { Survivor = {} } } },
	EconomyConfig = economy, SettingsConfig = schema, Util = { DeepCopy = copy },
}
local services = {
	Players = players, DataStoreService = { GetDataStore = function() return store end },
	ReplicatedStorage = { Shared = modules }, HttpService = { JSONEncode = function(_, value) return serde.encode("json", value) end },
}
local profile = loadModule("src/ServerScriptService/Services/ProfileService.lua", {
	game = { GetService = function(_, name) return assert(services[name], name) end },
	require = function(module) return module end,
	task = { defer = function(callback) callback() end, wait = function() end },
})
local attributes = {}
local player = { UserId = 123, Parent = players, SetAttribute = function(_, key, value) attributes[key] = value end }
profile:Load(player)
assert(profile:GetProfile(player).Preferences.UITheme == "Light")
local function update(patch, timestamp)
	local completed, success = profile:_execute(player, { Kind = "SetSettings", Patch = patch, UpdatedAt = timestamp })
	assert(completed); return success
end
assert(update({ StartingTutorial = false, Shadows = false, KeyPack = "H" }, 100))
assert(stored.Preferences.StartingTutorial == false and stored.Preferences.Shadows == false)
assert(stored.Currency == 25 and stored.Preferences.UITheme == "Light", "preference writes preserve profile")
assert(serde.decode("json", attributes.PersonalSettings).StartingTutorial == false, "false replicates")
assert(update({ StartingTutorial = true }, 90), "old preference is superseded")
assert(stored.Preferences.StartingTutorial == false, "old write cannot reenable tutorial")
assert(not update({ KeyCraft = "H" }, 110), "server rejects conflicts against fresh stored state")
assert(stored.Preferences.KeyCraft == "C")
assert(update({ GraphicsQuality = "Low" }, 120))
assert(stored.Preferences.StartingTutorial == false and stored.Preferences.KeyPack == "H")
profile._sessions[player] = nil
profile:Load(player)
assert(profile:GetProfile(player).Preferences.StartingTutorial == false, "disabled tutorial survives reload")
assert(profile:GetProfile(player).Preferences.GraphicsQuality == "Low")
print("Profile write-through, preference reload, stale writes, conflict rejection and unrelated-field preservation passed (mock DataStore)")

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, callback in ipairs(callbacks) do callback(...) end end,
	}
end
local personalChanged, resultEvent = signal(), signal()
local clientAttributes = { PersonalSettings = serde.encode("json", schema.Normalize()), ProfileLoaded = true }
local sent, delayed = {}, {}
local clientPlayer = {
	GetAttribute = function(_, key) return clientAttributes[key] end,
	GetAttributeChangedSignal = function() return personalChanged end,
}
local remote = { OnClientEvent = resultEvent, FireServer = function(_, ...) table.insert(sent, {...}) end }
local remotes = { WaitForChild = function() return remote end }
local clientServices = {
	Players = { LocalPlayer = clientPlayer },
	HttpService = { JSONDecode = function(_, raw) return serde.decode("json", raw) end },
	UserInputService = { GetFocusedTextBox = function() return nil end },
	ReplicatedStorage = { WaitForChild = function() return remotes end },
}
local client = loadModule(root .. "ClientSettings.lua", {
	game = { GetService = function(_, name) return clientServices[name] end },
	script = { Parent = { SettingsConfig = schema } }, require = function(module) return module end,
	Instance = { new = function() local event = signal(); return { Event = event, Fire = function(_, ...) event:Fire(...) end } end },
	Enum = roblox.Enum,
	task = { spawn = function(callback) callback() end, delay = function(_, callback) table.insert(delayed, callback) end },
})
assert(client.Set("StartingTutorial", false) and client.Get("StartingTutorial") == false)
client.Save(); assert(#sent == 1 and sent[1][2].StartingTutorial == false)
assert(client.Set("StartingTutorial", true), "edit while saving")
resultEvent:Fire("Result", { RequestId = sent[1][3], Success = true, Preferences = schema.Normalize({ StartingTutorial = false }) })
assert(client.Get("StartingTutorial") == true, "new local edit survives old save response")
client.Save(); resultEvent:Fire("Result", { RequestId = sent[2][3], Success = false })
assert(client.Get("StartingTutorial") == true, "failed save retains local edit")
client.Save(); resultEvent:Fire("Result", { RequestId = sent[3][3], Success = true, Preferences = schema.Normalize({ StartingTutorial = true }) })
assert(client.Set("KeyPack", "H")); assert(not client.Set("KeyCraft", "H"))
client.Capturing = true
assert(not client.Matches({ KeyCode = roblox.Enum.KeyCode.H }, "Pack"))
client.Capturing = false
assert(client.Matches({ KeyCode = roblox.Enum.KeyCode.H }, "Pack"))
client.Save(); delayed[#delayed]()
assert(client.Get("KeyPack") == "H" and client.Status:find("timed out"), "timeout is retryable")
clientAttributes.ProfileLoaded = false
local before = #sent; client.Save(); assert(#sent == before and client.Status:find("unavailable"))
client.Reset(); assert(client.Get("KeyPack") == "G" and client.Get("StartingTutorial") == true)
print("Client edits during save, retry, timeout, profile unavailability, reset and input capture passed (mock remotes)")
