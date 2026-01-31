-- PromptQueueService.lua
-- Throttles ProximityPrompt creation to avoid spikes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PromptQueueService = {}
PromptQueueService._queue = {}
PromptQueueService._head = 1
PromptQueueService._tail = 0
PromptQueueService._running = false

local function maxPerSecond()
	local cfg = Config.PROMPTS
	local n = cfg and cfg.MaxPerSecond or 250
	n = math.floor(tonumber(n) or 250)
	if n <= 0 then n = 250 end
	return n
end

function PromptQueueService:Enqueue(fn)
	if type(fn) ~= "function" then return end
	self._tail += 1
	self._queue[self._tail] = fn
	if not self._running then
		self:_run()
	end
end

function PromptQueueService:_run()
	self._running = true
	task.spawn(function()
		while self._head <= self._tail do
			local batch = math.min(maxPerSecond(), self._tail - self._head + 1)
			for _ = 1, batch do
				local fn = self._queue[self._head]
				self._queue[self._head] = nil
				self._head += 1
				if fn then
					pcall(fn)
				end
			end
			if self._head <= self._tail then
				task.wait(1)
			end
		end
		self._head = 1
		self._tail = 0
		self._running = false
	end)
end

return PromptQueueService
