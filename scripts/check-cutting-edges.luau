-- Studio test of visible cutting geometry after serialization, not just welds.
local Art=(...) or require(game.ReplicatedStorage.Shared.Art.OverhaulGearModels)
local Catalog=require(game.ReplicatedStorage.Shared.OverhaulCatalog)
local folder=Instance.new("Folder");folder.Name="_CuttingEdgeGeometryCheck";folder.Parent=workspace
local models,rays,missChecks=0,0,0
local ok,err=pcall(function()
 for id,def in pairs(Catalog.Gear) do
  local family=def.WeaponFamily or def.ToolFamily
  if family~="Sword" and family~="Dagger" and family~="Sickle" then continue end
  local tool=Art.Create(id,def)
  local edge=tool:FindFirstChild(family=="Sickle" and "SickleEdge" or "BladePoint")
  assert(edge and edge:IsA("UnionOperation") and edge:GetAttribute("ConnectedSolidCount")==1,id.." missing continuous cutting edge")
  local body=tool:FindFirstChild(family=="Sickle" and "HookSocket" or "Blade")
  local data=game:GetService("SerializationService"):SerializeInstancesAsync({edge,body})
  local copies=game:GetService("SerializationService"):DeserializeInstancesAsync(data)
  for _,p in ipairs(copies) do p.Anchored=true;p.CanQuery=true;p.CFrame=CFrame.new(0,9000,0)*p.CFrame;p.Parent=folder end
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=copies
  local function hit(x,y)
   return workspace:Raycast(Vector3.new(x,9000+y,-2),Vector3.new(0,0,4),params)~=nil
  end
  if family=="Sickle" then
   for i=0,95 do
    local t=i/100;local u=1-t
    local x=-.14*3*u*u*t-1.35*3*u*t*t-1.02*t^3
    local y=1.5+.92*3*u*u*t+.9*3*u*t*t-.55*t^3
    assert(hit(x,y),id.." sickle gap at curve t="..t);rays+=1
   end
   for _,p in ipairs({Vector2.new(-.4,1.45),Vector2.new(-.6,1.5),Vector2.new(-.25,1.75)}) do
    assert(not hit(p.X,p.Y),id.." sickle hook interior filled");missChecks+=1
   end
   assert(not tool:FindFirstChild("HookPoint") and not tool:FindFirstChild("HookBack"),id.." retains detached tip")
  else
   local short=family=="Dagger";local base=.65+(short and 1.3 or 2.35);local height=short and .45 or .65;local width=short and .34 or .51
   for i=0,64 do
    local y=base-.08+i*(height+.05)/64
    assert(hit(0,y),id.." blade-to-tip gap at y="..y);rays+=1
   end
   for i=1,9 do
    local t=i/10;local halfWidth=width*.5*(1-t)
    assert(not hit(halfWidth+.07,base+t*height),id.." blunt/flat tip outline");missChecks+=1
   end
  end
  for _,p in ipairs(copies)do p:Destroy()end
  tool:Destroy();models+=1
 end
end)
folder:Destroy();assert(ok,err)
return {models=models,continuityRays=rays,negativeOutlineRays=missChecks,failures=0}
