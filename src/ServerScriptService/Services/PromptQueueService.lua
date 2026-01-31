-- PromptQueueService.lua
-- Throttles ProximityPrompt creation to avoid spikes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PromptQueueService = {}
PromptQueueService._queue = {}
PromptQueueService._head = 1
PromptQueueService._tail = 0
PromptQueueService._running = false

local function maxPerSecond()
	local cfg = Config.PROMPTS
	local n = cfg and cfg.MaxPerSecond or 500
	n = math.floor(tonumber(n) or 500)
	if n <= 0 then n = 500 end
	return n
end

-- OPTIMIZED: Calculate batch size per frame instead of per second
local function batchPerFrame()
	return math.ceil(maxPerSecond() / 60) -- ~8 per frame at 60fps
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
	-- OPTIMIZED: Use Heartbeat for smoother distribution across frames
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if self._head > self._tail then
			connection:Disconnect()
			self._head = 1
			self._tail = 0
			self._running = false
			return
		end
		
		local batch = math.min(batchPerFrame(), self._tail - self._head + 1)
		for _ = 1, batch do
			if self._head > self._tail then break end
			local fn = self._queue[self._head]
			self._queue[self._head] = nil
			self._head += 1
			if fn then
				task.defer(fn) -- OPTIMIZED: Defer execution to spread load
			end
		end
	end)
end

return PromptQueueService
