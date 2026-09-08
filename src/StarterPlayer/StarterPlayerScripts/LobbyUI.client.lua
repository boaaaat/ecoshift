-- A responsive field kit: local interaction feedback, server-confirmed expedition state.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local SocialService = game:GetService("SocialService")
local Theme = require(RS:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("UITheme"))
local Mode = require(RS.Shared.SessionConfig).GetMode()
local player = Players.LocalPlayer
local remote = RS:WaitForChild("Remotes"):WaitForChild("Lobby", 60)
if not remote then return end

local gui = Instance.new("ScreenGui")
gui.Name = "ExpeditionAssembly"; gui.ResetOnSpawn = false; gui.DisplayOrder = 50
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = player.PlayerGui
Theme.TrackRoot(gui)
local panel = Instance.new("Frame")
panel.Name = "Assembly"; panel.AnchorPoint = Vector2.new(.5, .5)
panel.Position = UDim2.fromScale(.5, .5); panel.Size = UDim2.fromOffset(1120, 740)
panel.Visible = Mode == "Lobby"; panel.Parent = gui
Theme.Panel(panel); Theme.Fit(panel, 1120, 740); Theme.AnimatePanel(panel)

local function label(parent, text, x, y, w, h, size, token, bold)
	local l = Theme.Label(parent, text, UDim2.fromOffset(w, h), UDim2.fromOffset(x, y), size or 16, nil, bold)
	Theme.Bind(l, "TextColor3", token or "Text"); return l
end
local function button(parent, text, x, y, w, h, fn, primary)
	local b = Instance.new("TextButton")
	b.Name = text:gsub("%W", "") .. "Button"; b.Text = text; b.Font = Enum.Font.GothamBold; b.TextSize = 16
	b.Size = UDim2.fromOffset(w, h); b.Position = UDim2.fromOffset(x, y); b.Parent = parent
	Theme.Button(b, primary == true)
	if fn then b.Activated:Connect(fn) end
	return b
end
local function box(parent, name, x, y, w, h)
	local f = Instance.new("Frame"); f.Name = name; f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h); f.Parent = parent; Theme.Panel(f); return f
end
label(panel, "ECO / SHIFT", 28, 22, 330, 38, 32, "Text", true)
label(panel, "EXPEDITION OBSERVATORY", 30, 63, 450, 22, 14, "TextMuted", true)
local funds = label(panel, "CONNECTING TO FIELD RECORDS", 626, 29, 410, 30, 16, "Amber", true)
funds.TextXAlignment = Enum.TextXAlignment.Right
button(panel, "×", 1052, 24, 40, 40, function() panel.Visible = false end).TextSize = 26
local side = Instance.new("Frame")
side.Name = "Sections"; side.BackgroundTransparency = 1; side.Position = UDim2.fromOffset(28, 118)
side.Size = UDim2.fromOffset(220, 590); side.Parent = panel
local content = Instance.new("ScrollingFrame")
content.Name = "Content"; content.Position = UDim2.fromOffset(280, 115); content.Size = UDim2.fromOffset(812, 560)
content.BackgroundTransparency = 1; content.BorderSizePixel = 0; content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(); content.AutomaticCanvasSize = Enum.AutomaticSize.Y; content.Parent = panel
Theme.Bind(content, "ScrollBarImageColor3", "Moss")
local feedback = label(panel, "Assemble your crew. Prepare for the changing world.", 282, 691, 805, 36, 15, "TextMuted")
feedback.Name = "ActionFeedback"; feedback.TextWrapped = true; feedback.TextTruncate = Enum.TextTruncate.None
local function notify(text, token)
	feedback.Text = text; Theme.Bind(feedback, "TextColor3", token or "TextMuted")
end

local snapshot, page = {}, "Party"
local revision, requestSequence = 0, 0
local requestPrefix = HttpService:GenerateGUID(false) .. ":"
local sectionIds, scrollByPage, nameDrafts, nav = {}, {}, {}, {}
local submittedNames = {}
local pending, render, openPicker, queueLabel
local controls, removalId, removalUntil = {}, nil, 0
local friends, friendsLoading, friendsError, friendsLoadedAt = {}, false, nil, -math.huge
local inviteStatus, inviteExpiry, nativeInvite = {}, {}, nil
local lastPage, lastVisual = page, nil

