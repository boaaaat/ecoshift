-- Expedition assembly, class outfitting, and the world archive share one field kit.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Theme=require(RS:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("UITheme"))
local Mode=require(RS.Shared.SessionConfig).GetMode()
local player=Players.LocalPlayer
local remote=RS:WaitForChild("Remotes"):WaitForChild("Lobby",60)
if not remote then return end
local C=Theme.Colors
local gui=Instance.new("ScreenGui"); gui.Name="ExpeditionAssembly"; gui.ResetOnSpawn=false; gui.DisplayOrder=50; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=player.PlayerGui
local panel=Instance.new("Frame"); panel.Name="Assembly"; panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(970,590); panel.Visible=Mode=="Lobby"; panel.Parent=gui
Theme.Panel(panel); Theme.Fit(panel,970,590); Theme.AnimatePanel(panel)
local function label(parent,text,x,y,w,h,size,token,bold)
	local l=Theme.Label(parent,text,UDim2.fromOffset(w,h),UDim2.fromOffset(x,y),size,C[token or "Text"],bold)
	Theme.Bind(l,"TextColor3",token or "Text"); return l
end
local function button(parent,text,x,y,w,h,fn,primary)
	local b=Instance.new("TextButton"); b.Name=text:gsub("%W","").."Button"; b.Text=text; b.Font=Enum.Font.GothamBold; b.TextSize=13; b.Size=UDim2.fromOffset(w,h); b.Position=UDim2.fromOffset(x,y); b.Parent=parent; Theme.Button(b,primary==true)
	if fn then b.Activated:Connect(fn) end; return b
end
local function send(action,data) remote:FireServer(action,data or {}) end
label(panel,"ECO / SHIFT",26,18,300,32,27,"Text",true)
label(panel,"EXPEDITION OBSERVATORY",27,52,420,20,10,"TextMuted",true)
local funds=label(panel,"CONNECTING TO FIELD RECORDS",620,25,288,28,13,"Amber",true); funds.TextXAlignment=Enum.TextXAlignment.Right
button(panel,"×",925,20,28,28,function() panel.Visible=false end)
local side=Instance.new("Frame"); side.Name="Sections"; side.BackgroundTransparency=1; side.Position=UDim2.fromOffset(24,104); side.Size=UDim2.fromOffset(190,450); side.Parent=panel
local content=Instance.new("ScrollingFrame"); content.Name="Content"; content.Position=UDim2.fromOffset(236,101); content.Size=UDim2.fromOffset(704,417); content.BackgroundTransparency=1; content.BorderSizePixel=0; content.ScrollBarThickness=4; content.CanvasSize=UDim2.new(); content.AutomaticCanvasSize=Enum.AutomaticSize.Y; content.Parent=panel; Theme.Bind(content,"ScrollBarImageColor3","Moss")
local feedback=label(panel,"Assemble your crew. Prepare for the changing world.",239,536,690,30,12,"TextMuted"); feedback.TextWrapped=true; feedback.TextTruncate=Enum.TextTruncate.None
local snapshot,page=nil,"Party"
local removalId,removalUntil=nil,0
local scrollByPage={}
local render
for index,entry in ipairs({{"Party","01  EXPEDITION CREW"},{"Classes","02  CLASS OUTFITTER"},{"Saves","03  WORLD ARCHIVE"}}) do
	local b=button(side,entry[2],0,(index-1)*52,190,42,function() page=entry[1]; render() end)
	if Mode~="Lobby" and entry[1]~="Party" then b.Visible=false end
end
label(side,"SIX EXPLORERS\nONE CHANGING WORLD",8,190,176,56,11,"TextMuted",true).TextWrapped=true
label(side,"F2  •  CREW PANEL\nF4  •  APPEARANCE",8,350,176,52,11,"TextMuted").TextWrapped=true
button(side,"APPEARANCE",0,408,190,36,function() player:SetAttribute("FieldKitSettings",(player:GetAttribute("FieldKitSettings") or 0)+1) end)
local open=button(gui,Mode=="Lobby" and "EXPEDITION DESK  /  F2" or "CREW  /  F2",0,0,208,34,function() panel.Visible=not panel.Visible; if panel.Visible then send("Snapshot") end end,true)
open.AnchorPoint=Vector2.new(.5,0); open.Position=UDim2.new(.5,0,0,12)
open.Visible=not panel.Visible
panel:GetPropertyChangedSignal("Visible"):Connect(function() open.Visible=not panel.Visible end)
local function clear() for _,v in ipairs(content:GetChildren()) do v:Destroy() end end
local function box(parent,name,x,y,w,h)
	local f=Instance.new("Frame"); f.Name=name; f.Position=UDim2.fromOffset(x,y); f.Size=UDim2.fromOffset(w,h); f.Parent=parent; Theme.Panel(f); return f
