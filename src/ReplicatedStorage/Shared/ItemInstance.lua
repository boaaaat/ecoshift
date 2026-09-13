-- Item instances retain identity across inventory, chest, drops, and saves.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemInstance = {}
function ItemInstance.Copy(value)
 if type(value) ~= "table" then return value end
 local result = {}
 for key, entry in pairs(value) do result[key] = ItemInstance.Copy(entry) end
 return result
end
function ItemInstance.IsOverhaul()
 return true
end
function ItemInstance.Definition(id)
 if not ItemInstance.IsOverhaul() then return nil end
 local catalog = ReplicatedStorage.Shared:FindFirstChild("OverhaulCatalog")
 return catalog and require(catalog).Gear[id] or nil
end
function ItemInstance.New(id, amount, metadata)
 local entry = ItemInstance.Copy(metadata or {})
 entry.Id, entry.N = id, amount
 local def = ItemInstance.Definition(id)
 if id=="FieldJournal" then entry.Uid=entry.Uid or HttpService:GenerateGUID(false);entry.InstalledModules=entry.InstalledModules or {};entry.N=1 end
 if def then
  entry.Uid = entry.Uid or HttpService:GenerateGUID(false)
  entry.Grade = math.clamp(math.floor(tonumber(entry.Grade) or def.Grade or 1), 1, 8)
  if def.Kind ~= "Accessory" then
   entry.MaxDurability = def.Kind == "Armor" and (180+25*(entry.Grade-1)) or def.Kind == "Weapon" and (400+40*(entry.Grade-1)) or (300+40*(entry.Grade-1))
   entry.Durability = math.clamp(tonumber(entry.Durability) or entry.MaxDurability, 0, entry.MaxDurability)
  else entry.MaxDurability,entry.Durability=nil,nil end
  entry.Enchantments, entry.State = entry.Enchantments or {}, entry.State or {}
  entry.N = 1
 end
 return entry
end
function ItemInstance.Stackable(a, b)
 if not a or not b or a.Id ~= b.Id or a.Uid or b.Uid then return false end
 -- Scrolls and station modules carry instance data and may not be merged by ID.
 for key in pairs(a) do if key ~= "Id" and key ~= "N" then return false end end
 for key in pairs(b) do if key ~= "Id" and key ~= "N" then return false end end
 return true
end
return ItemInstance
