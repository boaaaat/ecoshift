-- ArmorService.lua
-- Applies equipped armor from the inventory armor slot.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local StatsService = require(script.Parent.StatsService)
local SurvivalConfig = require(ReplicatedStorage.Shared.SurvivalConfig)

local ArmorService = {}
ArmorService._equipped = {} -- [player] = { Id = string, Instance = Instance?, Character = Model? }

local EQUIP_FOLDER = "EquippedArmor"
local MOD_ID_ARMOR = "ArmorEquip"
local MOD_ID_TEMPRES = "TempResEquip"
local MOUNT_ATTEMPTS = 10
local MOUNT_RETRY_SECONDS = 0.25

local ARMOR_STATS = SurvivalConfig.ARMOR

local function isArmor(itemId)
	local item = ItemDatabase:Get(itemId)
	return item and item:HasTag("Armor") or false
end

local function getPrimary(model)
	if model.PrimaryPart then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function isGeneratedArmor(instance)
	return instance and instance:IsA("Accessory") and instance:GetAttribute("ArtStyle") == "Expedition"
		and instance:GetAttribute("ArtKind") == "Armor"
end

local function mountedHandle(entry)
	local handle = entry.Instance:FindFirstChild("Handle")
	local torso = entry.Character:FindFirstChild("UpperTorso") or entry.Character:FindFirstChild("Torso")
	local weld = handle and handle:FindFirstChild("AccessoryWeld")
	if torso and handle and handle:IsA("BasePart") and weld and weld:IsA("Weld")
		and ((weld.Part0 == handle and weld.Part1 == torso) or (weld.Part1 == handle and weld.Part0 == torso)) then return handle end
	local rigid = handle and handle:FindFirstChild("AccessoryRigidConstraint")
	if torso and handle and handle:IsA("BasePart") and rigid and rigid:IsA("RigidConstraint") and rigid.Enabled then
		local a, b = rigid.Attachment0, rigid.Attachment1
		if a and b and ((a.Parent == handle and b.Parent == torso) or (b.Parent == handle and a.Parent == torso)) then return handle end
	end
	return nil
end

local function clearGeneratedMounts(handle)
	for _, name in ipairs({ "AccessoryWeld", "AccessoryRigidConstraint" }) do
		local joint = handle:FindFirstChild(name)
		if joint then joint:Destroy() end
	end
end

local function tryGeneratedMount(entry, allowFallback)
	local accessory, char = entry.Instance, entry.Character
	local mounted = mountedHandle(entry)
	if mounted then mounted.Anchored = false; return true end
	local handle = accessory:FindFirstChild("Handle")
	local attachment = handle and handle:FindFirstChild("BodyFrontAttachment")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not handle or not handle:IsA("BasePart") or not attachment or not attachment:IsA("Attachment")
		or not hum or not torso or not torso:IsA("BasePart") then return false end
	local target = torso:FindFirstChild("BodyFrontAttachment")
	if target and not target:IsA("Attachment") then target = nil end
	if target and not entry.NativeMountRequested then
		-- R15 may create its attachment constraint after AddAccessory returns.
		-- Issue one native request, then poll without interrupting its parenting.
		entry.NativeMountRequested = true
		clearGeneratedMounts(handle)
		accessory.Parent = nil
		handle.Anchored = false
		local ok = pcall(function() hum:AddAccessory(accessory) end)
		if ok and mountedHandle(entry) then handle.Anchored = false; return true end
		if not accessory.Parent then accessory.Parent = char end
	end
	if not allowFallback then return false end
	-- Legacy/custom rigs may omit the body attachment. Do not modify their rig.
	local bodyFrame = target and target.CFrame or CFrame.new(0, 0, -torso.Size.Z * 0.5)
	-- Parenting can rebuild native accessory joints: perform it before our fallback.
	handle.Anchored = false
	accessory.Parent = char
	clearGeneratedMounts(handle)
	handle.CFrame = torso.CFrame * bodyFrame * attachment.CFrame:Inverse()
	local weld = Instance.new("Weld")
	weld.Name, weld.Part0, weld.Part1 = "AccessoryWeld", torso, handle
	weld.C0, weld.C1, weld.Parent = bodyFrame, attachment.CFrame, handle
	entry.MountFallback = true
	return true
end

local function recoverGeneratedMount(plr, entry)
	if not isGeneratedArmor(entry.Instance) or entry.MountTicket or entry.MountFinished then return end
	local ticket = {}
	entry.MountTicket = ticket
	entry.NativeMountRequested = nil
	local function attempt()
		if entry.MountTicket ~= ticket or ArmorService._equipped[plr] ~= entry or plr.Parent ~= Players
			or plr.Character ~= entry.Character or not entry.Character.Parent or not entry.Instance.Parent then
			if entry.MountTicket == ticket then entry.MountTicket = nil end
			return
		end
		entry.MountAttempts = (entry.MountAttempts or 0) + 1
		if tryGeneratedMount(entry, entry.MountAttempts >= MOUNT_ATTEMPTS) then
			entry.MountTicket, entry.MountAttempts = nil, 0
		elseif entry.MountAttempts < MOUNT_ATTEMPTS then
			task.delay(MOUNT_RETRY_SECONDS, attempt)
		else
			entry.MountTicket, entry.MountFinished = nil, true
			warn("[ArmorService] Generated armor could not mount:", entry.Id, plr.Name)
		end
	end
	attempt()
end

