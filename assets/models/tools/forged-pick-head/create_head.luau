-- Original closed pick-head profile. Run once in Studio, then serialize the
-- returned UnionOperation; runtime uses the saved CSG asset, never this operation.
local V,CF=Vector3.new,CFrame.new
local folder=Instance.new("Folder");folder.Name="_ForgePickHead";folder.Parent=game.ServerStorage
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
local function section(x)
 local t=math.abs(x)/1.35
 local y=.12-.75*t^1.75
 local radius=.2*(1-t)^.72
 return V(x,y+radius,0),V(x,y-radius,0)
end
for i=0,47 do
 local x0=-1.35+i*2.7/48;local x1=-1.35+(i+1)*2.7/48
 local a,b=section(x0);local c,d=section(x1)
 local t=math.abs((x0+x1)/2)/1.35
 local depth=.055+.27*(1-t)^.6
 triangle(a,b,c,depth);triangle(b,d,c,depth)
end
local first=table.remove(pieces,1)
local ok,bodies=pcall(function()return game:GetService("GeometryService"):UnionAsync(first,pieces,{
 CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=true,
})end)
folder:Destroy()
assert(ok,bodies)
assert(#bodies==1,"Forged pick profile must form one connected solid, got "..#bodies)
local head=bodies[1]
head.Size/=100
head.CFrame=CF(head.Position/100)*head.CFrame.Rotation
head.Name="ForgedPickHead"
head.UsePartColor=true;head.Color=Color3.fromRGB(137,150,153);head.Material=Enum.Material.Metal
head.Anchored=false;head.CanCollide=false;head.CanTouch=false;head.CanQuery=false;head.Massless=true
head:SetAttribute("ProfileCenterOffset",head.Position)
head:SetAttribute("ProfileSpan",2.7)
head:SetAttribute("ArtVersion",1)
head:SetAttribute("ConnectedSolidCount",#bodies)
return head

