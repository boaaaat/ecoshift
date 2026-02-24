-- ArmorService.lua
-- Applies equipped armor from the inventory armor slot.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent.InventoryService)
local ItemDatabase = require(ReplicatedStorage.Shared.Items.ItemDatabase)
local StatsService = require(script.Parent.StatsService)

local ArmorService = {}
ArmorService._equipped = {} -- [player] = { Id = string, Instance = Instance?, Character = Model? }

local EQUIP_FOLDER = "EquippedArmor"
local MOD_ID_ARMOR = "ArmorEquip"
local MOD_ID_TEMPRES = "TempResEquip"

local ARMOR_STATS = {
	DesertCloak = { Armor = 12, TempRes = 4 },
	SwampWaders = { Armor = 16, TempRes = 2 },
	FrostParka = { Armor = 20, TempRes = 6 },
	VolcanicPlate = { Armor = 26, TempRes = 5 },
	CrystalWeave = { Armor = 24, TempRes = 4 },
	AdaptiveSurvivalSuit = { Armor = 34, TempRes = 7 },
}

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

local function clearArmor(plr)
	local entry = ArmorService._equipped[plr]
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
	primary.Anchored = false
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
		if clone:IsA("Accessory") or clone:IsA("Clothing") then
			clone.Parent = char
		elseif clone:IsA("Tool") then
			clone.Parent = char
		elseif clone:IsA("Model") then
			clone.Parent = equipFolder
			attachModelToCharacter(clone, char)
		elseif clone:IsA("BasePart") then
			clone.Parent = equipFolder
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
	plr:SetAttribute("EquippedArmor", itemId)

	local stats = ARMOR_STATS[itemId]
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
	InventoryService:OnChanged(function(plr)
		ArmorService:Sync(plr)
	end)
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function()
			ArmorService:Sync(plr)
		end)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		ArmorService._equipped[plr] = nil
	end)
end

return ArmorService
