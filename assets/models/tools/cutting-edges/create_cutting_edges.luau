-- Original continuous sickle arc and blade points; one-time Studio CSG authoring.
local V,CF=Vector3.new,CFrame.new
local folder=Instance.new("Folder");folder.Name="_ForgeCuttingEdges";folder.Parent=game.ServerStorage
local pieces={}
local function triangle(a,b,c,depth)
 -- Author large enough that Studio's minimum primitive dimensions cannot
 -- thicken tiny tip triangles, then scale the final solid to held-item size.
 a*=100;b*=100;c*=100;depth*=100
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Cross(ac).Magnitude<.000001 then return end
 if ab.Magnitude>ac.Magnitude and ab.Magnitude>bc.Magnitude then c,a=a,c
 elseif ac.Magnitude>bc.Magnitude then a,b=b,a end
 local center=(a+b+c)/3
 a=center+(a-center)*1.003;b=center+(b-center)*1.003;c=center+(c-center)*1.003
 ab,ac,bc=b-a,c-a,c-b
 local right=ac:Cross(ab).Unit
 local back=bc.Unit
 local up=back:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 for _,spec in ipairs({{(a+b)/2,right,back,math.abs(ab:Dot(back))},{(a+c)/2,-right,-back,math.abs(ac:Dot(back))}}) do
  if spec[4]>.00001 then
   local wedge=Instance.new("WedgePart")
   wedge.Size=V(depth,height,spec[4])
   wedge.CFrame=CFrame.fromMatrix(spec[1],spec[2],up,spec[3])
   wedge.Anchored=true;wedge.Material=Enum.Material.Metal;wedge.Parent=folder
   table.insert(pieces,wedge)
  end
 end
end

local assets=Instance.new("Folder");assets.Name="CuttingEdges"
local function finish(name)
 local first=table.remove(pieces,1)
 local bodies=game:GetService("GeometryService"):UnionAsync(first,pieces,{CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=true})
 assert(#bodies==1,name.." must be one connected solid")
 local shape=bodies[1];shape.Name=name;shape.Size/=100;shape.CFrame=CF(shape.Position/100)*shape.CFrame.Rotation
 shape.UsePartColor=true;shape.Material=Enum.Material.Metal;shape.Color=Color3.fromRGB(140,153,155)
 shape.Anchored=false;shape.CanCollide=false;shape.CanTouch=false;shape.CanQuery=false;shape.Massless=true
 shape:SetAttribute("ConnectedSolidCount",1);shape:SetAttribute("ArtVersion",1);shape.Parent=assets
 folder:ClearAllChildren();pieces={}
end
local function point(t)
 local p0,p1,p2,p3=V(0,0,0),V(-.14,.92,0),V(-1.35,.9,0),V(-1.02,-.55,0)
 local u=1-t
 local p=p0*u^3+p1*3*u*u*t+p2*3*u*t*t+p3*t^3
 local tangent=(p1-p0)*3*u*u+(p2-p1)*6*u*t+(p3-p2)*3*t*t
 local n=V(-tangent.Y,tangent.X,0).Unit
 local radius=.14*(1-t)^.62
 return p+n*radius,p-n*radius
end
for i=0,47 do
 local a,b=point(i/48);local c,d=point((i+1)/48)
 local depth=.035+.145*(1-(i+.5)/48)^.45
 triangle(a,b,c,depth);triangle(b,d,c,depth)
end
finish("SickleEdge")
for _,spec in ipairs({{"SwordPoint",.51,.65},{"DaggerPoint",.34,.45}}) do
 local name,width,height=table.unpack(spec)
 for i=0,15 do
  local y0=-.035+i*(height+.035)/16;local y1=-.035+(i+1)*(height+.035)/16
  local r0=width*.5*(1-i/16);local r1=width*.5*(1-(i+1)/16)
  local depth=.02+.12*(1-(i+.5)/16)^.5
  triangle(V(-r0,y0,0),V(r0,y0,0),V(-r1,y1,0),depth)
  triangle(V(r0,y0,0),V(r1,y1,0),V(-r1,y1,0),depth)
 end
 finish(name)
end
folder:Destroy()
return assets

