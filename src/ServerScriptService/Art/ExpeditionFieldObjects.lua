-- Original field supplies and discovered expedition sites, in painted low-poly geometry.
local Art = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local C = { Brass=Color3.fromRGB(186,148,84), Ink=Color3.fromRGB(35,43,47), Paper=Color3.fromRGB(220,211,173),
	Wood=Color3.fromRGB(104,80,58), Moss=Color3.fromRGB(90,117,86), Stone=Color3.fromRGB(119,128,118), Glass=Color3.fromRGB(148,199,189) }
local biomeColors = { Forest="8EA96E", Desert="D4AC69", Swamp="78AD99", FrozenTundra="A8D7E1",
	Volcanic="DDA477", CrystalWastes="B6A2D8", AuroraVale="B3E0CE", StarfallCrater="D8BF9C" }
local function part(m, name, size, cf, color, shape, material)
	local p=Instance.new(shape or "Part")
	p.Name,p.Size,p.CFrame,p.Color=name,size,cf,color
	p.Material=material or Enum.Material.SmoothPlastic
	p.Anchored,p.CanCollide,p.CanTouch=true,true,false
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	p.Parent=m
	return p
end
local function cylinder(m,name,radius,height,cf,color)
	local p=part(m,name,V(height,radius*2,radius*2),cf*A(0,0,math.pi/2),color)
	p.Shape=Enum.PartType.Cylinder
	return p
end
local function model(name,family)
	local m=Instance.new("Model"); m.Name=name
	m:SetAttribute("ArtStyle","Expedition"); m:SetAttribute("ArtVersion",1); m:SetAttribute("ArtFamily",family)
	return m
end
local function finish(m)
	local root=m:FindFirstChildWhichIsA("BasePart",true)
	if root then m.PrimaryPart=root; root.PivotOffset=root.CFrame:Inverse() end
	return m
end
local function strap(m,cf,width,height,depth)
	for _,x in ipairs({-width*.32,width*.32}) do
		part(m,"CanvasBinding",V(.12,height+.05,depth+.06),cf*CF(x,0,0),C.Ink)
	end
end
local function dial(m,cf,radius,color,angle)
	cylinder(m,"BrassInstrumentRim",radius,.16,cf,C.Brass)
	cylinder(m,"EnamelDial",radius*.84,.18,cf*CF(0,.05,0),C.Paper)
	part(m,"Needle",V(.06,.04,radius*1.2),cf*CF(0,.17,-radius*.2)*A(0,angle or .5,0),color)
	for i=0,7 do
		part(m,"DialMark",V(.035,.025,.09),cf*A(0,i*math.pi/4,0)*CF(0,.16,-radius*.7),C.Ink)
	end
end
local function vial(m,cf,color)
	cylinder(m,"PaintedVial",.3,.86,cf*CF(0,.43,0),color)
	cylinder(m,"SealedStopper",.22,.2,cf*CF(0,.95,0),C.Wood)
	part(m,"FieldLabel",V(.38,.3,.025),cf*CF(0,.48,-.302),C.Paper)
	part(m,"LabelStripe",V(.23,.045,.03),cf*CF(0,.48,-.319),C.Ink)
