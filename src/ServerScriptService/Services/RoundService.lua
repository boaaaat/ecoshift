-- RoundService.lua
-- Tracks round start time and exposes wipe detection. Does not reset map; you can hook OnRoundEnd.
local Players = game:GetService("Players")

local RoundService = {}
RoundService._t0 = os.clock()
RoundService._checkInterval = 2

local function alivePlayers()
	local n = 0
	local players = Players:GetPlayers()
	for i = 1, #players do
		local plr = players[i]
		local hum = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then n += 1 end
	end
	return n
end

function RoundService:Bind()
	-- OPTIMIZED: Use task.spawn with controlled loop instead of Heartbeat
	task.spawn(function()
		while true do
			if #Players:GetPlayers() > 0 and alivePlayers() == 0 then
				-- round end
				local cb = _G.Ecoshift and _G.Ecoshift.OnRoundEnd
				if type(cb) == "function" then pcall(cb, os.clock()-self._t0) end
				self._t0 = os.clock() -- reset timer
			end
			task.wait(self._checkInterval)
		end
	end)
end

function RoundService:GetElapsed() return os.clock() - self._t0 end

return RoundService
