-- The expedition catalog is authoritative for all new-only game content.
local RS=game:GetService("ReplicatedStorage")
local Item=require(script.Parent.Item)
local Catalog=require(script.Parent.Parent.OverhaulCatalog)
local Database={}
local cache={}
local function build(def)
 local data=table.clone(def)
 local folder=RS:FindFirstChild("ItemIcons")
 local node=folder and folder:FindFirstChild(def.Id)
 if not data.Icon and node then
  if node:IsA("StringValue") then data.Icon=node.Value
  elseif node:IsA("Decal") then data.Icon=node.Texture
  elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then data.Icon=node.Image
  else data.Icon=node:GetAttribute("Icon") or node:GetAttribute("Image") end
 end
 return Item.new(data)
end
function Database:Get(id)
 local def=Catalog.Items[id]
 if not def then return nil end
 if not cache[id] then cache[id]=build(def) end
 return cache[id]
end
function Database:All()
 local list={}
 for _,def in pairs(Catalog.Items) do
  if not table.find(def.Tags or {},"RecipeRequirement") then table.insert(list,build(def)) end
 end
 table.sort(list,function(a,b) return a.Id<b.Id end)
 return list
end
function Database:Define(def)
 if type(def)~="table" or type(def.Id)~="string" then return end
 Catalog.Items[def.Id]=def; cache[def.Id]=nil
end
return Database