local function clearArmor(plr)
	local entry = ArmorService._equipped[plr]
	if entry then entry.MountTicket = nil end
	if entry and entry.Instance and entry.Instance.Parent then
		entry.Instance:Destroy()
	end
	ArmorService._equipped[plr] = nil
	if StatsService and StatsService.RemoveModifier then
		StatsService:RemoveModifier(plr, "Armor", MOD_ID_ARMOR)
		StatsService:RemoveModifier(plr, "TemperatureResistance", MOD_ID_TEMPRES)
	end
	local char = plr.Character
	if char then
		for _, kind in ipairs({"Heat", "Cold", "Toxin", "Wet"}) do char:SetAttribute("GearRes_" .. kind, 0) end
		local folder = char:FindFirstChild(EQUIP_FOLDER)
		if folder then folder:Destroy() end
	end
	plr:SetAttribute("EquippedArmor", nil)
end

local function attachModelToCharacter(model, character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local primary = getPrimary(model)
	if not primary then return end
	model.PrimaryPart = primary
	model:PivotTo(hrp.CFrame)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			if part ~= primary then
				local partWeld = Instance.new("WeldConstraint")
				partWeld.Part0 = primary
				partWeld.Part1 = part
				partWeld.Parent = part
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = primary
	weld.Parent = primary
end

function ArmorService:Equip(plr, itemId)
	if not itemId or not isArmor(itemId) then
		clearArmor(plr)
		return
	end
	local char = plr.Character
	if not char then
		ArmorService._equipped[plr] = { Id = itemId, Instance = nil, Character = nil }
		plr:SetAttribute("EquippedArmor", itemId)
		return
	end

	local entry = ArmorService._equipped[plr]
	if entry and entry.Id == itemId and entry.Character == char and entry.Instance and entry.Instance.Parent then
		recoverGeneratedMount(plr, entry)
		return
	end

	clearArmor(plr)

	local itemsFolder = ServerStorage:FindFirstChild("GameItems")
	local template = itemsFolder and itemsFolder:FindFirstChild(itemId)
	local clone = template and template:Clone() or nil

	local equipFolder = char:FindFirstChild(EQUIP_FOLDER)
	if not equipFolder then
		equipFolder = Instance.new("Folder")
		equipFolder.Name = EQUIP_FOLDER
		equipFolder.Parent = char
	end

	if clone then
		if clone:IsA("Accessory") then
			if isGeneratedArmor(clone) then
				local handle = clone:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then handle.Anchored = true end
				clone.Parent = equipFolder
			else
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:AddAccessory(clone) else clone.Parent = char end
			end
		elseif clone:IsA("Clothing") then
			clone.Parent = char
		elseif clone:IsA("Tool") then
			clone.Parent = char
		elseif clone:IsA("Model") then
			clone.Parent = equipFolder
			attachModelToCharacter(clone, char)
		elseif clone:IsA("BasePart") then
			clone.Parent = equipFolder
			clone.CanCollide = false
			clone.Massless = true
			clone.CFrame = char:GetPivot()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				clone.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = clone
				weld.Parent = clone
			else
				clone.Anchored = true
			end
		else
			clone.Parent = equipFolder
		end
	end

	ArmorService._equipped[plr] = { Id = itemId, Instance = clone, Character = char }
	if clone then recoverGeneratedMount(plr, ArmorService._equipped[plr]) end
	plr:SetAttribute("EquippedArmor", itemId)

	local stats = ARMOR_STATS[itemId]
	for _, kind in ipairs({"Heat", "Cold", "Toxin", "Wet"}) do
		char:SetAttribute("GearRes_" .. kind, stats and stats[kind .. "Resistance"] or 0)
	end
	if StatsService and StatsService.AddModifier then
		if stats and stats.Armor then
			StatsService:AddModifier(plr, "Armor", stats.Armor, "Add", nil, MOD_ID_ARMOR)
		else
			StatsService:RemoveModifier(plr, "Armor", MOD_ID_ARMOR)
		end
		if stats and stats.TempRes then
			StatsService:AddModifier(plr, "TemperatureResistance", stats.TempRes, "Add", nil, MOD_ID_TEMPRES)
		else
			StatsService:RemoveModifier(plr, "TemperatureResistance", MOD_ID_TEMPRES)
		end
	end
end

function ArmorService:Sync(plr)
	local inv = InventoryService:GetAll(plr)
	if not inv then return end
	local desired = inv.Armor and inv.Armor.Id or nil
	if not desired then
		if ArmorService._equipped[plr] then
			clearArmor(plr)
		end
		return
	end
	ArmorService:Equip(plr, desired)
end

function ArmorService:Init()
	if self._initialized then return end
	self._initialized = true
	InventoryService:OnChanged(function(plr)
		ArmorService:Sync(plr)
	end)
	local function bindPlayer(plr)
		plr.CharacterAdded:Connect(function()
			task.defer(function() ArmorService:Sync(plr) end)
		end)
		plr.CharacterAppearanceLoaded:Connect(function(char)
			local entry = ArmorService._equipped[plr]
			if plr.Character ~= char or not entry or entry.Character ~= char or not isGeneratedArmor(entry.Instance) then return end
			entry.MountTicket, entry.MountAttempts, entry.MountFinished = nil, 0, nil
			if entry.MountFallback then
				local handle = entry.Instance:FindFirstChild("Handle")
				if handle then clearGeneratedMounts(handle) end
				if handle and handle:IsA("BasePart") then handle.Anchored = true end
				entry.MountFallback = nil
			end
			recoverGeneratedMount(plr, entry)
		end)
		ArmorService:Sync(plr)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do bindPlayer(plr) end
	Players.PlayerRemoving:Connect(function(plr)
		local entry = ArmorService._equipped[plr]
		if entry then entry.MountTicket = nil end
		ArmorService._equipped[plr] = nil
	end)
end

return ArmorService
