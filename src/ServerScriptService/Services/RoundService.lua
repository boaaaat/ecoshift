-- RoundService.lua
-- Tracks round start time and exposes wipe detection. Does not reset map; you can hook OnRoundEnd.
local Players = game:GetService("Players")

local RoundService = {}
RoundService._t0 = os.clock()
RoundService._checkInterval = 2
RoundService._ended = false
RoundService._finalElapsed = nil

local function playerCounts()
	local alive = 0
	local participants = 0
	local players = Players:GetPlayers()
	for i = 1, #players do
		local plr = players[i]
		local hum = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
		if hum then
			participants += 1
			if hum.Health > 0 then
				alive += 1
			end
		elseif plr:GetAttribute("IsDead") then
			participants += 1
		end
	end
	return alive, participants
end

function RoundService:EndMatch(finalElapsed)
	if self._ended then
		return self._finalElapsed
	end
	self._ended = true
	self._finalElapsed = tonumber(finalElapsed) or (os.clock() - self._t0)
	return self._finalElapsed
end

function RoundService:IsEnded()
	return self._ended == true
end

function RoundService:Bind()
	task.spawn(function()
		while true do
			local alive, participants = playerCounts()
			if not self._ended and participants > 0 and alive == 0 then
				local elapsed = self:EndMatch()
				local cb = _G.Ecoshift and _G.Ecoshift.OnRoundEnd
				if type(cb) == "function" then pcall(cb, elapsed) end
			end
			task.wait(self._checkInterval)
		end
	end)
end

function RoundService:GetElapsed()
	if self._ended then
		return self._finalElapsed or 0
	end
	return os.clock() - self._t0
end

return RoundService
