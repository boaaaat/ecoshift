local Config = require(script.Parent.Parent.ClassConfig)
local Theme = require(script.Parent.UITheme)
local Items = require(script.Parent.Parent.Items.ItemDatabase)
local TextService = game:GetService("TextService")
local Outfitter = {}
local selected, preview = nil, 1
local passiveNames = {
	ResourcePower="Resource breaking power", HungerReduction="Hunger drain reduction", GatherReduction="Gathering duration reduction",
	BuildDiscount="Building cost reduction", MonsterDamage="Monster damage bonus", HealingBonus="Medical healing bonus",
	ReviveReduction="Revival duration reduction", CraftSpeed="Crafting work rate", MoveSpeed="Movement speed",
	SprintReduction="Sprint stamina saving", FoodBonus="Food restoration bonus", PlantBonusChance="Extra plant chance",
	PlantGatherReduction="Plant gathering reduction", MineralPower="Mineral breaking power", MineralBonusChance="Extra mineral chance",
	MaxHealth="Maximum HP bonus", MonsterResistance="Monster damage reduction", ExposureReduction="Exposure buildup reduction",
	ExposureRecovery="Natural exposure recovery",
}
local function words(id) return tostring(id):gsub("(%l)(%u)", "%1 %2") end
local function paragraphHeight(value,width,size)
	return math.ceil(TextService:GetTextSize(value,size,Enum.Font.Gotham,Vector2.new(width,10000)).Y)+12
end
local function text(parent, value, x,y,w,h,size,token,bold)
	local label=Theme.Label(parent,value,UDim2.fromOffset(w,h),UDim2.fromOffset(x,y),size,nil,bold)
	label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None; Theme.Bind(label,"TextColor3",token or "Text"); return label
end
local function press(parent,value,x,y,w,h,callback,primary)
	local b=Instance.new("TextButton");b.Text=value;b.Font=Enum.Font.GothamBold;b.TextSize=14;b.Position=UDim2.fromOffset(x,y);b.Size=UDim2.fromOffset(w,h);b.Parent=parent
	Theme.Button(b,primary);b.Activated:Connect(callback);return b
