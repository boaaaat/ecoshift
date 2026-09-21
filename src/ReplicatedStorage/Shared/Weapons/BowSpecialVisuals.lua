-- Local, quality-scaled choreography. Server records supply timing and hit positions.
local Definitions=require(script.Parent.BowSpecials)
local Profiles=require(script.Parent.BowVisuals)
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local TAU=math.pi*2
local GOLD=Color3.fromRGB(255,209,111)
local WHITE=Color3.fromRGB(255,247,255)
local Visuals={}
local function part(parent,name,color,size,shape)
 local p=Instance.new(shape=="Thorn" and "WedgePart" or "Part")
 p.Name=name;p.Size=size or Vector3.one*.2;p.Color=color;p.Material=Enum.Material.Neon
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 if shape=="Ball" then p.Shape=Enum.PartType.Ball end
 p.Parent=parent;return p
end
local function create(parent,id,position)
 local profile=Profiles.Profile(id)
 local state={Root=part(parent,"Special_"..id,profile.Color,Vector3.one*.05),Profile=profile}
 state.Root.Transparency=1;state.Root.CFrame=CF(position)
 function state:Destroy() self.Root:Destroy() end
 return state
end
local function beam(state,color,width)
 local a,b=Instance.new("Attachment"),Instance.new("Attachment");a.Parent=state.Root;b.Parent=state.Root
 local edge=Instance.new("Beam");edge.Attachment0=a;edge.Attachment1=b;edge.FaceCamera=true
 edge.Color=ColorSequence.new(color);edge.LightEmission=1;edge.Width0=width;edge.Width1=width;edge.Segments=1;edge.Parent=state.Root
 return {A=a,B=b,Beam=edge,Width=width}
end
local function draw(edge,a,b,alpha,width)
 edge.A.Position=a;edge.B.Position=b
 local opacity=math.floor(math.clamp(alpha,0,1)*30)/30
 if edge.Alpha~=opacity then edge.Alpha=opacity;edge.Beam.Transparency=NumberSequence.new(1-opacity) end
 edge.Beam.Width0=edge.Width*(width or 1);edge.Beam.Width1=edge.Beam.Width0
end
local function path(state,n,color,width)
 local edges={};for i=1,n do edges[i]=beam(state,color,width) end;return edges
end
local function curve(edges,sample,alpha,width)
 local previous=sample(0)
 for i,edge in ipairs(edges) do local point=sample(i/#edges);draw(edge,previous,point,alpha,width);previous=point end
end
local function ring(edges,radius,y,phase,alpha,width)
 curve(edges,function(u)local theta=u*TAU+phase;return V(math.cos(theta)*radius,y,math.sin(theta)*radius) end,alpha,width)
end
local function particles(state,color,rate,speed,lifetime)
 local emitter=Instance.new("ParticleEmitter")
 emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
 emitter.Color=ColorSequence.new(color,state.Profile.Accent);emitter.LightEmission=.8
 emitter.Rate=rate;emitter.Speed=NumberRange.new(speed*.5,speed);emitter.Lifetime=NumberRange.new(lifetime*.6,lifetime)
 emitter.SpreadAngle=Vector2.new(180,180);emitter.Drag=1
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.4,.3),NumberSequenceKeypoint.new(1,0)})
 emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(.7,.55),NumberSequenceKeypoint.new(1,1)})
 emitter.Parent=state.Root;return emitter
end
local function light(state,quality)
 if quality<.6 then return end
 local l=Instance.new("PointLight");l.Color=state.Profile.Color;l.Brightness=1.4;l.Range=16;l.Shadows=false;l.Parent=state.Root
 return l
end