end
function Art.CreateDrop(item)
	local id=item.Id
	local color=C.Moss
	for _,tag in ipairs(item.Tags or {}) do if biomeColors[tag] then color=Color3.fromHex(biomeColors[tag]); break end end
	local m=model(id,"FieldSupply")
	if item:HasTag("Utility") then
		m:SetAttribute("ArtFamily","FieldInstrument")
		part(m,"InstrumentCase",V(1.4,.45,1.6),CF(0,.225,0),C.Ink)
		part(m,"BrassFaceplate",V(1.22,.08,1.42),CF(0,.48,0),C.Brass)
		if id=="BiomeSelector" then
			dial(m,CF(0,.55,0),.38,C.Moss,1.3)
			local i=0
			for _,hex in ipairs({"8EA96E","D4AC69","78AD99","A8D7E1","DDA477","B6A2D8","B3E0CE","D8BF9C"}) do
				local angle=i*math.pi/4; i+=1
				part(m,"BiomeKey",V(.15,.14,.15),CF(math.sin(angle)*.51,.6,math.cos(angle)*.59),Color3.fromHex(hex))
			end
		elseif id=="ShiftStabilizer" or id=="ShiftTrigger" then
			for i=-1,1 do cylinder(m,"Coil",.16,.85,CF(i*.35,.91,0),i==0 and color or C.Brass) end
			part(m,"ControlLever",V(.1,.65,.1),CF(.48,.88,-.5)*A(.35,0,0),C.Paper)
		elseif id=="EventSeismograph" then
			part(m,"PaperChart",V(.9,.04,1.1),CF(0,.56,0),C.Paper)
			for i=-2,2 do part(m,"Trace",V(.27,.035,.045),CF(i*.17,.6,i%2*.18)*A(0,i%2==0 and .65 or -.65,0),C.Ink) end
		else
			dial(m,CF(0,.56,0),.51,color,id=="FieldClock" and -.8 or .8)
			if id=="FieldClock" then part(m,"HourHand",V(.045,.04,.31),CF(0,.75,-.1)*A(0,1.1,0),C.Ink)
			elseif id=="ResourceCompass" then part(m,"NorthPointer",V(.2,.06,.4),CF(0,.77,-.12),color,"WedgePart")
			else part(m,"SensorAerial",V(.08,1.1,.08),CF(.53,1.03,.52),C.Brass); part(m,"SensorTip",V(.19,.19,.19),CF(.53,1.64,.52),color) end
		end
	elseif id=="ReviveKit" or id=="Bandage" or id=="ThermalPatch" or id=="ToxinFilter" then
		m:SetAttribute("ArtFamily","MedicalKit")
		part(m,"CanvasKit",V(1.3,.65,.95),CF(0,.325,0),id=="ReviveKit" and C.Moss or C.Paper)
		strap(m,CF(0,.325,0),1.3,.65,.95)
		part(m,"MedicalEmblem",V(.4,.04,.12),CF(0,.675,0),C.Brass)
		part(m,"MedicalEmblem",V(.12,.04,.4),CF(0,.68,0),C.Brass)
		if id=="ReviveKit" then vial(m,CF(.72,0,0),C.Glass) end
	elseif item:HasTag("Food") then
		m:SetAttribute("ArtFamily","WrappedRations")
		for i=0,1 do part(m,"WaxedPacket",V(1,.22,.65),CF(i*.08,.12+i*.23,0)*A(0,i*.1,0),i==0 and C.Moss or C.Paper) end
		strap(m,CF(0,.24,0),1,.46,.67)
	elseif id:find("Tonic") or id:find("Gel") or id:find("Paste") or id:find("Water") or id:find("Essence") or id:find("Sap") then
		m:SetAttribute("ArtFamily","SealedSample"); vial(m,CF(),color)
	elseif id:find("Ingot") or id:find("Alloy") then
		m:SetAttribute("ArtFamily","StampedIngots")
		for i=0,1 do
			part(m,"Ingot",V(1,.22,.52),CF(0,.12+i*.23,0)*A(0,i*.15,0),color)
			part(m,"SlopedCasting",V(.2,.22,.52),CF(.56,.12+i*.23,0),color,"WedgePart")
		end
	elseif id:find("Cloth") or id:find("Weave") or id:find("Pelt") or id:find("Fur") or id:find("Leather") then
		m:SetAttribute("ArtFamily","FoldedTextile")
		for i=0,2 do part(m,"FoldedLayer",V(1.2,.13,.9-i*.06),CF(i*.03,.08+i*.13,0),color:Lerp(C.Paper,i*.13)) end
		strap(m,CF(0,.23,0),1.2,.43,.92)
	elseif id:find("Circuit") or id:find("Lens") or id:find("Glass") then
		m:SetAttribute("ArtFamily","OpticsAndCircuits")
		part(m,"ComponentBoard",V(1.1,.12,.85),CF(0,.06,0),C.Ink)
		for i=-1,1 do part(m,"CopperTrace",V(.06,.04,.67),CF(i*.31,.14,0),C.Brass) end
		dial(m,CF(0,.18,0),.29,color,0)
	elseif id:find("Wood") or id:find("Bark") or id:find("Fiber") or id:find("Reed") then
		m:SetAttribute("ArtFamily","BoundHarvest")
		for i=-1,1 do cylinder(m,"HarvestBundle",.14,.95,CF(i*.27,.18,0)*A(math.pi/2,0,0),color:Lerp(C.Wood,.55)) end
		strap(m,CF(0,.19,0),.88,.33,1)
	elseif id:find("Fang") or id:find("Talon") or id:find("Stinger") or id:find("Antler") or id:find("Bone") then
		m:SetAttribute("ArtFamily","CreatureTrophy")
		part(m,"TrophyBase",V(.38,.15,1),CF(0,.075,0),C.Paper)
		for i=-1,1 do part(m,"TrophyPoint",V(.17,.68,.32),CF(i*.18,.42,-.27)*A(.22,0,i*.3),C.Paper,"WedgePart") end
	else
		m:SetAttribute("ArtFamily",item:HasTag("MonsterDrop") and "CreatureSample" or "MineralSample")
		for i=-1,1 do
			part(m,"SampleFacet",V(.42,.48+(.14*(i%2)),.6),CF(i*.29,.28,i%2*.12)*A(0,i*.7,i*.2),color,"WedgePart")
		end
		part(m,"SurveySeal",V(.25,.04,.16),CF(0,.63,0),C.Brass)
	end
	return finish(m)
