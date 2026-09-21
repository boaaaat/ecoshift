-- Shared presentation metadata. Combat, harvesting and inventory remain authoritative.
local Catalog = require(script.Parent.Parent.OverhaulCatalog)
local Presentation = {}
local CF, A = CFrame.new, CFrame.Angles

function Presentation.Family(tool)
	local id = tool:GetAttribute("InventoryItemId") or tool.Name
	local def = Catalog.Gear[id]
	if def and (def.WeaponFamily or def.ToolFamily) then return def.WeaponFamily or def.ToolFamily end
	if id == "Bucket" then return "Bucket" end
	if id == "WaterFlask" or id == "Water" or id == "Antidote" or id == "RecoveryTonic" then return "Drink" end
	local item = Catalog.Items[id]
	for _, tag in ipairs(item and item.Tags or {}) do
		if tag == "Food" then return "Food" end
		if tag == "Medicine" or tag == "Repair" then return "Medicine" end
	end
	return tool:GetAttribute("ArtFamily") or "Carry"
end

function Presentation.Configure(tool)
	local family = Presentation.Family(tool)
	tool:SetAttribute("PoseFamily", family)
	-- An authored grip can be provided in handle space for off-center prefabs.
	-- Generated gear has its grasp centered on Handle, independent of its bounds.
	if tool:GetAttribute("ArtStyle") == "Expedition" and tool:GetAttribute("ArtKind") then
		tool.Grip = CF(0, -.04, 0) * A(-math.pi / 2, 0, family == "Dagger" and -.08 or 0)
	end
end

function Presentation.Action(tool, kind, direction)
	tool:SetAttribute("ItemActionKind", kind)
	if direction and direction.Magnitude > .001 then tool:SetAttribute("ItemAimDirection", direction.Unit) end
	tool:SetAttribute("ItemActionStarted", workspace:GetServerTimeNow())
end

return Presentation