end
local function textbox(parent,placeholder,x,y,w)
	local b=Instance.new("TextBox"); b.PlaceholderText=placeholder; b.Text=""; b.ClearTextOnFocus=false; b.Font=Enum.Font.Gotham; b.TextSize=13; b.Position=UDim2.fromOffset(x,y); b.Size=UDim2.fromOffset(w,34); b.Parent=parent; b.BorderSizePixel=0; Theme.Corner(b,6); Theme.Bind(b,"BackgroundColor3","SlotEmpty"); Theme.Bind(b,"TextColor3","Text"); b.PlaceholderColor3=C.TextMuted; return b
end
local descriptions={Generalist="A dependable all-round explorer.",Builder="Raise camp quickly and reinforce the team.",Hunter="Stronger strikes against biome creatures.",Gatherer="Bring more materials back to camp.",Engineer="Process supplies and craft equipment faster.",Medic="Help fallen teammates return to the expedition."}
local lastPage=page
render=function()
	scrollByPage[lastPage]=content.CanvasPosition
	clear()
	content.CanvasPosition=scrollByPage[page] or Vector2.zero; lastPage=page
	if not snapshot then label(content,"Retrieving expedition records…",10,10,650,40,18,"TextMuted"); return end
	funds.Text=tostring(snapshot.Currency or 0).."  "..string.upper(snapshot.CurrencyName or "FIELD MARKS")
	if page=="Party" then
		local party=snapshot.Party or {Members={},Invites={}}
		label(content,"YOUR EXPEDITION CREW",0,0,650,28,20,"Text",true)
		label(content,party.Id and (#party.Members.." / 6  •  "..(party.Queue and "MATCHMAKING" or "PREPARING")) or "Invite friends, choose classes, and ready up together.",0,32,680,24,12,"TextMuted")
		local selfMember
		for index=1,6 do
			local member=party.Members[index]
			local card=box(content,"Crew"..index,((index-1)%2)*346,68+math.floor((index-1)/2)*83,334,73)
			if member then
				label(card,member.DisplayName..(member.UserId==party.LeaderId and "  /  LEADER" or ""),12,10,307,23,14,"Text",true)
				label(card,(member.Role or "Generalist").."  •  "..(member.Online and (member.Ready and "READY" or member.Location or "ONLINE") or "OFFLINE"),12,38,307,20,11,member.Ready and "Success" or "TextMuted")
				if member.UserId==player.UserId then selfMember=member end
			else label(card,"OPEN CREW SLOT",12,24,305,24,11,"TextMuted",true) end
		end
		local y=329
		if not party.Id then button(content,"CREATE PARTY",0,y,208,38,function() send("CreateParty") end,true)
		else
			if not party.RunId then button(content,selfMember and selfMember.Ready and "NOT READY" or "READY UP",0,y,158,38,function() send("Ready",{Ready=not (selfMember and selfMember.Ready)}) end,true) end
			button(content,"LEAVE PARTY",170,y,154,38,function() send("LeaveParty") end)
			if party.LeaderId==player.UserId and Mode=="Lobby" and not party.RunId then button(content,party.Queue and "CANCEL QUEUE" or "FIND EXPEDITION",346,y,334,38,function() send(party.Queue and "CancelQueue" or "Queue") end,true) end
			if party.LeaderId==player.UserId and not party.RunId then
				local input=textbox(content,"Roblox username",0,y+54,492)
				button(content,"INVITE",510,y+54,170,34,function() send("Invite",{Username=input.Text}) end)
				y+=54
			end
		end
		y+=62
		if Mode=="Expedition" then button(content,"RETURN TO OBSERVATORY",0,y,680,38,function() send("ReturnLobby") end,true); y+=54 end
		if snapshot.Rejoin and snapshot.Rejoin.Available then button(content,"REJOIN ACTIVE EXPEDITION",0,y,680,38,function() send("Rejoin") end,true); y+=54 end
		for _,invite in ipairs(party.Invites or {}) do
			label(content,invite.From.." invited you to a party",0,y,474,34,13,"Text")
			button(content,"ACCEPT",510,y,170,34,function() send("AcceptInvite",{Id=invite.Id}) end,true); y+=44
		end
	elseif page=="Classes" then
		label(content,"CLASS OUTFITTER",0,0,680,30,20,"Text",true)
		label(content,"Permanent unlocks • earn Field Marks on expeditions",0,35,680,23,12,"TextMuted")
		for index,class in ipairs(snapshot.Classes or {}) do
			local card=box(content,class.Id,((index-1)%2)*346,74+math.floor((index-1)/2)*154,334,140)
			label(card,class.Name,14,12,306,26,19,"Text",true)
			local description=label(card,descriptions[class.Id] or "",14,43,306,38,12,"TextMuted"); description.TextWrapped=true; description.TextTruncate=Enum.TextTruncate.None
			local text=class.Selected and "EQUIPPED" or class.Owned and "EQUIP CLASS" or (tostring(class.Price).." FIELD MARKS  •  UNLOCK")
			button(card,text,14,93,306,33,function() if not class.Selected then send(class.Owned and "SelectClass" or "BuyClass",{Id=class.Id}) end end,class.Selected)
		end
	else
		label(content,"WORLD ARCHIVE",0,0,680,30,20,"Text",true)
		local pending=snapshot.ArchiveStatus and snapshot.ArchiveStatus.PendingCount or 0
		label(content,"Five personal save slots • original crew required"..(pending>0 and (" • "..pending.." reserving") or ""),0,35,680,23,12,"TextMuted")
		if snapshot.ArchiveAvailable==false then
			label(content,"The archive is temporarily unavailable. Your saved worlds are safe; try again shortly.",0,79,680,64,15,"Amber").TextWrapped=true
			return
		end
		for index=1,5 do
			local world=(snapshot.Worlds or {})[index]
			local card=box(content,"Save"..index,0,74+(index-1)*114,680,102)
			if world then
				local name=textbox(card,world.Name or "Expedition",14,13,318); name.Text=world.Name or "Expedition"
				button(card,"RENAME",346,13,150,34,function() send("RenameWorld",{Id=world.Id,Name=name.Text}) end)
				local confirming=removalId==world.Id and os.clock()<removalUntil
				button(card,confirming and "CONFIRM REMOVE" or "REMOVE MY COPY",510,13,155,34,function()
					if removalId==world.Id and os.clock()<removalUntil then
						removalId=nil;send("RemoveWorld",{Id=world.Id})
					else
						removalId,removalUntil=world.Id,os.clock()+12
						feedback.Text="Remove only your named copy? Other crew copies stay. Resume can recreate yours when you have a free slot."
						render()
					end
				end)
				label(card,world.Summary or (tostring(world.OwnerCount or 6).." original crew members • "..(world.Status=="AwaitingSnapshot" and "Preparing first save" or "World saved")),14,59,450,27,12,"TextMuted")
				button(card,"RESUME",483,57,182,31,function() send("ResumeWorld",{Id=world.Id}) end,true)
			else label(card,"EMPTY SLOT  /  "..index,14,31,646,27,12,"TextMuted",true) end
		end
	end
end
remote.OnClientEvent:Connect(function(action,data)
	if action=="Snapshot" then
		snapshot=data
		-- Keep typed invitations/save names intact during periodic status updates.
		if not UIS:GetFocusedTextBox() then render() end
	elseif action=="Result" then feedback.Text=data.Message or "Updated."; Theme.Bind(feedback,"TextColor3",data.Success and "Success" or "Danger"); send("Snapshot") end
end)
UIS.InputBegan:Connect(function(input,processed) if not processed and input.KeyCode==Enum.KeyCode.F2 then panel.Visible=not panel.Visible; if panel.Visible then send("Snapshot") end end end)
player:GetAttributeChangedSignal("LobbyPanelVersion"):Connect(function() page=player:GetAttribute("LobbyPanel") or "Party"; panel.Visible=true; render(); send("Snapshot") end)
render(); send("Snapshot")
task.spawn(function() while gui.Parent do task.wait(5); if panel.Visible then send("Snapshot") end end end)