end
function Art.CreateChest(name,biome)
	local rare=name~="Common_Chest"
	local color=biomeColors[biome] and Color3.fromHex(biomeColors[biome]) or C.Moss
	local m=model(name,"SurveyCache")
	part(m,"CrateBody",V(3.2,1.55,2.15),CF(0,.8,0),rare and C.Ink or C.Wood)
	for _,x in ipairs({-1.25,1.25}) do part(m,"CornerBinding",V(.2,1.9,2.3),CF(x,.97,0),C.Brass) end
	part(m,"BeveledLid",V(3.1,.43,2.05),CF(0,1.8,0),rare and color or C.Moss)
	part(m,"Latch",V(.32,.54,.12),CF(0,1.36,-1.13),C.Brass)
	part(m,"ExpeditionSeal",V(.76,.06,.76),CF(0,2.05,0)*A(0,math.pi/4,0),C.Paper)
	if rare then part(m,"ResonanceLine",V(1.4,.055,.075),CF(0,2.09,0),color,nil,Enum.Material.Neon) end
	return finish(m)
end
function Art.CreateStructure(name,biome)
	local supported={CabinRuin=true,WatchTower=true,AncientRuins=true,DesertOutpost=true,SunkenShack=true,WreckedSkiff=true}
	if not supported[name] then return nil end
	local m=model(name,"AbandonedExpeditionSite")
	local sand=Color3.fromRGB(172,144,100)
	if name=="AncientRuins" then
		part(m,"RuinFooting",V(15,.7,13),CF(0,.35,0),sand)
		for i=-1,1 do
			part(m,"CarvedPillar",V(1.9,7+i,1.9),CF(i*5,(7+i)/2,3),sand)
			part(m,"BrokenCapital",V(2.7,.65,2.7),CF(i*5,7.4+i,3)*A(0,i*.2,0),C.Stone)
		end
		part(m,"LintelFragment",V(7,1.1,2.2),CF(-2.5,7.6,3)*A(0,0,.12),sand)
		for i=0,3 do part(m,"FallenMasonry",V(2,.8,1.6),CF(-5+i*3,.7,-3+i%2)*A(0,i*.6,0),sand) end
	elseif name=="WreckedSkiff" then
		part(m,"Keel",V(3.5,.7,11),CF(0,.6,0),C.Wood)
		for _,x in ipairs({-1.8,1.8}) do
			part(m,"SplitHull",V(.38,2,9.4),CF(x,1.5,0)*A(0,0,-x*.12),C.Wood)
		end
		part(m,"PointedBow",V(3.7,2,2.8),CF(0,1.2,-5.9)*A(math.pi/2,0,0),C.Wood,"WedgePart")
		for z=-3,3,3 do part(m,"BrokenThwart",V(3.8,.3,.8),CF(0,1.5,z)*A(0,.08*z,0),C.Paper) end
		part(m,"SnappedMast",V(.45,4,.45),CF(.5,2.6,0)*A(.4,0,.3),C.Wood)
	else
		local elevated=name=="WatchTower" and 7 or name=="SunkenShack" and 2 or 0
		part(m,"Deck",V(12,.5,10),CF(0,elevated+.3,0),C.Wood)
		for _,x in ipairs({-5.3,5.3}) do for _,z in ipairs({-4.2,4.2}) do
			part(m,"TimberPost",V(.55,7+elevated,.55),CF(x,(7+elevated)/2,z),C.Wood)
		end end
		if name=="WatchTower" then
			local ladder=part(m,"ClimbableLadder",V(2,8,.4),CF(0,4,-5.1),C.Brass,"TrussPart")
			ladder.Style=Enum.Style.AlternatingSupports
			for _,x in ipairs({-5.2,5.2}) do part(m,"LookoutRail",V(.25,1.3,9),CF(x,8.3,0),C.Moss) end
		elseif name=="CabinRuin" or name=="SunkenShack" then
			for y=1,4 do
				part(m,"WeatheredPlank",V(11,.75,.3),CF(0,elevated+y,4.3),y%2==0 and C.Wood or C.Moss)
				part(m,"BrokenSide",V(.3,.75,4+y*.5),CF(-5.3,elevated+y,1),C.Wood)
			end
		end
		part(m,"CanvasRoof",V(12.4,.18,10.5),CF(0,7.1+elevated,0)*A(0,0,.13),name=="DesertOutpost" and C.Paper or C.Moss)
		part(m,"SurveyPennant",V(1.8,1.1,.06),CF(5.2,8.1+elevated,-4.2),C.Brass,"WedgePart")
	end
	return finish(m)
end
return Art
