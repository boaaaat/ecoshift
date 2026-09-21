-- Studio geometry regression. Optional fresh Art module can be passed by MCP.
-- Raycasts through the CSG collision surface check continuity beyond weld links.
local Art=(...) or require(game.ReplicatedStorage.Shared.Art.OverhaulGearModels)
local Catalog=require(game.ReplicatedStorage.Shared.OverhaulCatalog)
local folder=Instance.new("Folder");folder.Name="_PickHeadGeometryCheck";folder.Parent=workspace
local checked,rays,outsideChecks=0,0,0
local failure
local ok,err=pcall(function()
 for id,definition in pairs(Catalog.Gear) do
  if definition.ToolFamily~="Pickaxe" and definition.ToolFamily~="Universal" then continue end
  local tool=Art.Create(id,definition)
  local head=tool:FindFirstChild("ForgedPickHead")
  assert(head and head:IsA("UnionOperation"),id.." missing continuous head")
  assert(head:GetAttribute("ConnectedSolidCount")==1,id.." disconnected authored solids")
  assert(not tool:FindFirstChild("PickBeak") and not tool:FindFirstChild("PickShoulder") and not tool:FindFirstChild("HatchetBlade"),id.." retained obsolete detached head")
  local data=game:GetService("SerializationService"):SerializeInstancesAsync({head})
  local copy=game:GetService("SerializationService"):DeserializeInstancesAsync(data)[1]
  copy.Anchored=true;copy.CanQuery=true;copy.CFrame=CFrame.new(0,9000,0)*copy.CFrame;copy.Parent=folder
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={copy}
  -- Stop 0.06 studs before the zero-area mathematical points. Physics convex
  -- decomposition simplifies the final needle tips; the visual solid retains them.
  for i=0,96 do
   local x=-1.29+i*2.58/96
   local y=1.5+.12-.75*(math.abs(x)/1.35)^1.75
   assert(workspace:Raycast(Vector3.new(x,9000+y,-2),Vector3.new(0,0,4),params),id.." head has a gap at x="..x)
   rays+=1
  end
  for i=1,23 do
   local x=-1.35+i*2.7/24;local t=math.abs(x)/1.35
   local top=1.5+.12-.75*t^1.75+.2*(1-t)^.72
   assert(not workspace:Raycast(Vector3.new(x,9000+top+.12,-2),Vector3.new(0,0,4),params),id.." filled/blunt upper silhouette at "..x)
   outsideChecks+=1
  end
  copy:Destroy();tool:Destroy();checked+=1
 end
end)
folder:Destroy()
assert(ok,err)
return {models=checked,continuityRays=rays,emptySilhouetteRays=outsideChecks,serializedRoundTrips=checked,failures=0}
