-- ObjectiveRuntimeService.lua
-- Adds simple proximity prompts for active objectives.
local Workspace = game:GetService("Workspace")

local ObjectiveService = require(script.Parent.ObjectiveService)

local ObjectiveRuntimeService = {}
ObjectiveRuntimeService._activePrompts = {}

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
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Contribute"
		prompt.ObjectText = objectiveId
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	prompt.Enabled = true
	prompt.Triggered:Connect(function(plr)
		ObjectiveService:Advance(objectiveId, 0.2)
	end)
	return prompt
end

function ObjectiveRuntimeService:OnStart(objectiveId)
	local anchors = findAnchors(objectiveId)
	self._activePrompts[objectiveId] = self._activePrompts[objectiveId] or {}
	for _, part in ipairs(anchors) do
		local prompt = attachPrompt(part, objectiveId)
		table.insert(self._activePrompts[objectiveId], prompt)
	end
end

function ObjectiveRuntimeService:OnEnd(objectiveId)
	local prompts = self._activePrompts[objectiveId]
	if not prompts then return end
	for _, prompt in ipairs(prompts) do
		if prompt and prompt.Parent then
			prompt.Enabled = false
		end
	end
	self._activePrompts[objectiveId] = nil
end

function ObjectiveRuntimeService:Init()
	_G.Ecoshift = _G.Ecoshift or {}
	if type(_G.Ecoshift.OnObjectiveStartAdd) == "function" then
		_G.Ecoshift.OnObjectiveStartAdd(function(id)
			ObjectiveRuntimeService:OnStart(id)
		end)
	end
	if type(_G.Ecoshift.OnObjectiveEndAdd) == "function" then
		_G.Ecoshift.OnObjectiveEndAdd(function(id)
			ObjectiveRuntimeService:OnEnd(id)
		end)
	end
end

return ObjectiveRuntimeService