function Visuals.Zone(model,quality,parent)
 local id=model:GetAttribute("BowId");local def=Definitions[id]
 local state=create(parent,id,model:GetPivot().Position)
 local p=state.Profile;local low=quality<.6;local n=low and 16 or 28
 local rings,paths,nodes,stars,shards,links,crosses={},{},{},{},{},{},{}
 local function addRing(color,width) local r=path(state,n,color,width);rings[#rings+1]=r;return r end
 local emitter
 local lamp=light(state,quality)
 if def.Id=="SporeArrow" then
  addRing(p.Accent,.07);addRing(p.Color,.035)
  for i=1,(low and 8 or 18) do nodes[i]=part(state.Root,"Spore",i%2==0 and p.Color or p.Accent,Vector3.one*.16,"Ball") end
  emitter=particles(state,p.Color,low and 5 or 16,2,2)
 elseif def.Id=="FlareArrow" then
  addRing(GOLD,.1);addRing(p.Accent,.07)
  for i=1,(low and 8 or 12) do paths[i]=beam(state,GOLD,.1) end
  nodes[1]=part(state.Root,"SunCore",WHITE,Vector3.one*.5,"Ball")
 elseif def.Id=="LightningRod" then
  for i=1,3 do addRing(i==2 and WHITE or p.Accent,.07) end
  paths[1]=path(state,9,WHITE,.16);paths[2]=path(state,9,p.Accent,.3)
  for i=1,(low and 3 or 5) do nodes[i]=part(state.Root,"ChargeOrb",p.Color,Vector3.one*.22,"Ball") end
  emitter=particles(state,p.Color,low and 5 or 14,4,.7)
 elseif def.Id=="VineTrap" then
  paths[1]=path(state,low and 12 or 24,p.Accent,.22);paths[2]=path(state,low and 12 or 24,p.Color,.13)
  for i=1,(low and 12 or 24) do nodes[i]=part(state.Root,"Thorn",i%3==0 and GOLD or p.Color,V(.25,1.8,.65),"Thorn") end
  emitter=particles(state,p.Color,low and 3 or 9,7,.8)
 elseif def.Id=="StarBarrage" then
  addRing(p.Accent,.08);addRing(GOLD,.055)
  for i=1,def.Stars do
   stars[i]=part(state.Root,"ConstellationStar",i%2==0 and GOLD or WHITE,Vector3.one*.55,"Ball")
   shards[i]=part(state.Root,"FallenShard",i%2==0 and GOLD or p.Accent,V(.45,2,.65),"Thorn")
   links[i]=beam(state,i%2==0 and GOLD or p.Accent,.07)
   crosses[i]={beam(state,WHITE,.08),beam(state,GOLD,.055)}
   paths[i]=beam(state,GOLD,.075)
  end
  emitter=particles(state,p.Color,low and 7 or 22,7,1.5)
 end
 function state:Update(age)
  self.Root.CFrame=model:GetPivot()
  local lifetime=model:GetAttribute("Duration") or 1
  local fade=math.clamp((lifetime-age)/.5,0,1)
  local grow=math.clamp(age/.45,0,1)
  if lamp then lamp.Brightness=(1+.35*math.sin(age*4))*fade end
  if emitter then emitter.Enabled=fade>.1 end
  if def.Id=="SporeArrow" then
   ring(rings[1],def.Radius*grow,.1,age*.1,.38*fade)
   ring(rings[2],def.Radius*.8*grow,.3,-age*.15,.22*fade)
   for i,mote in ipairs(nodes) do
    local phase=age*.22+i*.618
    local r=def.Radius*math.sqrt((i*.618)%1)
    local point=V(math.cos(phase*TAU)*r,((age*.65+i*.7)%4)+.3,math.sin(phase*TAU)*r)
    mote.CFrame=self.Root.CFrame*CF(point)
    mote.Size=Vector3.one*(.15+.22*math.sin(age+i)^2)
    mote.Transparency=1-fade*(.35+.25*math.sin(phase*3)^2)
   end
  elseif def.Id=="FlareArrow" then
   local charge=math.clamp(age/def.Delay,0,1);local visible=age<=def.Delay and fade or 0
   ring(rings[1],1+charge*2,0,age*3,visible)
   ring(rings[2],3-charge*1.6,.2,-age*3,visible*.7)
   for i,edge in ipairs(paths) do
    local a=i*TAU/#paths+age*2
    local dir=V(math.cos(a),.12,math.sin(a))
    draw(edge,dir*(1+charge),dir*(2+charge*2),visible)
   end
   nodes[1].CFrame=self.Root.CFrame;nodes[1].Size=Vector3.one*(.5+charge*1.2);nodes[1].Transparency=1-visible*.85
  elseif def.Id=="LightningRod" then
   for i,r in ipairs(rings) do ring(r,1.1+i*.55+math.sin(age*6+i)*.12,(i-1)*.7,age*(i%2==0 and 2 or -2),fade*.7) end
   for j,edges in ipairs(paths) do
    curve(edges,function(u)return V(math.sin(u*38+math.floor(age*20))*.3,5*u,math.sin(u*51+j)*.25) end,fade*(j==1 and .9 or .35))
   end
   for i,orb in ipairs(nodes) do local a=age*3+i*TAU/#nodes;orb.CFrame=self.Root.CFrame*CF(math.cos(a)*1.8,1+math.sin(a)*.8,math.sin(a)*1.8);orb.Transparency=1-fade end
  elseif def.Id=="VineTrap" then
   local function ground(u)
    local sample=math.clamp(u*12,0,12);local lo=math.floor(sample);local hi=math.min(12,lo+1)
    local a=model:GetAttribute("Ground"..lo) or 0;local b=model:GetAttribute("Ground"..hi) or a
    return a+(b-a)*(sample-lo)
   end
   for side,edges in ipairs(paths) do
    curve(edges,function(u)return V((side==1 and -1 or 1)*(1.8+math.sin(u*17+side)*.5),ground(u)+.2+math.sin(u*math.pi*5)^2*.3,(u-.5)*def.Length*grow) end,fade*.8)
   end
   for i,thorn in ipairs(nodes) do
    local u=(i-1)/math.max(1,#nodes-1)
    thorn.CFrame=self.Root.CFrame*CF((i%2==0 and -1 or 1)*(1.6+math.sin(i)*.4),ground(u)+.6*grow,(u-.5)*def.Length*grow)*A(0,i,.3*math.sin(i))
    thorn.Size=V(.28,math.max(.05,(1+math.sin(i)^2)*grow),.8)
    thorn.Transparency=1-fade*.85
   end
  elseif def.Id=="StarBarrage" then
   local detonated=model:GetAttribute("Detonated")
   local alpha=detonated and 0 or fade
   ring(rings[1],def.Radius*grow,.2,age*.25,alpha*.45)
   ring(rings[2],def.InnerRadius*grow,.3,-age*.35,alpha*.35)
   local launched=model:GetAttribute("StarLaunched") or 0
   local offsets={}
   for i=1,def.Stars do
    local origin=model:GetAttribute("StarOrigin"..i)
    offsets[i]=origin and self.Root.CFrame:PointToObjectSpace(origin) or V(math.cos(i*math.pi/4)*13,26+(i%2)*4,math.sin(i*math.pi/4)*13)
   end
   for i,star in ipairs(stars) do
    local point=offsets[i];local visible=i>launched and alpha*grow or 0
    star.CFrame=self.Root.CFrame*CF(point);star.Transparency=1-visible
    local flare=.55+.22*math.sin(age*4+i)
    draw(crosses[i][1],point-V(flare,0,0),point+V(flare,0,0),visible)
    draw(crosses[i][2],point-V(0,flare*1.5,0),point+V(0,flare*1.5,0),visible)
    local nextIndex=i%def.Stars+1
    draw(links[i],point,offsets[nextIndex],visible*(nextIndex>launched and .6 or .1))
    local shard=model:GetAttribute("Shard"..i)
    local nextShard=model:GetAttribute("Shard"..nextIndex)
    shards[i].Transparency=shard and (1-alpha*.8) or 1
    if shard then
     local localPoint=self.Root.CFrame:PointToObjectSpace(shard)
     shards[i].CFrame=CF(shard+V(0,.65,0))*A(0,i,.25*math.sin(i))
     draw(paths[i],localPoint,nextShard and self.Root.CFrame:PointToObjectSpace(nextShard) or Vector3.zero,alpha*.65)
    else draw(paths[i],Vector3.zero,Vector3.zero,0) end
   end
  end
 end
 return state
end

function Visuals.Pulse(packet,quality,parent)
 local state=create(parent,packet.BowId,packet.Position)
 local p=state.Profile;local low=quality<.6;local kind=packet.Kind
 state.Duration=kind=="VineCatch" and packet.Duration or kind=="StarFinale" and 1.15 or kind=="Lightning" and .32 or .65
 local radius=packet.Radius or (kind=="StarHit" and 3 or 2)
 local rings={path(state,low and 18 or 32,p.Color,.16),path(state,low and 18 or 32,kind=="StarFinale" and GOLD or p.Accent,.09)}
 local rays={};local seeds={}
 local count=kind=="Lightning" and (low and 2 or 3) or (low and 8 or 16)
 for i=1,count do
  rays[i]=path(state,kind=="Lightning" and 7 or 1,i%2==0 and WHITE or p.Color,.09)
  seeds[i]=part(state.Root,"BurstShard",i%2==0 and GOLD or p.Color,V(.15,.5,.15),"Thorn")
 end
 local core=part(state.Root,"FlashCore",WHITE,Vector3.one*.2,"Ball")
 local emitter=particles(state,p.Color,0,kind=="StarFinale" and 22 or 10,.6);emitter:Emit(low and 10 or 30)
 local lamp=light(state,quality)
 function state:Update(age)
  local u=math.clamp(age/self.Duration,0,1);local fade=(1-u)^1.6
  local growth=1-(1-u)^3
  if lamp then lamp.Brightness=3*fade end
  core.CFrame=self.Root.CFrame;core.Size=Vector3.one*math.max(.1,(kind=="StarFinale" and 8 or 3)*growth)
  core.Transparency=.8+.2*u
  if kind=="Lightning" then
   local delta=packet.To-packet.Position
   for j,edges in ipairs(rays) do
    curve(edges,function(t)local wave=math.sin(t*math.pi);return delta*t+V(math.sin(t*51+j+math.floor(age*35)),math.sin(t*32+j),math.cos(t*73+j))*wave*(j==1 and .55 or 1.4) end,fade*(j<=2 and .9 or .08))
   end
  else
   for j,r in ipairs(rings) do ring(r,radius*growth*(j==1 and 1 or .7),.2+j*.25,age*j,fade*(j==1 and .8 or .5),1-u*.7) end
   for i,edges in ipairs(rays) do
    local theta=i*TAU/count
    local a=V(math.cos(theta),0,math.sin(theta))
    if kind=="VineCatch" then
     local t=age*3+i*TAU/count;local point=V(math.cos(t)*1.5,math.sin(t*2)*1.4,math.sin(t)*1.5)
     draw(edges[1],point,point+V(0,.75,0),math.min(age*6,fade)*.8)
    else draw(edges[1],a*radius*growth*.4,a*radius*growth+V(0,math.sin(theta*3)^2*growth*3,0),fade) end
   end
  end
  for i,shard in ipairs(seeds) do
   local theta=i*TAU/count
   shard.CFrame=self.Root.CFrame*CF(math.cos(theta)*radius*growth,math.sin(u*math.pi)*(1+i%3),math.sin(theta)*radius*growth)*A(age*4,i,age*3)
   shard.Transparency=1-fade*.75
  end
 end
 return state
end
return Visuals
