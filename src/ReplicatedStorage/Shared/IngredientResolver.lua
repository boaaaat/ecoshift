-- Resolve flexible trophy requirements to exact inventory debits before any mutation.
local Workbench=require(script.Parent.WorkbenchConfig)
local Resolver={}
function Resolver.Resolve(ingredients,quantity,count,player)
 local available,paid={},{}
 local function remaining(id) if available[id]==nil then available[id]=math.max(0,count(id) or 0) end;return available[id] end
 local function take(id,n)
  if remaining(id)<n then return false end
  available[id]-=n;paid[id]=(paid[id] or 0)+n;return true
 end
 -- Fixed inputs reserve first, so flexible choices cannot steal required materials.
 for _,entry in ipairs(ingredients or {}) do
  if not entry.AnyOf and not take(entry.Id,Workbench:IngredientCost(entry,player)*quantity) then return nil,"Missing "..entry.Id end
 end
 for _,entry in ipairs(ingredients or {}) do
  if entry.AnyOf then
   -- Distinctness is per crafted output, allowing the same four types in later batches.
   for _=1,quantity do
    local needed=Workbench:IngredientCost(entry,player)
    local choices=table.clone(entry.AnyOf)
    if entry.Distinct then table.sort(choices,function(a,b)return remaining(a)==remaining(b) and a<b or remaining(a)>remaining(b) end) end
    for _,id in ipairs(choices) do
     local n=math.min(remaining(id),needed,entry.Distinct and 1 or needed)
     if n>0 then take(id,n);needed-=n end
     if needed==0 then break end
    end
    if needed>0 then return nil,entry.Distinct and "Need four different deep-region trophies" or "Need a deep-region trophy" end
   end
  end
 end
 local costs={};for id,n in pairs(paid) do table.insert(costs,{Id=id,N=n}) end
 table.sort(costs,function(a,b)return a.Id<b.Id end);return costs
end
function Resolver.Count(snapshot,id)
 local n=0;for _,bag in ipairs({snapshot and snapshot.Hotbar or {},snapshot and snapshot.Storage or {}}) do for _,entry in pairs(bag) do if entry and entry.Id==id then n+=entry.N end end end;return n
end
function Resolver.Max(ingredients,snapshot,player,limit)
 local low,high=0,limit or 99
 while low<high do
  local mid=math.ceil((low+high)/2)
  if Resolver.Resolve(ingredients,mid,function(id)return Resolver.Count(snapshot,id) end,player) then low=mid else high=mid-1 end
 end
 return low
end
return Resolver
