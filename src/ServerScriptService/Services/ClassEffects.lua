local RS = game:GetService("ReplicatedStorage")
local Classes = require(RS.Shared.ClassConfig)
local Map = require(RS.Shared.ResourceItemMap)
local E = {}
function E.Kind(node)
	local id = node:GetAttribute("DropItemId") or node:GetAttribute("ItemId") or node.Name
	return Classes.ResourceKind(Map.Normalize(id))
end
function E.Power(player, node)
	local bonus = player:GetAttribute("Class_GatherPower") or 0
	if E.Kind(node)=="Mineral" then bonus += player:GetAttribute("Class_MineralPower") or 0; bonus += player:GetAttribute("ClassMineralPower") or 0 end
	bonus += player:GetAttribute("ClassHarvestPower") or 0
	return 1 + math.clamp(bonus,0,.75)
end
function E.Duration(player, node, duration)
	local bonus = (player:GetAttribute("Class_GatherTimeReduction") or 0) + (player:GetAttribute("ClassHarvestReduction") or 0)
	if E.Kind(node)=="Plant" then bonus += player:GetAttribute("Class_PlantTimeReduction") or 0 end
	return duration * (1-math.clamp(bonus,0,.5))
end
function E.Extra(player, node)
	if node:GetAttribute("ObjectiveId") or node:GetAttribute("ObjectiveInstanceId") or node:FindFirstAncestor("Objectives") then return 0 end
	local kind = E.Kind(node)
	local chance = kind=="Plant" and player:GetAttribute("Class_PlantYield") or kind=="Mineral" and player:GetAttribute("Class_MineralYield") or 0
	return math.random() < (chance or 0) and 1 or 0
end
function E.ReviveDuration(player, duration)
	return duration * math.max(.25,(1-(player:GetAttribute("Class_ReviveReduction") or 0))*(1-(player:GetAttribute("ClassReviveReduction") or 0)))
end
return E
