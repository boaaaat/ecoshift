-- RoundService.lua
-- Tracks round start time and exposes wipe detection. Does not reset map; you can hook OnRoundEnd.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		-- Character loads yield. A pending restored teammate must not cause a
		-- temporary all-down wipe while earlier downed bodies are reconstructed.
		if plr:GetAttribute("WorldPlayerLoading") then alive += 1; participants += 1; continue end
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
			if not ReplicatedStorage:GetAttribute("WorldRestoring") and not self._ended and participants > 0 and alive == 0 then
				local elapsed = self:EndMatch()
				local cb = _G.Ecoshift and _G.Ecoshift.OnRoundEnd
				if type(cb) == "function" then pcall(cb, elapsed) end
			end
			task.wait(self._checkInterval)
		end
	end)
end

function RoundService:GetElapsed()
	if self._restoreElapsed then return self._restoreElapsed end
	if self._ended then
		return self._finalElapsed or 0
	end
	return os.clock() - self._t0
end

function RoundService:CaptureWorldState()
	return { Elapsed = self:GetElapsed(), Ended = self._ended }
end

function RoundService:RestoreWorldState(state)
	local elapsed = require(script.Parent.WorldSnapshotCodec).Number(state.Elapsed, 0, 1e9)
	self._t0, self._ended = os.clock() - elapsed, state.Ended == true
	self._finalElapsed = self._ended and elapsed or nil
	self._restoreElapsed = elapsed
end

function RoundService:CompleteWorldRestore()
	if self._restoreElapsed then self._t0 = os.clock() - self._restoreElapsed end
	self._restoreElapsed = nil
end

return RoundService
