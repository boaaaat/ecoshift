-- Current catalog adapter for tools, inventory descriptions, and prototype art.
local C=require(script.Parent.OverhaulCatalog)
local Stats={ToolPower={},WeaponPower={},MeleeRange=11,HarvestRange=10,BowRange=120,ToolCooldown=.55}
for id,def in pairs(C.Gear) do if def.Kind=="Tool" then Stats.ToolPower[id]=def.Power elseif def.Kind=="Weapon" then Stats.WeaponPower[id]=def.Damage end end
function Stats.Description(id) return C.Items[id] and C.Items[id].Description or nil end
return Stats
