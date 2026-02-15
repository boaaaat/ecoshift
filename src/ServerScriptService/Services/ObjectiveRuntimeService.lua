-- ObjectiveRuntimeService.lua
-- Adds simple proximity prompts for active objectives.
local Workspace = game:GetService("Workspace")

local ObjectiveService = require(script.Parent.ObjectiveService)
local PromptQueueService = require(script.Parent.PromptQueueService)

local ObjectiveRuntimeService = {}
ObjectiveRuntimeService._activePrompts = {}
ObjectiveRuntimeService._promptConns = setmetatable({}, { __mode = "k" })
ObjectiveRuntimeService._promptObjective = setmetatable({}, { __mode = "k" })
ObjectiveRuntimeService._initialized = false

local function findAnchors(objectiveId)
	local folder = Workspace:FindFirstChild("Objectives")
	if not folder then return {} end
	local list = {}
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("BasePart") then
			local id = inst:GetAttribute("ObjectiveId") or inst.Name
			if id == objectiveId then
				list[#list + 1] = inst
			end
		end
	end
	return list
end

local function attachPrompt(part, objectiveId)
	if not part or not part.Parent then return nil end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = part
	end
	prompt.ActionText = "Contribute"
	prompt.ObjectText = objectiveId
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	local conn = ObjectiveRuntimeService._promptConns[prompt]
	if not conn then
		conn = prompt.Triggered:Connect(function()
			local boundObjective = ObjectiveRuntimeService._promptObjective[prompt]
			if boundObjective and prompt.Enabled then
				ObjectiveService:Advance(boundObjective, 0.2)
			end
		end)
		ObjectiveRuntimeService._promptConns[prompt] = conn
	end
	ObjectiveRuntimeService._promptObjective[prompt] = objectiveId
	prompt.Enabled = true
	return prompt
end

function ObjectiveRuntimeService:OnStart(objectiveId)
	local anchors = findAnchors(objectiveId)
	self._activePrompts[objectiveId] = self._activePrompts[objectiveId] or {}
	for _, part in ipairs(anchors) do
		PromptQueueService:Enqueue(function()
			local prompt = attachPrompt(part, objectiveId)
			if prompt then
				self._activePrompts[objectiveId][prompt] = true
			end
		end)
	end
end

function ObjectiveRuntimeService:OnEnd(objectiveId)
	local prompts = self._activePrompts[objectiveId]
	if not prompts then return end
	for prompt in pairs(prompts) do
		if prompt and prompt.Parent then
			prompt.Enabled = false
		end
		if self._promptObjective[prompt] == objectiveId then
			self._promptObjective[prompt] = nil
		end
	end
	self._activePrompts[objectiveId] = nil
end

function ObjectiveRuntimeService:Init()
	if self._initialized then return end
	self._initialized = true
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 100 do
			if type(_G.Ecoshift.OnObjectiveStartAdd) == "function" and type(_G.Ecoshift.OnObjectiveEndAdd) == "function" then
				_G.Ecoshift.OnObjectiveStartAdd(function(id)
					ObjectiveRuntimeService:OnStart(id)
				end)
				_G.Ecoshift.OnObjectiveEndAdd(function(id)
					ObjectiveRuntimeService:OnEnd(id)
				end)
				return
			end
			task.wait(0.1)
		end
	end)
end

return ObjectiveRuntimeService
