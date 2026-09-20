-- Consistent single-flight RemoteEvent requests with request IDs and timeouts.
local HttpService = game:GetService("HttpService")

local Request = {}
Request.__index = Request

function Request.new(remote)
	return setmetatable({Remote = remote, Pending = nil, Serial = 0}, Request)
end

function Request:IsPending()
	return self.Pending ~= nil
end

function Request:Send(action, payload, options)
	options = options or {}
	if self.Pending and options.Track ~= false then
		if options.OnBusy then options.OnBusy(self.Pending) end
		return nil
	end
	payload = table.clone(payload or {})
	self.Serial += 1
	local id = options.AddRequestId == false and tostring(self.Serial)
		or payload.RequestId or HttpService:GenerateGUID(false)
	if options.AddRequestId ~= false then payload.RequestId = id end
	local pending = {Id = id, Action = action, Payload = payload}
	if options.Track ~= false then
		self.Pending = pending
		if options.OnStart then options.OnStart(pending) end
		task.delay(options.Timeout or 8, function()
			if self.Pending ~= pending then return end
			self.Pending = nil
			if options.OnTimeout then options.OnTimeout(pending) end
		end)
	end
	self.Remote:FireServer(action, payload)
	return pending
end

function Request:Resolve(requestId)
	local pending = self.Pending
	if not pending or requestId and pending.Id ~= requestId then return nil end
	self.Pending = nil
	return pending
end

function Request:Cancel()
	local pending = self.Pending
	self.Pending = nil
	return pending
end

return Request
