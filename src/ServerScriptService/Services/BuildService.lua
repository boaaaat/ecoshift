-- BuildService.lua
-- Server-authoritative grid placement with costs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local GridService = require(script.Parent.GridService)
local InventoryService = require(script.Parent.InventoryService)

local BuildService = {}
BuildService._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
BuildService._remoteBuild = Util.GetRemote(BuildService._remotesFolder, Config.RemoteNames.Build)

local function isAllowedType(t)
	return Config.BUILD.AllowedTypes[t] == true
end

local function withinRange(plr, worldPos)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - worldPos).Magnitude <= (Config.GRID.BuildMaxDistance or 45)
end

local function getPrefab(buildType)
	local folder = ServerStorage:FindFirstChild("BuildPrefabs")
	if folder then
		return folder:FindFirstChild(buildType)
	end
	return nil
end

local function createFallbackPart(buildType, position)
	local part = Instance.new("Part")
	part.Size = Vector3.new(Config.GRID.Size, Config.GRID.Size, Config.GRID.Size)
	part.Anchored = true
	part.Position = position
	part.Name = "Build_" .. buildType
	part:SetAttribute("BuildType", buildType)
	return part
end

local function applyDurability(inst)
	local dur = Instance.new("NumberValue")
	dur.Name = "Durability"
	dur.Value = 100
	dur.Parent = inst
	inst:SetAttribute("DurabilityMax", 100)
end

function BuildService:Place(plr, buildType, worldPos)
	if not isAllowedType(buildType) then return false end
	if not withinRange(plr, worldPos) then return false end
	local dist = math.sqrt(worldPos.X * worldPos.X + worldPos.Z * worldPos.Z)
	if dist > (Config.WORLD.WorldRadius or 2200) then return false end
	if dist < (Config.WORLD.CenterExclusionRadius or 0) then return false end

	local gx, gz = GridService:WorldToGrid(worldPos)
	if GridService:IsOccupied(gx, gz) then return false end

	local cost = Config.BUILD.Costs[buildType] or {}
	local buildMult = tonumber(plr:GetAttribute("Role_Build")) or 1.0
	local adjusted = {}
	for _, entry in ipairs(cost) do
		local n = math.max(1, math.floor((entry.N or 1) / math.max(buildMult, 0.1)))
		adjusted[#adjusted + 1] = { Id = entry.Id, N = n }
	end
	if not InventoryService:PayCost(plr, adjusted) then return false end

	local pos = GridService:GridToWorld(gx, gz, worldPos.Y)
	local prefab = getPrefab(buildType)
	local inst
	if prefab then
		inst = prefab:Clone()
		if inst:IsA("Model") then
			inst:PivotTo(CFrame.new(pos))
		elseif inst:IsA("BasePart") then
			inst.CFrame = CFrame.new(pos)
		end
	else
		inst = createFallbackPart(buildType, pos)
	end

	inst.Parent = workspace
	inst:SetAttribute("OwnerUserId", plr.UserId)
	inst:SetAttribute("GridX", gx)
	inst:SetAttribute("GridZ", gz)
	applyDurability(inst)
	pcall(function() game:GetService("CollectionService"):AddTag(inst, "Structure") end)

	GridService:Reserve(gx, gz, plr.UserId, inst)
	return true
end

function BuildService:Remove(plr, target)
	if typeof(target) ~= "Instance" or not target.Parent then return false end
	local owner = target:GetAttribute("OwnerUserId")
	if owner and owner ~= plr.UserId then return false end
	local pos = target:IsA("Model") and target:GetPivot().Position or target.Position
	if not withinRange(plr, pos) then return false end
	local gx = target:GetAttribute("GridX")
	local gz = target:GetAttribute("GridZ")
	if typeof(gx) == "number" and typeof(gz) == "number" then
		GridService:Release(gx, gz)
	else
		GridService:ReleaseByInstance(target)
	end
	target:Destroy()
	return true
end

function BuildService:Bind()
	if not self._remoteBuild then return end
	self._remoteBuild.OnServerEvent:Connect(function(plr, action, payload)
		if type(action) ~= "string" then return end
		if action == "Place" then
			local buildType = payload and payload.Type
			local pos = payload and payload.Position
			if typeof(pos) ~= "Vector3" or type(buildType) ~= "string" then return end
			pcall(function() BuildService:Place(plr, buildType, pos) end)
		elseif action == "Remove" then
			local target = payload and payload.Target
			pcall(function() BuildService:Remove(plr, target) end)
		end
	end)
end

return BuildService