local function requestId()
	requestSequence += 1; return requestPrefix .. tostring(requestSequence)
end
local function refresh(scope, extra)
	local data = extra or {}; data.RequestId = requestId(); data.Scope = scope or "Core"
	remote:FireServer("Snapshot", data)
end
local function applyControls()
	for _, control in ipairs(controls) do
		local b = control.Button
		local active = pending and pending.Action == control.Action and pending.Key == control.Key
		b.Interactable = not pending and not control.Disabled
		local text = active and control.Waiting or control.Text
		if b:IsA("TextButton") then b.Text = text; b.TextTransparency = pending and not active and .3 or 0
		elseif control.Status then control.Status.Text = active and "Inviting…" or control.Text end
		Theme.Bind(b, "BackgroundColor3", active and "SlotSelected" or control.Primary and "Moss" or "SlotEmpty")
	end
end
local function send(action, data, waiting)
	if pending then notify("Your previous action is still finishing…", "Amber"); return end
	data = table.clone(data or {}); data.RequestId = requestId()
	pending = {Id = data.RequestId, Action = action, Data = data, Key = tostring(data.Id or data.UserId or ""), Started = os.clock()}
	notify(waiting or "Updating…", "Amber"); applyControls()
	remote:FireServer(action, data)
end
local function actionButton(parent, text, waiting, action, data, x, y, w, h, primary, disabled)
	local b = button(parent, text, x, y, w, h, function() send(action, data, waiting) end, primary)
	table.insert(controls, {Button = b, Text = text, Waiting = waiting, Action = action,
		Key = tostring(data and (data.Id or data.UserId) or ""), Primary = primary, Disabled = disabled})
	return b
end
local function navigate(nextPage)
	page = nextPage; render()
	if page == "Saves" then refresh("Archive") else refresh("Core") end
end
for index, entry in ipairs({{"Party", "01  EXPEDITION CREW"}, {"Classes", "02  CLASS OUTFITTER"}, {"Saves", "03  WORLD ARCHIVE"}}) do
	nav[entry[1]] = button(side, entry[2], 0, (index - 1) * 62, 220, 50, function() navigate(entry[1]) end)
	nav[entry[1]].TextSize = 15
	if Mode ~= "Lobby" and entry[1] ~= "Party" then nav[entry[1]].Visible = false end
end
label(side, "1–6 EXPLORERS\nONE CHANGING WORLD", 8, 234, 205, 66, 14, "TextMuted", true).TextWrapped = true
label(side, "F2  ·  CREW PANEL\nF4  ·  APPEARANCE", 8, 474, 205, 55, 14, "TextMuted").TextWrapped = true
button(side, "APPEARANCE", 0, 540, 220, 44, function() player:SetAttribute("FieldKitSettings", (player:GetAttribute("FieldKitSettings") or 0) + 1) end)
local open = button(gui, Mode == "Lobby" and "EXPEDITION DESK  /  F2" or "CREW  /  F2", 0, 0, 264, 44, function()
	panel.Visible = not panel.Visible
	if panel.Visible then refresh("All") end
end, true)
local openHost = Instance.new("Frame"); openHost.Name = "DeskShortcut"; openHost.BackgroundTransparency = 1
openHost.Size = open.Size; openHost.AnchorPoint = Vector2.new(.5, 0); openHost.Position = UDim2.new(.5, 0, 0, 12); openHost.Parent = gui
open.Parent = openHost; Theme.Fit(openHost, 1120, 740, nil, true)
open.Visible = not panel.Visible
panel:GetPropertyChangedSignal("Visible"):Connect(function() open.Visible = not panel.Visible end)