end
local abilityDescriptions={
	Generalist=function(i) return string.format("Restore %d HP, %d stamina and remove %d heat or cold exposure. Self only; cannot revive.",({15,20,25})[i],({20,25,30})[i],({15,20,25})[i]) end,
	Gatherer=function(i) return string.format("For %ds: +%d%% resource breaking power and %d%% shorter hand gathering. Does not boost combat.",({12,15,18})[i],({25,35,45})[i],({20,25,30})[i]) end,
	Builder=function(i) return string.format("Deploy a turret (%d HP, %d damage/second, %d-stud range) or shelter (%d HP, 12×12 studs, player-operated door). Lasts 60s. Place within 16 studs, including outside camp; one deployment at a time.",({120,160,200})[i],({6,8,10})[i],({50,55,60})[i],({300,400,500})[i]) end,
	Hunter=function(i) return string.format("Mark a visible monster within 60 studs for %ds. Crew attacks deal +%d%% damage; half bonus against bosses. Marks do not stack.",({20,25,30})[i],({10,15,20})[i]) end,
	Medic=function(i) return string.format("Crew within 24 studs recover %d HP over 5s and receive %d%% shorter revival interactions for %ds. Still requires a Revival Kit.",({20,25,30})[i],({40,50,60})[i],({8,10,12})[i]) end,
	Engineer=function(i) return string.format("Overclock a crew station within 12 studs: +%d%% crafting work rate for %ds. Benefits ongoing and new crafts without changing material costs.",({25,35,45})[i],({20,25,30})[i]) end,
	Scout=function(i) return string.format("Reveal shared terrain within %d studs and mark resources, structures and monsters for %ds. Explored terrain stays revealed; no shift forecast.",({120,160,200})[i],({15,20,25})[i]) end,
	Cook=function(i) return string.format("Crew within 24 studs gain %d hunger and %d stamina over 10s. Overlapping meals do not stack.",({15,20,25})[i],({10,15,20})[i]) end,
	Botanist=function(i) return string.format("Regrow up to %d harvested plants within 24 studs. Each plant regrows once per biome shift across the crew. Excludes trees, cactus, minerals and objective plants.",({3,4,5})[i]) end,
	Prospector=function(i) return string.format("Mark minerals within %d studs for %ds and gain +%d%% mineral breaking power for %ds.",({80,100,120})[i],({15,20,25})[i],({20,30,40})[i],({12,15,18})[i]) end,
	Warden=function(i) return string.format("Draw up to six non-boss monsters within 20 studs toward you for %ds. Take %d%% less monster damage for %ds.",({6,7,8})[i],({25,30,35})[i],({8,10,12})[i]) end,
	Climatologist=function(i) return string.format("Create a stationary 20-stud field for %ds: %d%% less exposure buildup and %.1f exposure recovery/second. Protection ends on leaving; no poison or attack protection.",({20,25,30})[i],({30,40,50})[i],({1,1.5,2})[i]) end,
}
function Outfitter.Render(content,snapshot,rerender,actionButton)
	content.CanvasPosition=Vector2.zero
	local mobile=Theme.IsMobile(); local w=mobile and math.max(260,content.AbsoluteSize.X-10) or 796
	local records={};for _,record in ipairs(snapshot.Classes or {}) do records[record.Id]=record end
	if not selected then
		text(content,"CLASS OUTFITTER",0,0,w,30, mobile and 20 or 25,"Text",true)
		text(content,"12 paths · ability at level 3 · mastery at 24 active hours",0,36,w,34,14,"TextMuted")
		local cols=mobile and math.max(2,math.floor(w/165)) or 3;local cw=(w-(cols-1)*10)/cols
		for index,id in ipairs(Config.Order) do
			local def=Config.Definitions[id];local record=records[id] or {};local level=record.Level or 1
			local card=press(content,"",((index-1)%cols)*(cw+10),82+math.floor((index-1)/cols)*146,cw,136,function() selected=id;preview=level;rerender() end,record.Selected)
			local glyphHost=Instance.new("Frame");glyphHost.BackgroundTransparency=1;glyphHost.Size=UDim2.fromOffset(34,34);glyphHost.Position=UDim2.fromOffset(10,10);glyphHost.Parent=card;Theme.Icon(glyphHost,({Generalist="Survey",Gatherer="Harvest",Builder="Build",Hunter="Bow",Medic="Health",Engineer="Craft",Scout="Sprint",Cook="Food",Botanist="Leaf",Prospector="Mineral",Warden="Shield",Climatologist="Exposure"})[id] or "Survey",28)
			text(card,def.Name or id,48,10,cw-54,32,16,"Text",true)
			text(card,record.Owned and ("LEVEL "..level..(record.Selected and " · EQUIPPED" or "")) or (def.Price.." FIELD MARKS"),10,51,cw-20,22,12,record.Selected and "Amber" or "TextMuted",true)
			local required=Config.RequiredSeconds[math.min(level+1,5)];local seconds=record.ActiveSeconds or 0
			text(card,record.Owned and (level==5 and "MASTERED" or string.format("%d / %d class XP",math.floor(seconds/60),required/60)) or "VIEW CLASS",10,84,cw-20,22,12,"TextMuted")
			local track=Instance.new("Frame");track.Size=UDim2.new(1,-20,0,4);track.Position=UDim2.fromOffset(10,120);track.BorderSizePixel=0;track.Parent=card;Theme.Bind(track,"BackgroundColor3","SlotEmpty")
			local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(record.Owned and (level==5 and 1 or math.clamp(seconds/required,0,1)) or 0,1);fill.BorderSizePixel=0;fill.Parent=track;Theme.Bind(fill,"BackgroundColor3","Amber")
		end
		return
	end
	local def=Config.Definitions[selected];local record=records[selected] or {};local ownedLevel=record.Level or 1
	press(content,"‹ ALL CLASSES",0,0,150,40,function() selected=nil;rerender() end)
	text(content,def.Name or selected,166,0,w-166,40,22,"Text",true)
	text(content,def.Description or "",0,50,w,48,15,"TextMuted")
	local tabW=(w-32)/5
	for level=1,5 do press(content,"LEVEL "..level,(level-1)*(tabW+8),108,tabW,42,function() preview=level;rerender() end,preview==level) end
	local y=165
	text(content,"STARTER KIT · LEVEL "..preview,0,y,w,25,15,"Amber",true);y+=32
	local kit={"Harvester"}; for _,item in ipairs(Config.GetKit(selected,preview)) do table.insert(kit,(Items:Get(item.Id) and Items:Get(item.Id).Name or words(item.Id))..((item.N or 1)>1 and " ×"..item.N or "")) end
	local kitText=table.concat(kit,"  ·  ");local kitHeight=paragraphHeight(kitText,w,15);text(content,kitText,0,y,w,kitHeight,15,"Text");y+=kitHeight+12
	text(content,"PASSIVE BONUSES",0,y,w,25,15,"Amber",true);y+=30
	local passives=Config.GetPassives(selected,preview);local names={};for key in pairs(passives) do table.insert(names,key) end;table.sort(names)
	for _,key in ipairs(names) do local value=passives[key]; if type(value)=="number" then
		text(content,((Config.PassiveLabels or {})[key] or passiveNames[key] or words(key))..": "..(math.abs(value)<1 and string.format("%g%%",value*100) or tostring(value)),0,y,w,30,15);y+=32
	end end
	local ability=def.Ability or {};y+=8;text(content,(ability.Name or "UNIQUE ABILITY")..(preview<3 and " · UNLOCKS AT LEVEL 3" or ""),0,y,w,48,16,"Amber",true);y+=50
	local details=abilityDescriptions[selected](math.clamp(preview-2,1,3)).."  Cooldown: "..tostring(ability.Cooldown or 0).."s."
	local abilityH=paragraphHeight(details,w,15);text(content,details,0,y,w,abilityH,15,"TextMuted");y+=abilityH+16
	local money=snapshot.Currency or 0
	if not record.Owned then
		actionButton(content,"UNLOCK · "..def.Price.." MARKS","UNLOCKING…","BuyClass",{Id=selected},0,y,w,46,true,money<def.Price)
	else
		actionButton(content,record.Selected and "EQUIPPED" or "EQUIP CLASS","EQUIPPING…","SelectClass",{Id=selected},0,y,w,44,record.Selected,record.Selected);y+=56
		if ownedLevel<5 then
			local nextLevel=ownedLevel+1;local seconds=record.ActiveSeconds or 0;local need=Config.RequiredSeconds[nextLevel];local price=Config.UpgradePrices[nextLevel]
			text(content,string.format("LEVEL %d REQUIRES  ·  %d / %d class XP  ·  %d / %d Marks",nextLevel,math.floor(seconds/60),need/60,money,price),0,y,w,52,14,"TextMuted");y+=58
			actionButton(content,"UPGRADE TO LEVEL "..nextLevel,"SAVING UPGRADE…","UpgradeClass",{Id=selected,RoleId=selected,TargetLevel=nextLevel},0,y,w,46,true,seconds<need or money<price)
		else text(content,"CLASS MASTERED · LEVEL 5",0,y,w,40,16,"Amber",true) end
	end
end
return Outfitter
