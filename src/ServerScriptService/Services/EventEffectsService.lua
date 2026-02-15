-- EventEffectsService.lua
-- Applies gameplay modifiers when events begin/end.
-- Reads Effects and Modifiers from the resolved event config (data-driven).
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

local function applyResolved(resolved, isStart)
	local mods = _G.Ecoshift.Mods
	local delta = isStart and 1 or -1

	-- Effects: additive deltas to gameplay multipliers (ResourceMultiplier, EnemyMultiplier, etc.)
	if type(resolved.Effects) == "table" then
		for key, value in pairs(resolved.Effects) do
			if mods[key] ~= nil then
				mods[key] += (tonumber(value) or 0) * delta
			end
		end
	end

	-- Modifiers: additive deltas to environment (Temp, Toxin, Wet, etc.)
	if type(resolved.Modifiers) == "table" then
		for key, value in pairs(resolved.Modifiers) do
			if mods[key] ~= nil then
				mods[key] += (tonumber(value) or 0) * delta
			end
		end
	end
end

function EventEffectsService:Init()
	if self._initialized then return end
	self._initialized = true
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 200 do
			if type(_G.Ecoshift.OnEventStartAdd) == "function" and type(_G.Ecoshift.OnEventEndAdd) == "function" then
				_G.Ecoshift.OnEventStartAdd(function(_, _, payload)
					if payload and payload.Resolved then
						applyResolved(payload.Resolved, true)
					end
				end)
				_G.Ecoshift.OnEventEndAdd(function(_, _, payload)
					if payload and payload.Resolved then
						applyResolved(payload.Resolved, false)
					end
				end)
				return
			end
			task.wait(0.1)
		end
	end)
end

return EventEffectsService