local function textbox(parent, world, x, y, w)
	local b = Instance.new("TextBox"); b.Name = "WorldName"; b.PlaceholderText = "Expedition"
	b.Text = nameDrafts[world.Id] or world.Name or "Expedition"; b.ClearTextOnFocus = false
	b.Font = Enum.Font.Gotham; b.TextSize = 16; b.Position = UDim2.fromOffset(x, y); b.Size = UDim2.fromOffset(w, 42)
	b.Parent = parent; b.BorderSizePixel = 0; Theme.Corner(b, 6)
	Theme.Bind(b, "BackgroundColor3", "SlotEmpty"); Theme.Bind(b, "TextColor3", "Text"); Theme.Bind(b, "PlaceholderColor3", "TextMuted")
	b:GetPropertyChangedSignal("Text"):Connect(function() nameDrafts[world.Id] = b.Text end)
	return b
end
local descriptions = {
	Generalist = "A dependable all-round explorer.", Builder = "Raise camp quickly and reinforce the team.",
	Hunter = "Stronger strikes against biome creatures.", Gatherer = "Bring more materials back to camp.",
	Engineer = "Process supplies and craft equipment faster.", Medic = "Help fallen teammates return to the expedition.",
}

local function updateQueue()
	if not queueLabel or not queueLabel.Parent then return end
	local party = snapshot.Party or {}
	if party.Queue and party.Queue.Mode == "Party" then
		queueLabel.Text = string.format("%d / 6  ·  STARTING YOUR CREW'S EXPEDITION", #(party.Members or {}))
		Theme.Bind(queueLabel, "TextColor3", "Amber")
	elseif party.Queue then
		local started = tonumber(party.QueueStartedAt)
		local elapsed = started and math.max(0, math.floor(workspace:GetServerTimeNow() - started)) or 0
		queueLabel.Text = string.format("%d / 6  ·  FINDING EXPEDITION  ·  %02d:%02d", #(party.Members or {}), math.floor(elapsed / 60), elapsed % 60)
		Theme.Bind(queueLabel, "TextColor3", "Amber")
	else
		queueLabel.Text = party.Id and (#(party.Members or {}) .. " / 6  ·  " .. (party.RunId and "EXPEDITION ASSIGNED" or "PREPARING")) or "Start solo or invite friends. Matchmaking is optional."
		Theme.Bind(queueLabel, "TextColor3", "TextMuted")
	end
end

local function directoryRequest()
	local ids = {}; for _, friend in ipairs(friends) do table.insert(ids, friend.UserId) end
	refresh("InviteDirectory", {FriendIds = ids})
end
openPicker = function()
	page = "Invite"; render()
	if friendsLoading then return end
	if os.clock() - friendsLoadedAt < 30 then directoryRequest(); return end
	friendsLoading = true; friendsError = nil; render()
	-- Yielding platform calls never hold up opening the picker or its back button.
	task.spawn(function()
		local ok, result = pcall(player.GetFriendsOnlineAsync, player, 200)
		friendsLoading = false; friendsLoadedAt = os.clock()
		if ok then
			friends = {}; local seen = {}
			for _, friend in ipairs(result) do
				local id = tonumber(friend.VisitorId)
				if id and id ~= player.UserId and friend.IsOnline ~= false and not seen[id] then
					seen[id] = true
					table.insert(friends, {UserId = id, Name = friend.UserName, DisplayName = friend.DisplayName or friend.UserName, Friend = true})
				end
			end
		else friendsError = "Online friends could not load. Server players are still available." end
		if page == "Invite" then render() end
		directoryRequest()
	end)
end

local function invite(entry)
	local party = snapshot.Party or {}
	if party.LeaderId ~= player.UserId or party.RunId then notify("Only the crew leader can invite players before a run.", "Amber"); return end
	if entry.CanPartyInvite or entry.InServer then
		send("Invite", {UserId = entry.UserId}, "Inviting " .. entry.DisplayName .. "…")
	elseif entry.InExperience then
		notify("This friend is on an expedition. Invite them when they return to the observatory.", "Amber")
	elseif entry.PresenceAvailable ~= true then
		notify("Checking this friend's crew connection… Try again in a moment.", "Amber")
		directoryRequest()
	elseif entry.Friend then
		if nativeInvite then notify("Finish the open Roblox invite first.", "Amber"); return end
		nativeInvite = entry.UserId; inviteStatus[entry.UserId] = "Opening invite…"; render()
		task.spawn(function()
			local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player, entry.UserId)
			if nativeInvite ~= entry.UserId then return end
			if not ok or not allowed then
				nativeInvite = nil; inviteStatus[entry.UserId] = nil
				notify("Roblox cannot send an invite to this friend right now.", "Amber"); if page == "Invite" then render() end; return
			end
			local options = Instance.new("ExperienceInviteOptions"); options.InviteUser = entry.UserId
			options.PromptMessage = "Invite this friend to your EcoShift expedition."
			inviteStatus[entry.UserId] = "Confirm in Roblox"
			local prompted = pcall(SocialService.PromptGameInvite, SocialService, player, options)
			options:Destroy()
			if not prompted then nativeInvite = nil; inviteStatus[entry.UserId] = nil; notify("The Roblox invite could not open. Try again.", "Amber") end
			if page == "Invite" then render() end
		end)
	else notify("That player is no longer available to invite.", "Amber") end
end
SocialService.GameInvitePromptClosed:Connect(function(sender, recipients)
	if sender ~= player or not nativeInvite then return end
	local target = nativeInvite; nativeInvite = nil
	local sent = false; for _, id in ipairs(recipients or {}) do if tonumber(id) == target then sent = true end end
	inviteStatus[target] = sent and "Invite sent" or nil
	inviteExpiry[target] = sent and os.clock() + 10 or nil
	notify(sent and "Roblox invite sent. Add your friend to the crew when they arrive." or "Invite closed.", sent and "Success" or "TextMuted")
	if page == "Invite" then render() end
end)

local function renderPicker()
	label(content, "INVITE EXPLORERS", 0, 0, 550, 34, 25, "Text", true)
	button(content, "BACK TO CREW", 600, 0, 196, 40, function() navigate("Party") end)
	label(content, "Choose a profile to invite them.", 0, 43, 790, 27, 16, "TextMuted")
	local entries, byId, inCrew = {}, {}, {}
	for _, member in ipairs((snapshot.Party or {}).Members or {}) do inCrew[member.UserId] = true end
	for _, friend in ipairs(friends) do local entry = table.clone(friend); byId[entry.UserId] = entry; table.insert(entries, entry) end
	for _, row in ipairs((snapshot.InviteDirectory or {}).Entries or {}) do
		local entry = byId[row.UserId]
		if entry then for key, value in pairs(row) do entry[key] = value end end
	end
	-- Current-server players appear immediately, even while friend presence loads.
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local entry = byId[other.UserId]
			if not entry then entry = {UserId = other.UserId}; byId[other.UserId] = entry; table.insert(entries, entry) end
			entry.Name = other.Name; entry.DisplayName = other.DisplayName; entry.InServer = true
		end
	end
	table.sort(entries, function(a, b)
		if (a.Friend == true) ~= (b.Friend == true) then return a.Friend == true end
		local an, bn = string.lower(a.DisplayName or a.Name or ""), string.lower(b.DisplayName or b.Name or "")
		return an == bn and a.UserId < b.UserId or an < bn
	end)
	local y, column, group = 84, 0, nil
	if friendsLoading or friendsError then
		label(content, friendsLoading and "Loading online friends…" or friendsError, 0, y, 790, 40, 15, "TextMuted").TextWrapped = true; y += 48
	end
	for _, entry in ipairs(entries) do
		local nextGroup = entry.Friend and "ONLINE FRIENDS" or "IN THIS SERVER"
		if nextGroup ~= group then
			if column > 0 then y += 226; column = 0 end
			group = nextGroup; label(content, group, 0, y, 790, 27, 14, "TextMuted", true); y += 36
		end
		local tile = Instance.new("ImageButton"); tile.Name = "Invite_" .. entry.UserId
		tile.Size = UDim2.fromOffset(190, 210); tile.Position = UDim2.fromOffset(column * 202, y)
		tile.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150"
		tile.ScaleType = Enum.ScaleType.Fit; tile.Parent = content; Theme.Button(tile, false)
		local fallback = label(tile, "?", 0, 0, 190, 146, 48, "TextMuted", true)
		fallback.Name = "PortraitPlaceholder"; fallback.TextXAlignment = Enum.TextXAlignment.Center
		fallback.Visible = not tile.IsLoaded
		tile:GetPropertyChangedSignal("IsLoaded"):Connect(function() fallback.Visible = not tile.IsLoaded end)
		local plate = Instance.new("Frame"); plate.Name = "Nameplate"; plate.BorderSizePixel = 0
		plate.Size = UDim2.new(1, 0, 0, 64); plate.Position = UDim2.new(0, 0, 1, -64); plate.Parent = tile
		Theme.Bind(plate, "BackgroundColor3", "Panel"); Theme.Corner(plate, 6)
		local name = label(plate, entry.DisplayName or entry.Name or "Explorer", 9, 6, 172, 26, 16, "Text", true)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local statusText = inCrew[entry.UserId] and "In your crew" or inviteStatus[entry.UserId] or ("@" .. (entry.Name or "Explorer"))
		local status = label(plate, statusText, 9, 32, 172, 24, 13, inviteStatus[entry.UserId] and "Success" or "TextMuted")
		status.TextXAlignment = Enum.TextXAlignment.Center
		tile.Activated:Connect(function() invite(entry) end)
		table.insert(controls, {Button = tile, Status = status, Text = statusText, Action = "Invite", Key = tostring(entry.UserId),
			Disabled = inCrew[entry.UserId] or inviteStatus[entry.UserId] ~= nil})
		column += 1; if column == 4 then column = 0; y += 226 end
	end
	if #entries == 0 and not friendsLoading then label(content, "No online friends or other server players right now.", 0, y, 790, 50, 17, "TextMuted") end
end

-- Compare only visible state; heartbeat timestamps should never rebuild buttons.
local function visualKey()
	local party = snapshot.Party or {}
	local crew = {}
	for _, member in ipairs(party.Members or {}) do table.insert(crew, {member.UserId, member.DisplayName, member.Role, member.Ready == true, member.Online == true}) end
	return HttpService:JSONEncode({page, snapshot.Currency, snapshot.Classes, party.Id, party.LeaderId, party.RunId,
		party.Queue and party.Queue.Mode or false, party.Queue ~= nil and party.Queue ~= false, party.QueueStartedAt, crew, party.Invites, snapshot.Rejoin, page == "Saves" and snapshot.Worlds or false,
		page == "Saves" and snapshot.ArchiveAvailable, page == "Invite" and snapshot.InviteDirectory or false})
end
render = function()
	scrollByPage[lastPage] = content.CanvasPosition
	for _, child in ipairs(content:GetChildren()) do child:Destroy() end
	controls = {}; queueLabel = nil
	content.CanvasPosition = scrollByPage[page] or Vector2.zero; lastPage = page
	for key, b in pairs(nav) do Theme.Bind(b, "BackgroundColor3", (key == page or key == "Party" and page == "Invite") and "SlotSelected" or "SlotEmpty") end
	funds.Text = tostring(snapshot.Currency or 0) .. "  " .. string.upper(snapshot.CurrencyName or "FIELD MARKS")
	lastVisual = visualKey()
	if not snapshot.Classes then label(content, "Retrieving expedition records…", 0, 10, 790, 44, 22, "TextMuted"); return end
	if page == "Invite" then renderPicker()
	elseif page == "Party" then
		local party = snapshot.Party or {Members = {}, Invites = {}}
		label(content, "YOUR EXPEDITION CREW", 0, 0, 790, 34, 25, "Text", true)
		queueLabel = label(content, "", 0, 41, 790, 28, 16, "TextMuted"); queueLabel.Name = "QueueStatus"; updateQueue()
		local selfMember
		for index = 1, 6 do
			local member = (party.Members or {})[index]
			local card = box(content, "Crew" .. index, ((index - 1) % 2) * 404, 84 + math.floor((index - 1) / 2) * 104, 392, 92)
			if member then
				label(card, member.DisplayName .. (member.UserId == party.LeaderId and "  /  LEADER" or ""), 16, 14, 360, 29, 18, "Text", true)
				local status = member.Online and (member.Ready and "READY" or "NOT READY") or "OFFLINE"
				local detail = label(card, (member.Role or "Generalist") .. "  ·  " .. status, 16, 51, 360, 25, 16, member.Online and member.Ready and "Success" or "TextMuted")
				detail.Name = "Readiness"
				if member.UserId == player.UserId then selfMember = member end
			else label(card, "OPEN CREW SLOT", 16, 30, 360, 28, 15, "TextMuted", true) end
		end
		local y = 416
		if not party.Id then actionButton(content, "CREATE PARTY", "CREATING…", "CreateParty", nil, 0, y, 250, 46, true)
		else
			if not party.RunId then actionButton(content, selfMember and selfMember.Ready and "NOT READY" or "READY UP", "UPDATING…", "Ready", {Ready = not (selfMember and selfMember.Ready)}, 0, y, 190, 46, true) end
			actionButton(content, "LEAVE PARTY", "LEAVING…", "LeaveParty", nil, 202, y, 190, 46)
			if party.LeaderId == player.UserId and Mode == "Lobby" and not party.RunId then
				local starting = party.Queue and party.Queue.Mode == "Party"
				actionButton(content, starting and "STARTING EXPEDITION…" or "START EXPEDITION", "STARTING…", "StartExpedition", nil, 404, y, 392, 46, true, party.Queue ~= nil and party.Queue ~= false)
			end
			if party.LeaderId == player.UserId and not party.RunId then
				y += 60
				local inviteButton = button(content, "+  INVITE EXPLORERS", 0, y, 392, 46, openPicker)
				inviteButton.Interactable = not party.Queue and #(party.Members or {}) < 6
				if Mode == "Lobby" then
					local starting = party.Queue and party.Queue.Mode == "Party"
					actionButton(content, party.Queue and (starting and "CANCEL START" or "CANCEL MATCHMAKING") or "MATCHMAKE · FILL CREW", party.Queue and "CANCELLING…" or "JOINING QUEUE…", party.Queue and "CancelQueue" or "Queue", nil, 404, y, 392, 46, false, not party.Queue and #(party.Members or {}) >= 6)
				end
				y += 52
				label(content, "Start with 1–6 ready players. Matchmaking fills open seats with other explorers.", 0, y, 796, 42, 14, "TextMuted").TextWrapped = true
			end
		end
		y += 62
		if Mode == "Expedition" then actionButton(content, "RETURN TO OBSERVATORY", "RETURNING…", "ReturnLobby", nil, 0, y, 796, 46, true); y += 62 end
		if snapshot.Rejoin and snapshot.Rejoin.Available then actionButton(content, "REJOIN ACTIVE EXPEDITION", "REJOINING…", "Rejoin", nil, 0, y, 796, 46, true); y += 62 end
		for _, invitation in ipairs(party.Invites or {}) do
			label(content, invitation.From .. " invited you to a party", 0, y, 575, 44, 16)
			actionButton(content, "ACCEPT", "JOINING…", "AcceptInvite", {Id = invitation.Id}, 610, y, 186, 44, true); y += 58
		end
	elseif page == "Classes" then
		label(content, "CLASS OUTFITTER", 0, 0, 796, 34, 25, "Text", true)
		label(content, "Permanent unlocks · earn Field Marks on expeditions", 0, 43, 796, 28, 16, "TextMuted")
		for index, class in ipairs(snapshot.Classes or {}) do
			local card = box(content, class.Id, ((index - 1) % 2) * 404, 84 + math.floor((index - 1) / 2) * 180, 392, 166)
			label(card, class.Name, 16, 14, 360, 30, 24, "Text", true)
			local description = label(card, descriptions[class.Id] or "", 16, 50, 360, 49, 16, "TextMuted")
			description.TextWrapped = true; description.TextTruncate = Enum.TextTruncate.None
			local text = class.Selected and "EQUIPPED" or class.Owned and "EQUIP CLASS" or (tostring(class.Price) .. " FIELD MARKS  ·  UNLOCK")
			actionButton(card, text, class.Owned and "EQUIPPING…" or "UNLOCKING…", class.Owned and "SelectClass" or "BuyClass", {Id = class.Id}, 16, 112, 360, 40, class.Selected, class.Selected)
		end
	else
		label(content, "WORLD ARCHIVE", 0, 0, 796, 34, 25, "Text", true)
		label(content, "Five personal save slots · original crew required", 0, 43, 796, 28, 16, "TextMuted")
		if snapshot.ArchiveAvailable == nil then label(content, "Opening your saved worlds…", 0, 87, 796, 54, 19, "TextMuted"); return end
		if snapshot.ArchiveAvailable == false then
			label(content, "The archive is temporarily unavailable. Your saved worlds are safe; try again shortly.", 0, 87, 796, 70, 18, "Amber").TextWrapped = true; return
		end
		for index = 1, 5 do
			local world = (snapshot.Worlds or {})[index]
			local card = box(content, "Save" .. index, 0, 84 + (index - 1) * 140, 796, 126)
			if world then
				local name = textbox(card, world, 16, 16, 352)
				-- Read the current draft when clicked, rather than the render-time name.
				local renameButton = button(card, "RENAME", 382, 16, 164, 42, function() send("RenameWorld", {Id = world.Id, Name = name.Text}, "Saving world name…") end)
				table.insert(controls, {Button = renameButton, Text = "RENAME", Waiting = "SAVING…", Action = "RenameWorld", Key = tostring(world.Id)})
				local confirming = removalId == world.Id and os.clock() < removalUntil
				local remove = button(card, confirming and "CONFIRM REMOVE" or "REMOVE MY COPY", 560, 16, 220, 42, function()
					if pending then notify("Your previous action is still finishing…", "Amber"); return end
					if removalId == world.Id and os.clock() < removalUntil then removalId = nil; send("RemoveWorld", {Id = world.Id}, "Removing your copy…")
					else removalId, removalUntil = world.Id, os.clock() + 12; notify("Remove your named copy? Other crew copies stay. Crew resume can recreate yours in a free slot.", "Amber"); render() end
				end)
				table.insert(controls, {Button = remove, Text = remove.Text, Waiting = "REMOVING…", Action = "RemoveWorld", Key = tostring(world.Id)})
				label(card, world.Summary or (tostring(world.OwnerCount or 6) .. " original crew · " .. (world.Status == "AwaitingSnapshot" and "Preparing first save" or "World saved")), 16, 74, 535, 34, 15, "TextMuted")
				actionButton(card, "RESUME", "PREPARING…", "ResumeWorld", {Id = world.Id}, 586, 72, 194, 38, true)
			else label(card, "EMPTY SLOT  /  " .. index, 16, 44, 764, 32, 16, "TextMuted", true) end
		end
	end
	applyControls()
end

local function reconcile(request, result)
	local party = snapshot.Party or {}
	if request.Action == "SelectClass" then
		local role = result.ConfirmedRole or request.Data.Id
		for _, class in ipairs(snapshot.Classes or {}) do class.Selected = class.Id == role end
		for _, member in ipairs(party.Members or {}) do
			if member.UserId == player.UserId and not party.RunId then
				if member.Role ~= role then member.Ready = false end
				member.Role = role
			end
		end
	elseif request.Action == "Ready" then
		for _, member in ipairs(party.Members or {}) do if member.UserId == player.UserId then member.Ready = request.Data.Ready end end
	elseif request.Action == "CancelQueue" then party.Queue = false; party.QueueStartedAt = nil
	elseif request.Action == "BuyClass" then
		for _, class in ipairs(snapshot.Classes or {}) do if class.Id == request.Data.Id then class.Owned = true end end
	elseif request.Action == "Invite" then inviteStatus[request.Data.UserId] = "Invite sent"; inviteExpiry[request.Data.UserId] = os.clock() + 15
	elseif request.Action == "RenameWorld" then submittedNames[request.Data.Id] = request.Data.Name end
end
remote.OnClientEvent:Connect(function(action, data)
	if type(data) ~= "table" then return end
	local incoming = tonumber(data.StateRevision) or 0
	if action == "Snapshot" then
		local section = data.Section or "Core"
		if incoming < revision or (tonumber(data.SnapshotId) or 0) <= (sectionIds[section] or -1) then return end
		revision = incoming; sectionIds[section] = tonumber(data.SnapshotId) or 0
		if section == "Archive" then
			for id, name in pairs(submittedNames) do
				if nameDrafts[id] == name then nameDrafts[id] = nil end
				submittedNames[id] = nil
			end
		end
		for key, value in pairs(data) do
			if key ~= "StateRevision" and key ~= "SnapshotId" and key ~= "RequestId" and key ~= "Section" and key ~= "Partial" and key ~= "ServerTime" then snapshot[key] = value end
		end
		if not UIS:GetFocusedTextBox() and visualKey() ~= lastVisual then render() end
		updateQueue()
	elseif action == "Accepted" then
		revision = math.max(revision, incoming)
	elseif action == "Result" and data.Action ~= "Snapshot" then
		revision = math.max(revision, incoming)
		if not pending or data.RequestId ~= pending.Id then return end
		local completed = pending; pending = nil
		if data.Success then reconcile(completed, data) end
		local message = data.Message or "Updated."
		if data.Success and completed.Action == "SelectClass" then message = (data.ConfirmedRole or completed.Data.Id) .. " equipped."
		elseif data.Success and completed.Action == "BuyClass" then message = "Class unlocked. Choose Equip Class to use it." end
		notify(message, data.Success and "Success" or "Danger")
		if not UIS:GetFocusedTextBox() then render() else applyControls() end
	elseif action == "Notice" and type(data.Message) == "string" then
		notify(data.Message, data.Success and "Success" or "Amber")
	elseif action == "SnapshotError" and incoming >= revision then
		if data.Section == "Archive" then snapshot.ArchiveAvailable = false end
		if data.Section == "Core" and not snapshot.Classes then notify("Expedition records could not load. Retrying…", "Amber") end
		if not UIS:GetFocusedTextBox() then render() end
	end
end)
UIS.TextBoxFocusReleased:Connect(function() task.defer(function() if not UIS:GetFocusedTextBox() and visualKey() ~= lastVisual then render() end end) end)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then panel.Visible = not panel.Visible; if panel.Visible then refresh("All") end end
end)
player:GetAttributeChangedSignal("LobbyPanelVersion"):Connect(function()
	page = player:GetAttribute("LobbyPanel") or "Party"; panel.Visible = true; render(); refresh("All")
end)
for _, event in ipairs({Players.PlayerAdded, Players.PlayerRemoving}) do event:Connect(function() task.defer(function() if page == "Invite" then render() end end) end) end
render(); refresh("All")
task.spawn(function()
	local tick = 0
	while gui.Parent do
		task.wait(1); tick += 1; updateQueue()
		if pending and os.clock() - pending.Started > 8 then notify("Still confirming your action… You can keep browsing.", "Amber") end
		if tick % 5 == 0 and panel.Visible then refresh("Core") end
		local expired = false
		for id, untilTime in pairs(inviteExpiry) do
			if os.clock() >= untilTime then inviteExpiry[id] = nil; inviteStatus[id] = nil; expired = true end
		end
		if expired and page == "Invite" then render() end
		if removalId and os.clock() >= removalUntil then removalId = nil; if page == "Saves" and not UIS:GetFocusedTextBox() then render() end end
		if tick % 30 == 0 and panel.Visible then
			if page == "Invite" then openPicker() elseif page == "Saves" then refresh("Archive") end
			refresh("Rejoin")
		end
	end
end)
