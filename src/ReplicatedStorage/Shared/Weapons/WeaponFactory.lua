-- One shared weapon profile adapter; all numbers originate in the current gear catalog.
local Catalog=require(script.Parent.Parent.OverhaulCatalog)
local Factory={}
function Factory.GetType(tool)
 local def=tool and Catalog.Gear[tool.Name]
 if not def or def.Kind~="Weapon" then return "" end
 return def.WeaponFamily=="Bow" and "Bow" or def.WeaponFamily=="Staff" and "Gun" or "Sword"
end
function Factory.Create(tool,owner)
 local kind=Factory.GetType(tool)
 if kind=="" then return nil end
 local def=Catalog.Gear[tool.Name]
 local profile={Tool=tool,Owner=owner}
 function profile:GetType()return kind end
 function profile:GetDamage()return (tool:GetAttribute("Durability") or 1)>0 and def.Damage or 0 end
 function profile:GetRange()return def.Reach end
 function profile:GetCooldown()return def.AttackCycle end
 function profile:GetNumber(name,default)if name=="Range" then return self:GetRange() end;return def[name] or default end
 function profile:GetChargeTime()return 1.3 end
 function profile:ComputeDamage(ratio)return def.Damage*math.clamp(ratio,0.25,1) end
 return profile
end
return Factory
