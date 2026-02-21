-- HarvesterClient.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
local function resolveInteractRemote()
	if not Remotes then return nil end
	return Remotes:FindFirstChild(Config.RemoteNames.Interact)
		or Remotes:WaitForChild(Config.RemoteNames.Interact, 3)
end
local InteractRE = resolveInteractRemote()
local ToolConfig = require(ReplicatedStorage.Modules.ToolConfig)
local missingInteractWarned = false

local player = Players.LocalPlayer

local function raycastTarget(origin, direction, excludeTerrain)
	if not origin or not direction then return nil, nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filters = { player.Character }
	if excludeTerrain then
		table.insert(filters, Workspace.Terrain)
	end
	params.FilterDescendantsInstances = filters
	local result = Workspace:Raycast(origin, direction, params)
	return result and result.Instance or nil, result
end

local function getMouseRay()
	local camera = Workspace.CurrentCamera
	if not camera then return nil, nil end
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
	return ray.Origin, ray.Direction
end

local function acquireHarvestHit(range)
	local camOrigin, camDirection = getMouseRay()
	if not camOrigin or not camDirection then
		return nil
	end

	local acquireDistance = math.max((range or 8) * 6, 64)
	local camHit, camResult = raycastTarget(camOrigin, camDirection * acquireDistance, false)
	if not camHit then
		camHit, camResult = raycastTarget(camOrigin, camDirection * acquireDistance, true)
	end

	local char = player.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
	local aimPosition = (camResult and camResult.Position) or (camOrigin + camDirection * acquireDistance)

	if root and aimPosition then
		local toAim = aimPosition - root.Position
		if toAim.Magnitude > 0.001 then
			local rootHit = nil
			local rootDirection = toAim.Unit * (math.max(range or 8, 8) + 2)
			rootHit = select(1, raycastTarget(root.Position, rootDirection, false))
			if not rootHit then
				rootHit = select(1, raycastTarget(root.Position, rootDirection, true))
			end
			if rootHit then
				return rootHit
			end
		end
	end

	return camHit
end

local function findNode(hit)
	if not hit then return nil end
	local function hasValue(inst, name)
		return inst:GetAttribute(name) ~= nil or inst:FindFirstChild(name, true) ~= nil
	end
	local function hasHarvestMarkers(inst)
		return hasValue(inst, "Health")
			or hasValue(inst, "MaxHealth")
			or hasValue(inst, "Duration")
			or hasValue(inst, "HarvestDuration")
	end
	local current = hit
	while current do
		if current:IsA("Model") then
			if hasHarvestMarkers(current) then
				return current
			end
			local pp = current.PrimaryPart
			if pp and hasHarvestMarkers(pp) then
				return current
			end
		elseif current:IsA("BasePart") then
			if hasHarvestMarkers(current) then
				return current
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
local boundTools = setmetatable({}, { __mode = "k" })
local characterConnections = {}

local function disconnectCharacterConnections()
	for _, conn in ipairs(characterConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(characterConnections)
end

local function hasWeaponType(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local wAttr = tool:GetAttribute("WeaponType")
	if wAttr ~= nil then
		if typeof(wAttr) == "string" then
			return wAttr ~= ""
		end
		return tostring(wAttr) ~= ""
	end
	local wChild = tool:FindFirstChild("WeaponType")
	if wChild and wChild:IsA("ValueBase") then
		if typeof(wChild.Value) == "string" then
			return wChild.Value ~= ""
		end
		return tostring(wChild.Value or "") ~= ""
	end
	return false
end

local function isHarvestTool(tool)
	if not tool or not tool:IsA("Tool") then return false end
	-- If it's a weapon, do not treat as a harvest tool
	if hasWeaponType(tool) then
		return false
	end
	local t = tool:GetAttribute("ToolType")
	if typeof(t) == "string" and t ~= "" then
		return true
	end
	local child = tool:FindFirstChild("ToolType")
	if child then
		if child:IsA("StringValue") then
			return child.Value ~= ""
		elseif child:IsA("ValueBase") then
			return tostring(child.Value or "") ~= ""
		end
	end
	return false
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
	if not InteractRE then
		InteractRE = resolveInteractRemote()
	end
	if not InteractRE then
		if not missingInteractWarned then
			missingInteractWarned = true
			warn("[HarvesterClient] Missing interact remote:", Config.RemoteNames.Interact)
		end
		return
	end
	missingInteractWarned = false
	local range = getRange(tool)
	local hit = acquireHarvestHit(range)
	local node = findNode(hit)
	InteractRE:FireServer("Harvest", node or hit)
end

local function startLoop(tool)
	if loopRunning then return end
	loopRunning = true
	task.spawn(function()
		while holding and activeTool == tool do
			-- Ensure tool is still equipped
			if not tool.Parent or tool.Parent ~= player.Character then
				break
			end
			harvestOnce(tool)
			task.wait(getCooldown(tool))
		end
		loopRunning = false
	end)
end

local function bindTool(tool)
	if not tool:IsA("Tool") then return end
	if not isHarvestTool(tool) then return end
	if boundTools[tool] then return end
	boundTools[tool] = true

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
	if not activeTool or activeTool.Parent ~= player.Character then return end
	holding = true
	startLoop(activeTool)
end)

inputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	holding = false
end)

local function onCharacter(char)
	disconnectCharacterConnections()
	local backpack = player:WaitForChild("Backpack")
	characterConnections[#characterConnections + 1] = char.ChildRemoved:Connect(function(child)
		if child == activeTool then
			holding = false
			activeTool = nil
		end
	end)
	characterConnections[#characterConnections + 1] = backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
	characterConnections[#characterConnections + 1] = char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			if isHarvestTool(child) then
				activeTool = child
			end
		end
	end)
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
			if isHarvestTool(child) then
				activeTool = child
			end
		end
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
