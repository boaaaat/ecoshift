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
local memberNote, memberMessage
local function notify(text, token)
	feedback.Text = text; Theme.Bind(feedback, "TextColor3", token or "TextMuted")
	if memberNote and memberNote.Parent then
		memberMessage = {Text = text, Token = token or "TextMuted"}
		memberNote.Text = text; Theme.Bind(memberNote, "TextColor3", memberMessage.Token)
	end
end

local snapshot, page = {}, "Party"
local revision, requestSequence = 0, 0
local requestPrefix = HttpService:GenerateGUID(false) .. ":"
local sectionIds, scrollByPage, nameDrafts, nav = {}, {}, {}, {}
local submittedNames = {}
local pending, render, openPicker, queueLabel
local selectedMemberId, memberOverlay
local controls, removalId, removalUntil = {}, nil, 0
local friends, friendsLoading, friendsError, friendsLoadedAt = {}, false, nil, -math.huge
local inviteStatus, inviteExpiry, nativeInvite = {}, {}, nil
local invitePopup, popupAccept, popupStatus, popupTimer, popupBar, activeInvitation, popupDeadline, popupMessage
local seenInvitations = {}
local inboxEpoch, inboxReads = 0, {}
local updateInvitePopup, updatePopupControls
local lastPage, lastVisual = page, nil

local function requestId()
	requestSequence += 1; return requestPrefix .. tostring(requestSequence)
end
local function refresh(scope, extra)
	local data = extra or {}; data.RequestId = requestId(); data.Scope = scope or "Core"
	if data.Scope == "Invites" then inboxReads[data.RequestId] = {Epoch = inboxEpoch, At = os.clock()} end
	remote:FireServer("Snapshot", data)
end
local function applyControls()
	for _, control in ipairs(controls) do
		local b = control.Button
		if not b.Parent then continue end
		local active = pending and pending.Action == control.Action and pending.Key == control.Key
		b.Interactable = not pending and not control.Disabled
		local text = active and control.Waiting or control.Text
		if b:IsA("TextButton") then b.Text = text; b.TextTransparency = control.Disabled and .45 or pending and not active and .3 or 0
		elseif control.Status then control.Status.Text = active and "Inviting…" or control.Text end
		Theme.Bind(b, "BackgroundColor3", active and "SlotSelected" or control.Primary and "Moss" or "SlotEmpty")
	end
	if updatePopupControls then updatePopupControls() end
end
local function send(action, data, waiting)
	if pending then notify("Your previous action is still finishing…", "Amber"); return end
	data = table.clone(data or {}); data.RequestId = requestId()
	pending = {Id = data.RequestId, Action = action, Data = data, Key = tostring(data.Id or data.UserId or ""), Started = os.clock(), PartyId = (snapshot.Party or {}).Id}
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
	selectedMemberId = nil; page = nextPage; render()
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
openHost.Size = open.Size
openHost.AnchorPoint = Vector2.new(.5, Mode == "Lobby" and 1 or 0)
openHost.Position = Mode == "Lobby" and UDim2.new(.5, 0, 1, -18) or UDim2.new(.5, 0, 0, 12)
openHost.Parent = gui
open.Parent = openHost; Theme.Fit(openHost, 1120, 740, nil, true)
open.Visible = not panel.Visible
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	open.Visible = not panel.Visible
	if not panel.Visible then
		selectedMemberId = nil
		if memberOverlay then memberOverlay:Destroy(); memberOverlay = nil end
	end
end)

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

-- Roblox loads thumbnails asynchronously over the neutral portrait background.
local function loadPortrait(image, userId)
	image.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
	image.ScaleType = Enum.ScaleType.Fit
end
local function portrait(parent, userId, x, y, size)
	local image = Instance.new("ImageLabel"); image.Name = "AvatarPortrait"
	image.Size = UDim2.fromOffset(size, size); image.Position = UDim2.fromOffset(x, y)
	image.BorderSizePixel = 0; image.Parent = parent
	Theme.Bind(image, "BackgroundColor3", "SlotEmpty"); Theme.Corner(image, 8)
	loadPortrait(image, userId)
	return image
end
local function liveInvitations()
	local list = {}
	for _, invitation in ipairs(snapshot.Invites or (snapshot.Party or {}).Invites or {}) do
		if type(invitation.Id) == "string" and type(invitation.ExpiresAt) == "number"
			and invitation.ExpiresAt > workspace:GetServerTimeNow() then table.insert(list, invitation) end
	end
	return list
