-- RoundService.lua
-- Tracks round start time and exposes wipe detection. Does not reset map; you can hook OnRoundEnd.
local Players = game:GetService("Players")

local RoundService = {}
RoundService._t0 = os.clock()
RoundService._checkInterval = 2
RoundService._next = 0

local function alivePlayers()
	local n = 0
	for _,plr in ipairs(Players:GetPlayers()) do
		local hum = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
		if hum and hum.Health > 0 then n += 1 end
	end
	return n
end

function RoundService:Bind()
	game:GetService("RunService").Heartbeat:Connect(function()
		local t = os.clock()
		if t < self._next then return end
		self._next = t + self._checkInterval
		if #Players:GetPlayers() > 0 and alivePlayers() == 0 then
			-- round end
			local cb = _G.Ecoshift and _G.Ecoshift.OnRoundEnd
			if type(cb) == "function" then pcall(cb, os.clock()-self._t0) end
			self._t0 = os.clock() -- reset timer; you can also trigger server soft reset here if desired.
		end
	end)
end

function RoundService:GetElapsed() return os.clock() - self._t0 end

return RoundService
