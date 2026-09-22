-- A non-modal HUD tracker; station menus only choose the goal.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Shared = script.Parent.Parent
local Theme = require(script.Parent.UITheme)
local make = require(script.Parent.UIFactory).Create
local Plan = require(Shared.RecipePlan)
local Guide = require(Shared.RecipeGuide)
local Workbench = require(Shared.WorkbenchConfig)
local Catalog = require(Shared.OverhaulCatalog)
local Cooking = require(Shared.CookingConfig)
local Items = require(Shared.Items.ItemDatabase)
local Ingredients = require(Shared.IngredientResolver)
local player = Players.LocalPlayer
local Helper = {}
local target, inventory, plan, activeCraft
local queues = {}
local dirty, expanded, signature = true, false, ""
local available = Vector2.new(1280,720)
local colors = Theme.Colors
local function name(id) local item=Items:Get(id);return item and item.Name or tostring(id) end
local function stationName(id) return Workbench.STATIONS[id] and Workbench.STATIONS[id].Name or tostring(id) end
local gui = make("ScreenGui",player:WaitForChild("PlayerGui"),{
	Name="RecipeHelperHUD",ResetOnSpawn=false,Enabled=false,DisplayOrder=12,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
Theme.TrackRoot(gui)
local panel = make("Frame",gui,{Name="Tracker",AnchorPoint=Vector2.new(1,0),BackgroundColor3=colors.Panel,BorderSizePixel=0})
Theme.Panel(panel)
local title = make("TextLabel",panel,{
	Name="Goal",Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-108,0,44),BackgroundTransparency=1,
	Text="",TextColor3=colors.Text,TextSize=14,Font=Enum.Font.GothamBold,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
})
local function control(text,x)
	local b=make("TextButton",panel,{Position=UDim2.new(1,x,0,6),Size=UDim2.fromOffset(44,44),Text=text,
		TextSize=18,Font=Enum.Font.GothamBold,TextColor3=colors.Text,BackgroundColor3=colors.SlotEmpty,BorderSizePixel=0})
	Theme.Button(b);return b
end
local toggle = control("+",-96);toggle.Name="ExpandChecklist"
local stop = control("×",-48);stop.Name="StopTracking"
local caption = make("TextLabel",panel,{
	Position=UDim2.fromOffset(12,55),Size=UDim2.new(1,-24,0,20),BackgroundTransparency=1,Text="",
	TextColor3=colors.TextMuted,TextSize=12,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
})
local list = make("ScrollingFrame",panel,{
	Name="Steps",Position=UDim2.fromOffset(12,80),Size=UDim2.new(1,-24,1,-88),BackgroundTransparency=1,
	BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
	ScrollingDirection=Enum.ScrollingDirection.Y,
})
make("UIListLayout",list,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",list,{PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,4)})
local function layout()
	local mobile=Theme.IsMobile()
	local top=mobile and 54 or 160
	local width=math.min(mobile and 290 or 340,available.X-24)
	local height=math.min(expanded and 440 or 230,math.max(150,available.Y-top-(mobile and 100 or 130)))
	panel.Position=UDim2.new(1,-12,0,top);panel.Size=UDim2.fromOffset(width,height)
	toggle.Text=expanded and "−" or "+"
end
local function incoming()
	local result={}
	local function add(id,record)
		result[id]=result[id] or {};table.insert(result[id],record)
	end
	for station,records in pairs(queues) do
		if station:IsDescendantOf(workspace) then
			for id,record in pairs(records) do if record.Count>0 then add(id,record) end end
		else queues[station]=nil end
	end
	if activeCraft then add(activeCraft.ItemId,{Count=activeCraft.Count,StationType=activeCraft.StationType,Working=true}) end
	return result
end
local function describe(step)
	if step.Kind=="Gather" then
		local sources=table.concat(step.Sources or {},"\n")
		return "Gather "..step.Count.." × "..name(step.ItemId),
			step.Owned.." / "..step.Needed.." owned\n"..(step.Warning or (sources~="" and sources or "No gathering source is recorded for this item.")),colors.Warning
	elseif step.Kind=="Collect" then
		return (step.Working and "Finish crafting " or "Finish / collect ")..step.Count.." × "..name(step.ItemId),
			step.Working and "Craft in progress; its materials are already paid." or
			("Last seen at "..stationName(step.StationType)..". Return, check fuel, and collect the queued or ready output."),colors.Amber
	elseif step.Kind=="Upgrade" then
		local locked=(workspace:GetAttribute("CampaignTier") or 1)<step.Grade
		return "Upgrade "..stationName(step.StationType).." to grade "..step.Grade,
			locked and ("Complete campaign tier "..step.Grade.." first.") or "Return to the selected station, finish its queued work, then choose Upgrade.",locked and colors.Warning or colors.Success
	elseif step.Kind=="Craft" then
		local recipe=step.Recipe
		local stations={}
		for _,id in ipairs(recipe.AllowedStations or {recipe.StationType}) do table.insert(stations,stationName(id)) end
		local lock=Workbench:GetCampaignLock(step.RecipeId)
		local details=step.Batches.." batch"..(step.Batches==1 and "" or "es").." at "..table.concat(stations," / ")
		if not table.find(recipe.AllowedStations or {},"Hand") then details..=" · grade "..(recipe.RequiredGrade or 1) end
		local usable=Guide.GetUsableStation(step.RecipeId,player)
		if lock then details..="\n"..lock
		elseif not usable then details..="\nFind or place this station; upgrade it if its grade is too low." end
		if recipe.Cooking or table.find(recipe.AllowedStations or {},"Furnace") then
			details..="\nQueue batches, add fuel as needed, then collect the output."
		end
		return "Craft "..step.Count.." × "..name(step.ItemId),details,lock and colors.Warning or colors.Text
	end
	return step.Text or "Recipe unavailable","",colors.Warning
end
local function refresh()
	if not target then return end
	if not inventory then title.Text="Recipe helper";caption.Text="Loading inventory…";return end
	for station in pairs(queues) do
		if not station:IsDescendantOf(workspace) then queues[station]=nil;dirty=true end
	end
	if target.Kind=="Recipe" and not target.Count then
		target.Count=Ingredients.Count(inventory,target.ItemId)+target.OutputCount
	end
	if target.Kind=="Upgrade" then
		local grade=target.Station and target.Station:GetAttribute("StationGrade")
		local present=target.Station and target.Station:IsDescendantOf(workspace)
		if grade~=target.LastGrade or present~=target.LastPresent then dirty=true;target.LastGrade=grade;target.LastPresent=present end
	end
	if dirty and not target.Completed then
		plan=Plan.Build(target,inventory,player,incoming());dirty=false
		if plan.Complete then target.Completed=true end
	end
	if not plan then return end
	title.Text=target.Kind=="Upgrade" and (stationName(target.StationType).." · grade "..target.Grade) or (name(target.ItemId).." ×"..target.OutputCount)
	caption.Text=target.Completed and "Complete!" or (#plan.Steps.." steps left · "..(expanded and "full plan" or (Theme.IsMobile() and "+ for full plan" or "H / + for full plan")))
	local rows,bits={},{}
	if target.Completed then
		rows={{"✓ Goal complete",target.Kind=="Upgrade" and "Your station has been upgraded." or "Your crafted items are ready.",colors.Success}}
	else
		for index,step in ipairs(plan.Steps) do
			if not expanded and index>1 then break end
			local heading,detail,color=describe(step)
			table.insert(rows,{index..". "..heading,detail,color})
		end
	end
	for _,row in ipairs(rows) do table.insert(bits,row[1]..row[2]..tostring(row[3])) end
	local nextSignature=table.concat(bits,"|")
	if nextSignature==signature then return end
	signature=nextSignature
	for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	for index,row in ipairs(rows) do
		local frame=make("Frame",list,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=index})
		make("UIListLayout",frame,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
		for line=1,2 do
			make("TextLabel",frame,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
				Text=row[line],TextColor3=line==1 and row[3] or colors.TextMuted,TextSize=line==1 and 14 or 12,
				Font=line==1 and Enum.Font.GothamBold or Enum.Font.Gotham,TextWrapped=true,
				TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=line})
		end
	end
end
local function start(goal)
	target=goal;plan=nil;dirty=true;signature="";expanded=false
	gui.Enabled=true;list.CanvasPosition=Vector2.zero;layout();refresh()
end
function Helper.TrackRecipe(itemId,recipeId,batches)
	local entry=Guide.GetEntry(itemId)
	recipeId=recipeId or entry.RecipeId
	local recipe=recipeId==entry.RecipeId and entry.Recipe or Workbench.RECIPES[recipeId]
	if not recipe then return end
	start({Kind="Recipe",ItemId=itemId,RecipeId=recipeId,OutputCount=(recipe.Output.N or 1)*math.clamp(math.floor(tonumber(batches) or 1),1,99)})
end
function Helper.TrackUpgrade(station,stationType)
	if not station or not station:IsDescendantOf(workspace) then return end
	local _,grade=Catalog.GetStationUpgradeCost(stationType,station:GetAttribute("StationGrade") or 1)
	if grade then start({Kind="Upgrade",Station=station,StationType=stationType,Grade=grade}) end
end
local function toggleChecklist()
	expanded=not expanded;signature="";list.CanvasPosition=Vector2.zero;layout();refresh()
end
toggle.Activated:Connect(toggleChecklist)
UIS.InputBegan:Connect(function(input,processed)
	if not processed and not UIS:GetFocusedTextBox() and gui.Enabled and input.KeyCode==Enum.KeyCode.H then toggleChecklist() end
end)
stop.Activated:Connect(function()target=nil;plan=nil;gui.Enabled=false end)
Theme.BindResponsive(gui,function(_,size)available=size;layout() end)

local remotes=RS:WaitForChild("Remotes")
local inventoryRemote=remotes:WaitForChild("InventoryUpdate")
inventoryRemote.OnClientEvent:Connect(function(kind,payload)
	if kind~="Snapshot" or type(payload)~="table" then return end
	-- Queue snapshots separately confirm collection. Other inventory gains must not
	-- erase work still waiting in a station (e.g. finding loot while ore smelts).
	inventory=payload;dirty=true
	-- Remember completion before the player equips, places, or consumes the output.
	if target and target.Kind=="Recipe" and target.Count and Ingredients.Count(payload,target.ItemId)>=target.Count then
		target.Completed=true;plan={Steps={},Complete=true}
	end
end)
local function queueSnapshot(kind,payload,cooking)
	local isSnapshot=cooking and (kind=="Open" or kind=="State") or (not cooking and kind=="Snapshot")
	if not isSnapshot or type(payload)~="table" or typeof(payload.Station)~="Instance" then return end
	-- Upgrade panels also send Station snapshots for kitchens, with an empty
	-- furnace state. They must not overwrite that kitchen's cooking queue.
	if not cooking and payload.StationType~="Furnace" then return end
	local state=cooking and payload or payload.State
	if type(state)~="table" then return end
	local records={}
	local function add(id,n)
		if not id or n<=0 then return end
		records[id]=records[id] or {Count=0,StationType=payload.StationType}
		records[id].Count+=n
	end
	for _,entry in pairs(state.Output or {}) do if type(entry)=="table" then add(entry.Id,entry.N or 0) end end
	for _,job in ipairs(state.Jobs or {}) do
		if job.OwnerUserId==player.UserId then
			local id=cooking and Cooking.GetOutputId(job.RecipeId,job.SeasoningId) or job.Output and job.Output.Id
			add(id,(job.Remaining or 0)*(cooking and 1 or job.Output and job.Output.N or 1))
		end
	end
	queues[payload.Station]=records;dirty=true
end
local connected={}
local function bind(remote)
	if not remote:IsA("RemoteEvent") or connected[remote] then return end
	if remote.Name=="Station" or remote.Name=="Cooking" then
		connected[remote]=true
		remote.OnClientEvent:Connect(function(kind,payload)queueSnapshot(kind,payload,remote.Name=="Cooking") end)
	elseif remote.Name=="Craft" then
		connected[remote]=true
		remote.OnClientEvent:Connect(function(kind,payload)
			if type(payload)~="table" then return end
			if kind=="Started" then
				activeCraft={ItemId=payload.OutputId,Count=payload.OutputCount,RecipeId=payload.RecipeId,StationType=payload.StationType}
			elseif kind=="Result" and activeCraft and activeCraft.RecipeId==payload.RecipeId and activeCraft.StationType==payload.StationType and payload.Reason~="CraftInProgress" then activeCraft=nil end
			dirty=true
		end)
	end
end
remotes.ChildAdded:Connect(bind)
for _,remote in ipairs(remotes:GetChildren()) do bind(remote) end
inventoryRemote:FireServer("RequestSnapshot")
player:GetAttributeChangedSignal("Class_BuildDiscount"):Connect(function()dirty=true end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt
	if elapsed<.5 then return end
	elapsed=0
	if gui.Enabled then refresh() end
end)
return Helper