end
local function closeInvitePopup()
	if invitePopup then invitePopup:Destroy() end
	invitePopup, popupAccept, popupStatus, popupTimer, popupBar, activeInvitation = nil, nil, nil, nil, nil, nil
end
updatePopupControls = function()
	if not popupAccept then return end
	local joining = pending and pending.Action == "AcceptInvite" and pending.Key == activeInvitation.Id
	-- Membership can change on another server while this panel is closed.
	-- The accept endpoint validates the current crew instead of a stale UI lock.
	popupAccept.Interactable = not pending
	popupAccept.Text = joining and "JOINING…" or "ACCEPT INVITE"
	popupAccept.TextTransparency = popupAccept.Interactable and 0 or .35
	if joining then popupStatus.Text = "Confirming your place in the crew…"
	else popupStatus.Text = popupMessage or ((snapshot.Party or {}).Id and "Leave your current crew before accepting." or "You can also accept from the crew menu.") end
end
updateInvitePopup = function()
	if Mode ~= "Lobby" then return end
	local list = liveInvitations()
	if activeInvitation then
		local stillLive = false
		for _, invitation in ipairs(list) do if invitation.Id == activeInvitation.Id then stillLive = true; break end end
		if not stillLive or os.clock() >= popupDeadline then closeInvitePopup() end
	end
	if not activeInvitation then
		for _, invitation in ipairs(list) do
			if not seenInvitations[invitation.Id] then
				seenInvitations[invitation.Id] = invitation.ExpiresAt
				activeInvitation = invitation
				popupMessage = nil
				refresh("Core")
				popupDeadline = os.clock() + math.min(20, invitation.ExpiresAt - workspace:GetServerTimeNow())
				local popup = box(gui, "InvitationPopup", 0, 0, 470, 242)
				invitePopup = popup; popup.Active = true; popup.ZIndex = 60; popup.AnchorPoint = Vector2.new(1, 1)
				popup.Position = UDim2.new(1, -20, 1, -20); popup.Visible = false
				Theme.Fit(popup, 470, 242); Theme.AnimatePanel(popup)
				label(popup, "YOU'RE INVITED", 20, 15, 345, 30, 23, "Amber", true)
				button(popup, "×", 410, 12, 40, 40, function() closeInvitePopup(); updateInvitePopup() end).TextSize = 25
				local nameX = 20
				if type(invitation.FromUserId) == "number" and invitation.FromUserId > 0 then portrait(popup, invitation.FromUserId, 20, 62, 62); nameX = 98 end
				label(popup, invitation.From or "An explorer", nameX, 63, 450 - nameX, 29, 21, "Text", true)
				label(popup, "invited you to their expedition crew", nameX, 95, 450 - nameX, 26, 15, "TextMuted")
				popupAccept = button(popup, "ACCEPT INVITE", 20, 139, 210, 44, function() send("AcceptInvite", {Id = invitation.Id}, "Joining the crew…") end, true)
				button(popup, "VIEW IN MENU", 240, 139, 210, 44, function()
					panel.Visible = true; scrollByPage.Party = Vector2.zero; navigate("Party"); content.CanvasPosition = Vector2.zero
				end)
				popupStatus = label(popup, "You can also accept from the crew menu.", 20, 192, 373, 31, 14, "TextMuted")
				popupStatus.TextWrapped = true; popupStatus.TextTruncate = Enum.TextTruncate.None
				popupTimer = label(popup, "20s", 399, 192, 51, 31, 15, "Amber", true)
				local track = Instance.new("Frame"); track.Name = "Lifetime"; track.BackgroundTransparency = 1
				track.Position = UDim2.fromOffset(20, 232); track.Size = UDim2.fromOffset(430, 3); track.Parent = popup
				popupBar = Instance.new("Frame"); popupBar.BorderSizePixel = 0; popupBar.Size = UDim2.fromScale(1, 1); popupBar.Parent = track
				Theme.Bind(popupBar, "BackgroundColor3", "Amber")
				popup.Visible = true
				task.delay(math.max(0, popupDeadline - os.clock()), function() if activeInvitation == invitation then updateInvitePopup() end end)
				break
			end
		end
	end
	if invitePopup then
		local remaining = math.max(0, popupDeadline - os.clock())
		popupTimer.Text = tostring(math.ceil(remaining)) .. "s"
		popupBar.Size = UDim2.fromScale(math.clamp(remaining / 20, 0, 1), 1)
		updatePopupControls()
	end
