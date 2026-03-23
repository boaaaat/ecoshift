-- ObjectiveRuntimeService.lua
-- Adds simple proximity prompts for active objectives.
local Workspace = game:GetService("Workspace")

local ObjectiveService = require(script.Parent.ObjectiveService)
local PromptQueueService = require(script.Parent.PromptQueueService)
local GameStateService = require(script.Parent.GameStateService)

local ObjectiveRuntimeService = {}
ObjectiveRuntimeService._activePrompts = {}
ObjectiveRuntimeService._promptConns = setmetatable({}, { __mode = "k" })
ObjectiveRuntimeService._promptObjective = setmetatable({}, { __mode = "k" })
ObjectiveRuntimeService._initialized = false

local function getObjectiveId(part)
	return part:GetAttribute("ObjectiveId") or part.Name
end

local function isObjectiveAnchor(part)
	if not part or not part:IsA("BasePart") then return false end
	local folder = part:FindFirstAncestor("Objectives")
	if not folder then return false end
	if folder.Parent == Workspace then
		return true
	end
	local generatedWorld = Workspace:FindFirstChild("GeneratedWorld")
	return generatedWorld and folder:IsDescendantOf(generatedWorld) or false
end

local function objectiveRoots()
	local roots = {}
	local folder = Workspace:FindFirstChild("Objectives")
	if folder then
		roots[#roots + 1] = folder
	end
	local generatedWorld = Workspace:FindFirstChild("GeneratedWorld")
	if generatedWorld then
		for _, inst in ipairs(generatedWorld:GetDescendants()) do
			if inst:IsA("Folder") and inst.Name == "Objectives" then
				roots[#roots + 1] = inst
			end
		end
	end
	return roots
end

local function findAnchors(objectiveId)
	local list = {}
	for _, root in ipairs(objectiveRoots()) do
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("BasePart") and getObjectiveId(inst) == objectiveId then
				list[#list + 1] = inst
			end
		end
	end
	return list
end

local function attachPrompt(part, objectiveId)
	if GameStateService:IsGameOver() then return nil end
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
	if GameStateService:IsGameOver() then return end
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

function ObjectiveRuntimeService:ClearAllPrompts()
	local activeIds = {}
	for objectiveId in pairs(self._activePrompts) do
		activeIds[#activeIds + 1] = objectiveId
	end
	for _, objectiveId in ipairs(activeIds) do
		self:OnEnd(objectiveId)
	end
end

function ObjectiveRuntimeService:_onDescendantAdded(inst)
	if GameStateService:IsGameOver() then return end
	if not isObjectiveAnchor(inst) then return end
	local objectiveId = getObjectiveId(inst)
	local prompts = self._activePrompts[objectiveId]
	if not prompts then return end
	PromptQueueService:Enqueue(function()
		local prompt = attachPrompt(inst, objectiveId)
		if prompt then
			prompts[prompt] = true
		end
	end)
end

function ObjectiveRuntimeService:Init()
	if self._initialized then return end
	self._initialized = true
	Workspace.DescendantAdded:Connect(function(inst)
		self:_onDescendantAdded(inst)
	end)
	GameStateService:OnStateChanged(function(state)
		if state and state.MatchState == "GameOver" then
			ObjectiveRuntimeService:ClearAllPrompts()
		end
	end)
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
