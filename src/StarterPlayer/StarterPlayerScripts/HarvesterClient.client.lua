-- HarvesterClient.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- OPTIMIZED: Try immediate lookup first
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
local InteractRE = Remotes and (Remotes:FindFirstChild("ResourceInteract") or Remotes:WaitForChild("ResourceInteract", 3))
local ToolConfig = require(ReplicatedStorage.Modules.ToolConfig)

local player = Players.LocalPlayer

local function raycastTarget(range, excludeTerrain)
	local camera = Workspace.CurrentCamera
	if not camera then return nil end
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filters = { player.Character }
	if excludeTerrain then
		table.insert(filters, Workspace.Terrain)
	end
	params.FilterDescendantsInstances = filters
	local result = Workspace:Raycast(ray.Origin, ray.Direction * range, params)
	return result and result.Instance or nil
end

local function findNode(hit)
	if not hit then return nil end
	local current = hit
	while current do
		if current:IsA("Model") then
			local function hasValue(name)
				return current:GetAttribute(name) ~= nil or current:FindFirstChild(name, true)
			end
			if hasValue("Health") or hasValue("Duration") or hasValue("HarvestDuration") then
				return current
			end
			local pp = current.PrimaryPart
			if pp then
				local function hasValueOn(part, name)
					return part:GetAttribute(name) ~= nil or part:FindFirstChild(name)
				end
				if hasValueOn(pp, "Health") or hasValueOn(pp, "Duration") or hasValueOn(pp, "HarvestDuration") then
					return current
				end
			end
		end
		current = current.Parent
	end
	return nil
end

local activeTool = nil
local holding = false
local loopRunning = false
local inputBeganConn = nil
local inputEndedConn = nil

local function isHarvestTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local dmg = tool:GetAttribute("Damage") or tool:GetAttribute("HarvestDamage")
	if typeof(dmg) == "number" then return true end
	local child = tool:FindFirstChild("Damage") or tool:FindFirstChild("HarvestDamage")
	return child and child:IsA("ValueBase") and typeof(child.Value) == "number"
end

local function getRange(tool)
	local cfg = ToolConfig.Read(tool)
	local range = cfg.Range or 0
	if range <= 0 then range = 8 end
	return range
end

local function getCooldown(tool)
	local cfg = ToolConfig.Read(tool)
	return math.max(0.05, tonumber(cfg.Cooldown) or 0.4)
end

local function harvestOnce(tool)
	local range = getRange(tool)
	local hit = raycastTarget(range, false)
	local node = findNode(hit)
	if not node then
		hit = raycastTarget(range, true)
		node = findNode(hit)
	end
	InteractRE:FireServer("Harvest", node)
end

local function startLoop(tool)
	if loopRunning then return end
	loopRunning = true
	task.spawn(function()
		while holding and activeTool == tool do
			harvestOnce(tool)
			task.wait(getCooldown(tool))
		end
		loopRunning = false
	end)
end

local function bindTool(tool)
	if not tool:IsA("Tool") then return end
	if not isHarvestTool(tool) then return end
	tool.Equipped:Connect(function()
		activeTool = tool
	end)
	tool.Unequipped:Connect(function()
		holding = false
		activeTool = nil
	end)
	tool.Activated:Connect(function()
		-- Single click still works
		holding = true
		startLoop(tool)
	end)
end

inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not activeTool then return end
	holding = true
	startLoop(activeTool)
end)

inputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	holding = false
end)

local function onCharacter(char)
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
		end
	end)
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
			activeTool = child
		end
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