end
local function startingExpedition(party)
	return party.Queue and party.Queue.Mode == "Party" and party.Queue.Purpose ~= "LobbyMerge"
end
local function readiness(member)
	return member.Online and (member.Ready and "READY" or "NOT READY") or "OFFLINE"
end
local function crewReady(party)
	if #(party.Members or {}) == 0 then return false end
	for _, member in ipairs(party.Members) do if not member.Online or not member.Ready then return false end end
	return true
end

local function updateQueue()
	if not queueLabel or not queueLabel.Parent then return end
	local party = snapshot.Party or {}
	if startingExpedition(party) then
		queueLabel.Text = string.format("%d / 6  ·  STARTING YOUR CREW'S EXPEDITION", #(party.Members or {}))
		Theme.Bind(queueLabel, "TextColor3", "Amber")
	elseif party.Queue then
		local started = tonumber(party.QueueStartedAt)
		local elapsed = started and math.max(0, math.floor(workspace:GetServerTimeNow() - started)) or 0
		queueLabel.Text = string.format("%d / 6  ·  FINDING TEAMMATES  ·  %02d:%02d", #(party.Members or {}), math.floor(elapsed / 60), elapsed % 60)
		Theme.Bind(queueLabel, "TextColor3", "Amber")
	else
		queueLabel.Text = party.Id and (#(party.Members or {}) .. " / 6  ·  " .. (party.RunId and "EXPEDITION ASSIGNED" or party.MergedCrew and (crewReady(party) and "CREW READY · LEADER CAN START" or "CREWS JOINED · READY UP AGAIN") or "PREPARING")) or "Start solo or invite friends. Matchmaking is optional."
		Theme.Bind(queueLabel, "TextColor3", "TextMuted")
	end
end

local function directoryRequest()
	local ids = {}; for _, friend in ipairs(friends) do table.insert(ids, friend.UserId) end
	refresh("InviteDirectory", {FriendIds = ids})
end
openPicker = function()
	selectedMemberId = nil; page = "Invite"; render()
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
	local party = snapshot.Party or {}
	local guidance = not party.Id and "Create a party from the crew menu before inviting players."
		or party.LeaderId ~= player.UserId and "Your crew leader can send invitations."
		or "Choose a profile to invite them."
	label(content, guidance, 0, 43, 790, 27, 16, "TextMuted")
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
		tile.Image = ""; tile.Parent = content; Theme.Button(tile, false)
		-- A square portrait ends above the nameplate; text never covers the face.
		local avatar = portrait(tile, entry.UserId, 28, 6, 134)
		avatar.BackgroundTransparency = 1
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

local function renderMemberMenu()
	if not selectedMemberId or page ~= "Party" then return end
	local party = snapshot.Party or {}
	local member
	for _, candidate in ipairs(party.Members or {}) do if candidate.UserId == selectedMemberId then member = candidate; break end end
	if not member then selectedMemberId = nil; return end
	local function closeMenu() selectedMemberId = nil; render() end
	local overlay = Instance.new("TextButton"); overlay.Name = "MemberDetailOverlay"
	overlay.Text = ""; overlay.AutoButtonColor = false; overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = .2; overlay.BorderSizePixel = 0; overlay.ZIndex = 20; overlay.Parent = panel
	Theme.Bind(overlay, "BackgroundColor3", "Night"); Theme.Corner(overlay, 10)
	overlay.Activated:Connect(closeMenu); memberOverlay = overlay
	local menu = box(overlay, "MemberDetails", 0, 0, 448, 454)
	menu.AnchorPoint = Vector2.new(.5, .5); menu.Position = UDim2.fromScale(.5, .5); menu.Active = true
	label(menu, "CREW PROFILE", 20, 17, 344, 30, 20, "Text", true)
	button(menu, "×", 386, 13, 42, 42, closeMenu).TextSize = 26
	portrait(menu, member.UserId, 20, 66, 100)
	label(menu, member.DisplayName or member.Name or "Explorer", 136, 69, 292, 32, 23, "Text", true)
	label(menu, "@" .. (member.Name or "Explorer"), 136, 105, 292, 23, 15, "TextMuted")
	label(menu, readiness(member) .. (member.UserId == party.LeaderId and "  /  LEADER" or ""), 136, 139, 292, 25, 14,
		member.Online and member.Ready and "Success" or "TextMuted", true)
	label(menu, member.Role or "Generalist", 20, 184, 408, 29, 21, "Text", true)
	label(menu, descriptions[member.Role] or "Expedition crew member.", 20, 218, 408, 43, 15, "TextMuted").TextWrapped = true
	local records = box(menu, "FieldRecords", 20, 274, 408, 62)
	label(records, "FIELD RECORDS", 12, 8, 384, 20, 12, "TextMuted", true)
	label(records, "Career statistics are not available yet.", 12, 31, 384, 23, 14, "TextMuted")
	local leader = party.LeaderId == player.UserId and member.UserId ~= player.UserId
	local locked = Mode ~= "Lobby" or party.Queue or party.RunId or party.ManagementLocked
	if leader then
		actionButton(menu, "KICK MEMBER", "REMOVING…", "KickMember", {UserId = member.UserId}, 20, 352, 198, 44, false, locked)
		actionButton(menu, "MAKE LEADER", "UPDATING…", "TransferLeader", {UserId = member.UserId}, 230, 352, 198, 44, true, locked or not member.Online)
		memberNote = label(menu, locked and "Crew changes are locked while queued or on an expedition." or "Leadership can be passed to an online crew member.", 20, 404, 408, 34, 13, "TextMuted")
	else
		memberNote = label(menu, member.UserId == player.UserId and "This is your expedition profile." or "Only the crew leader can manage other members.", 20, 355, 408, 58, 15, "TextMuted")
	end
	memberNote.TextWrapped = true; memberNote.TextTruncate = Enum.TextTruncate.None
	if memberMessage then memberNote.Text = memberMessage.Text; Theme.Bind(memberNote, "TextColor3", memberMessage.Token) end
	menu.Visible = false; Theme.AnimatePanel(menu); menu.Visible = true
end

-- Compare only visible state; heartbeat timestamps should never rebuild buttons.
local function visualKey()
	local party = snapshot.Party or {}
	local crew = {}
	for _, member in ipairs(party.Members or {}) do table.insert(crew, {member.UserId, member.DisplayName, member.Name, member.Role, member.Ready == true, member.Online == true}) end
	return HttpService:JSONEncode({page, snapshot.Currency, snapshot.Classes, party.Id, party.LeaderId, party.RunId,
		party.Queue and party.Queue.Mode or false, party.Queue and party.Queue.Purpose or false, party.ManagementLocked == true, party.MergedCrew == true, selectedMemberId or false,
		party.Queue ~= nil and party.Queue ~= false, party.QueueStartedAt, crew, liveInvitations(), snapshot.Rejoin, page == "Saves" and snapshot.Worlds or false,
		page == "Saves" and snapshot.ArchiveAvailable, page == "Invite" and snapshot.InviteDirectory or false})
end
render = function()
	if memberOverlay then memberOverlay:Destroy(); memberOverlay = nil end
	memberNote = nil
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
		local crewTop = 84
		local invitations = liveInvitations()
		if #invitations > 0 then
			label(content, "PARTY INVITATIONS", 0, crewTop, 796, 25, 16, "Amber", true); crewTop += 34
			for _, invitation in ipairs(invitations) do
				local row = box(content, "Invitation_" .. invitation.Id, 0, crewTop, 796, 72)
				label(row, (invitation.From or "An explorer") .. " invited you", 16, 9, 546, 28, 19, "Text", true)
				label(row, party.Id and "Leave your current crew before accepting." or "Join their expedition crew.", 16, 39, 546, 23, 14, "TextMuted")
				actionButton(row, "ACCEPT", "JOINING…", "AcceptInvite", {Id = invitation.Id}, 594, 14, 186, 44, true, party.Id ~= nil and party.Id ~= false)
				crewTop += 84
			end
		end
		if party.MergedCrew and not party.RunId then
			label(content, crewReady(party) and "Your crew is ready. The leader can now press Start Expedition." or "Everyone readies again. Your chosen leader then presses Start Expedition.", 0, crewTop - 8, 796, 40, 16, "TextMuted").TextWrapped = true
			crewTop += 44
		end
		local selfMember
		for index = 1, 6 do
			local member = (party.Members or {})[index]
			if member then
				local card = Instance.new("ImageButton"); card.Name = "Crew" .. index; card.Image = ""
				card.Position = UDim2.fromOffset(((index - 1) % 2) * 404, crewTop + math.floor((index - 1) / 2) * 104)
				card.Size = UDim2.fromOffset(392, 92); card.Parent = content; Theme.Button(card, false)
				portrait(card, member.UserId, 14, 14, 64)
				label(card, (member.DisplayName or member.Name or "Explorer") .. (member.UserId == party.LeaderId and "  /  LEADER" or ""), 92, 16, 284, 29, 18, "Text", true)
				local detail = label(card, (member.Role or "Generalist") .. "  ·  " .. readiness(member), 92, 51, 284, 25, 16, member.Online and member.Ready and "Success" or "TextMuted")
				detail.Name = "Readiness"
				card.Activated:Connect(function() selectedMemberId = member.UserId; memberMessage = nil; render() end)
				if member.UserId == player.UserId then selfMember = member end
			else
				local card = button(content, "", ((index - 1) % 2) * 404, crewTop + math.floor((index - 1) / 2) * 104, 392, 92, openPicker)
				card.Name = "Crew" .. index
				label(card, "+  OPEN CREW SLOT", 16, 17, 360, 28, 17, "TextMuted", true)
				label(card, "Browse players to invite", 16, 51, 360, 25, 15, "TextMuted")
			end
		end
		local y = crewTop + 332
		if not party.Id then actionButton(content, "CREATE PARTY", "CREATING…", "CreateParty", nil, 0, y, 250, 46, true)
		else
			if not party.RunId then actionButton(content, selfMember and selfMember.Ready and "NOT READY" or "READY UP", "UPDATING…", "Ready", {Ready = not (selfMember and selfMember.Ready)}, 0, y, 190, 46, true) end
			actionButton(content, "LEAVE PARTY", "LEAVING…", "LeaveParty", nil, 202, y, 190, 46)
			if party.LeaderId == player.UserId and Mode == "Lobby" and not party.RunId then
				local starting = startingExpedition(party)
				actionButton(content, starting and "STARTING EXPEDITION…" or "START EXPEDITION", "STARTING…", "StartExpedition", nil, 404, y, 392, 46, true, party.Queue ~= nil and party.Queue ~= false)
			end
			if party.LeaderId == player.UserId and not party.RunId then
				y += 60
				local inviteButton = button(content, "+  INVITE EXPLORERS", 0, y, 392, 46, openPicker)
				inviteButton.Interactable = not party.Queue and #(party.Members or {}) < 6
				if Mode == "Lobby" then
					local starting = startingExpedition(party)
					actionButton(content, party.Queue and (starting and "CANCEL START" or "CANCEL MATCHMAKING") or "MATCHMAKE · FILL CREW", party.Queue and "CANCELLING…" or "JOINING QUEUE…", party.Queue and "CancelQueue" or "Queue", nil, 404, y, 392, 46, false, not party.Queue and #(party.Members or {}) >= 6)
				end
				y += 52
				label(content, "Matchmaking joins parties and randomly picks an existing leader. Everyone readies again; that leader starts the expedition.", 0, y, 796, 42, 14, "TextMuted").TextWrapped = true
			end
		end
		y += 62
		if Mode == "Expedition" then actionButton(content, "RETURN TO OBSERVATORY", "RETURNING…", "ReturnLobby", nil, 0, y, 796, 46, true); y += 62 end
		if snapshot.Rejoin and snapshot.Rejoin.Available then actionButton(content, "REJOIN ACTIVE EXPEDITION", "REJOINING…", "Rejoin", nil, 0, y, 796, 46, true); y += 62 end
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
	renderMemberMenu(); applyControls()
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
	elseif request.Action == "KickMember" and party.Id == request.PartyId then
		for index, member in ipairs(party.Members or {}) do if member.UserId == request.Data.UserId then table.remove(party.Members, index); break end end
		for _, member in ipairs(party.Members or {}) do member.Ready = false end
		if selectedMemberId == request.Data.UserId then selectedMemberId = nil end
	elseif request.Action == "TransferLeader" and party.Id == request.PartyId then
		party.LeaderId = request.Data.UserId; selectedMemberId = nil
		for _, member in ipairs(party.Members or {}) do member.Ready = false end
	elseif request.Action == "BuyClass" then
		for _, class in ipairs(snapshot.Classes or {}) do if class.Id == request.Data.Id then class.Owned = true end end
	elseif request.Action == "Invite" then inviteStatus[request.Data.UserId] = "Invite sent"; inviteExpiry[request.Data.UserId] = os.clock() + 15
	elseif request.Action == "AcceptInvite" then
		local kept = {}; for _, invitation in ipairs(liveInvitations()) do if invitation.Id ~= request.Data.Id then table.insert(kept, invitation) end end
		snapshot.Invites = kept
		if activeInvitation and activeInvitation.Id == request.Data.Id then closeInvitePopup() end
		refresh("Invites")
	elseif request.Action == "RenameWorld" then submittedNames[request.Data.Id] = request.Data.Name end
end
remote.OnClientEvent:Connect(function(action, data)
	if type(data) ~= "table" then return end
	local incoming = tonumber(data.StateRevision) or 0
	if action == "Snapshot" then
		local section = data.Section or "Core"
		local inboxRead = inboxReads[data.RequestId]
		local olderInbox = section == "Invites" and inboxRead and inboxRead.Epoch < inboxEpoch
		if section == "Invites" and data.RequestId then inboxReads[data.RequestId] = nil end
		if incoming < revision or (tonumber(data.SnapshotId) or 0) <= (sectionIds[section] or -1) then return end
		revision = incoming; sectionIds[section] = tonumber(data.SnapshotId) or 0
		if section == "Archive" then
			for id, name in pairs(submittedNames) do
				if nameDrafts[id] == name then nameDrafts[id] = nil end
				submittedNames[id] = nil
			end
		end
		for key, value in pairs(data) do
			if key ~= "StateRevision" and key ~= "SnapshotId" and key ~= "RequestId" and key ~= "Section" and key ~= "Partial" and key ~= "ServerTime"
				and not (key == "Invites" and (data.InvitesAvailable == false or olderInbox)) then snapshot[key] = value end
		end
		if not UIS:GetFocusedTextBox() and visualKey() ~= lastVisual then render() end
		updateQueue()
		updateInvitePopup()
	elseif action == "Invitation" then
		-- This event is emitted only after a confirmed inbox write. Show it now;
		-- an older in-flight read must not erase it while the refresh catches up.
		if type(data.Id) == "string" and type(data.PartyId) == "string" and type(data.From) == "string"
			and type(data.ExpiresAt) == "number" and data.ExpiresAt > workspace:GetServerTimeNow() then
			inboxEpoch += 1
			local inbox = {}
			for _, invitation in ipairs(liveInvitations()) do
				if invitation.Id ~= data.Id and invitation.PartyId ~= data.PartyId then table.insert(inbox, invitation) end
			end
			table.insert(inbox, data); snapshot.Invites = inbox
			updateInvitePopup()
			if panel.Visible and not UIS:GetFocusedTextBox() and visualKey() ~= lastVisual then render() end
		end
		refresh("Invites")
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
		if completed.Action == "AcceptInvite" and not data.Success and activeInvitation
			and activeInvitation.Id == completed.Data.Id then popupMessage = message end
		if not UIS:GetFocusedTextBox() then render() else applyControls() end
		updateInvitePopup()
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
	if not processed and input.KeyCode == Enum.KeyCode.Escape and selectedMemberId then selectedMemberId = nil; render(); return end
	if not processed and input.KeyCode == Enum.KeyCode.F2 then panel.Visible = not panel.Visible; if panel.Visible then refresh("All") end end
end)
player:GetAttributeChangedSignal("LobbyPanelVersion"):Connect(function()
	page = player:GetAttribute("LobbyPanel") or "Party"; panel.Visible = true; render(); refresh("All")
end)
for _, event in ipairs({Players.PlayerAdded, Players.PlayerRemoving}) do event:Connect(function() task.defer(function() if page == "Invite" then render() end end) end) end
render(); refresh("All"); if Mode == "Lobby" then refresh("Invites") end
task.spawn(function()
	local tick = 0
	while gui.Parent do
		task.wait(1); tick += 1; updateQueue(); updateInvitePopup()
		for id, expiresAt in pairs(seenInvitations) do if expiresAt <= workspace:GetServerTimeNow() then seenInvitations[id] = nil end end
		for id, read in pairs(inboxReads) do if os.clock() - read.At > 120 then inboxReads[id] = nil end end
		if Mode == "Lobby" and tick % 3 == 0 then refresh("Invites") end
		if page == "Party" and panel.Visible and not UIS:GetFocusedTextBox() and visualKey() ~= lastVisual then render() end
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
