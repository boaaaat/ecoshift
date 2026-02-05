-- EventEffectsService.lua
-- Applies gameplay modifiers when events begin/end.
local EventEffectsService = {}
EventEffectsService._initialized = false

local function resetMods()
	_G.Ecoshift = _G.Ecoshift or {}
	_G.Ecoshift.Mods = {
		Temp = 0,
		Toxin = 0,
		Wet = 0,
		ResourceMultiplier = 1.0,
		EnemyMultiplier = 1.0,
	}
end

resetMods()

local function applyForEvent(id, isStart)
	local mods = _G.Ecoshift.Mods
	local delta = isStart and 1 or -1
	if id == "ToxicFog" then
		mods.Toxin += 1 * delta
	elseif id == "MonsoonFlood" then
		mods.Wet += 1 * delta
	elseif id == "MeteorShower" then
		mods.EnemyMultiplier += 0.25 * delta
	elseif id == "ResourceBoom" then
		mods.ResourceMultiplier += 0.75 * delta
	elseif id == "MonsterSiege" then
		mods.EnemyMultiplier += 0.6 * delta
	end
end

function EventEffectsService:Init()
	if self._initialized then return end
	self._initialized = true
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 200 do
			if type(_G.Ecoshift.OnEventStartAdd) == "function" and type(_G.Ecoshift.OnEventEndAdd) == "function" then
				_G.Ecoshift.OnEventStartAdd(function(_, id)
					applyForEvent(id, true)
				end)
				_G.Ecoshift.OnEventEndAdd(function(_, id)
					applyForEvent(id, false)
				end)
				return
			end
			task.wait(0.1)
		end
	end)
end

return EventEffectsService
