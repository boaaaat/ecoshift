local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClientSettings"))
if require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode() ~= "Expedition" then return end
-- Expedition instruments and team ballots. Secret forecasts arrive personalized.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("UI"):WaitForChild("UITheme"))
local ControlConfig = require(Shared:WaitForChild("WorldControlConfig"))
local ItemDatabase = require(Shared.Items.ItemDatabase)
local BiomeConfig = require(Shared.BiomeConfig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:WaitForChild("WorldControl", 30)
if not remote then warn("[WorldControlUI] WorldControl remote unavailable") return end
local gameStateRemote = Remotes:WaitForChild("GameStateUpdate")
local C = Theme.Colors
local snapshot, world = {}, {}
local selectedBiome, lastBallotId

local function biomeName(id)
	local def = id and BiomeConfig.BIOMES[id]
	return def and def.DisplayName or id or "Unknown"
end
local function itemName(id)
	local item = ItemDatabase:Get(id)
	return item and item.Name or id
end
local function label(parent, text, x, y, width, height, size, color, bold)
	return Theme.Label(parent, text, UDim2.fromOffset(width, height), UDim2.fromOffset(x, y), size, color or C.Paper, bold)
end
local function button(parent, text, x, y, width, height, primary)
	local result = Instance.new("TextButton")
	result.Text, result.Font, result.TextSize = text, Enum.Font.GothamBold, 13
	result.Size, result.Position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
	result.Parent = parent
	Theme.Button(result, primary)
	return result
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "WorldControlUI", false, 85
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "SurveyInstrument"
panel.Size = UDim2.fromOffset(600, 600)
panel.Position, panel.AnchorPoint = UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
panel.Visible, panel.Parent = false, gui
Theme.Panel(panel, true)
Theme.Fit(panel, 600, 600)
Theme.CaptureCursor(panel); Theme.AnimatePanel(panel)
label(panel, "ECOSHIFT  /  SURVEY INSTRUMENTS", 24, 14, 470, 18, 10, C.Amber, true)
label(panel, "Read the world. Shape the next shift.", 24, 36, 510, 28, 22, C.Paper, true)
local close = button(panel, "×", 546, 18, 30, 30, false)
close.Name = "CloseButton"
close.Activated:Connect(function() panel.Visible = false end)

local intel = Instance.new("Frame")
intel.Name = "Instruments"
intel.Size, intel.Position = UDim2.fromOffset(552, 84), UDim2.fromOffset(24, 78)
intel.Parent = panel
Theme.Panel(intel, false)
local instrumentLabels = {}
for index, title in ipairs({ "SHIFT CLOCK", "BIOME FORECAST", "WEATHER FORECAST" }) do
	local x = 12 + (index - 1) * 182
	label(intel, title, x, 10, 168, 18, 10, C.TextMuted, true)
	instrumentLabels[index] = label(intel, "No instrument", x, 30, 168, 40, 13, C.Text, true)
	instrumentLabels[index].TextWrapped = true
end

local cards = {}
for index, action in ipairs(ControlConfig.Order) do
	local def = ControlConfig.Actions[action]
	local card = Instance.new("Frame")
	card.Name = action
	card.Size, card.Position = UDim2.fromOffset(552, 116), UDim2.fromOffset(24, 176 + (index - 1) * 128)
	card.Parent = panel
	Theme.Panel(card, false)
	label(card, string.format("0%d  /  %s", index, string.upper(def.Name)), 14, 10, 385, 22, 13, C.Text, true)
	local ownership = label(card, "NOT CRAFTED", 397, 12, 142, 18, 10, C.TextMuted, true)
	ownership.TextXAlignment = Enum.TextXAlignment.Right
	local description = label(card, def.Description, 14, 33, 520, 20, 11, C.TextMuted)
	local fuel = label(card, "Checking fuel...", 14, 58, 370, 18, 11, C.Text)
	local reason = label(card, "", 14, 80, 355, 22, 10, C.TextMuted)
	local propose = button(card, "PROPOSE VOTE", 390, 72, 146, 30, true)
	propose.Name = "ProposeButton"
	propose.Activated:Connect(function()
		local state = snapshot.Actions and snapshot.Actions[action]
		if not state or not state.CanPropose then return end
		if action == "Select" and not selectedBiome then return end
		remote:FireServer("Propose", { Action = action, Biome = action == "Select" and selectedBiome or nil })
	end)
	cards[action] = { Ownership = ownership, Description = description, Fuel = fuel, Reason = reason, Propose = propose }
end
local destination = button(cards.Select.Description.Parent, "CHOOSE BIOME  ›", 14, 78, 220, 26, false)
destination.Name = "BiomeButton"
cards.Select.Reason.Visible = false
label(panel, "ESC  CLOSE   ·   Reusable devices. Fuel is spent only after team approval.", 24, 565, 552, 22, 10, C.Sage)

-- A separate surface keeps ballots available to spectators over the death screen.
local voteGui = Instance.new("ScreenGui")
voteGui.Name, voteGui.ResetOnSpawn, voteGui.DisplayOrder = "WorldControlBallots", false, 105
voteGui.Parent = player.PlayerGui
local ballotPanel = Instance.new("Frame")
ballotPanel.Name, ballotPanel.Size = "TeamBallot", UDim2.fromOffset(450, 166)
ballotPanel.Position, ballotPanel.AnchorPoint = UDim2.new(0.5, 0, 1, -26), Vector2.new(0.5, 1)
ballotPanel.Visible, ballotPanel.Parent = false, voteGui
Theme.Panel(ballotPanel, true)
Theme.Fit(ballotPanel, 450, 166)
Theme.CaptureCursor(ballotPanel); Theme.AnimatePanel(ballotPanel)
label(ballotPanel, "TEAM DECISION", 18, 10, 410, 18, 10, C.Amber, true)
local ballotTitle = label(ballotPanel, "World control proposal", 18, 31, 414, 25, 18, C.Paper, true)
local ballotDetail = label(ballotPanel, "", 18, 60, 414, 20, 12, C.Sage)
local ballotCount = label(ballotPanel, "", 18, 84, 414, 19, 12, C.Paper)
local yes = button(ballotPanel, "APPROVE", 18, 116, 198, 32, true)
local no = button(ballotPanel, "DECLINE", 234, 116, 198, 32, false)
yes.Name, no.Name = "ApproveButton", "DeclineButton"
local function vote(approve)
	local ballot = snapshot.Ballot
	if ballot and ballot.CanVote then remote:FireServer("Vote", { Id = ballot.Id, Approve = approve }) end
end
yes.Activated:Connect(function() vote(true) end)
no.Activated:Connect(function() vote(false) end)

local notice = Instance.new("Frame")
notice.Name, notice.Size = "WorldNotice", UDim2.fromOffset(480, 66)
notice.Position, notice.AnchorPoint = UDim2.new(0.5, 0, 0, 80), Vector2.new(0.5, 0)
notice.Visible, notice.Parent = false, voteGui
Theme.Panel(notice, true)
Theme.Fit(notice, 480, 66)
local noticeLabel = label(notice, "", 18, 10, 444, 46, 14, C.Paper, true)
noticeLabel.TextWrapped = true
local noticeSerial = 0
local function feedback(data)
	if type(data) ~= "table" then return end
	noticeSerial += 1
	local serial = noticeSerial
	noticeLabel.Text = data.Message or ""
	noticeLabel.TextColor3 = data.Success and C.Amber or C.Paper
	notice.Visible = true
	task.delay(5, function() if noticeSerial == serial then notice.Visible = false end end)
end

local function availableBiomes()
	local options = {}
	for _, id in ipairs(snapshot.EligibleBiomes or {}) do
		if id ~= world.Biome then table.insert(options, id) end
	end
	return options
end
local function render()
	if typeof(world.ShiftRemaining) == "number" then
		local remaining = math.max(0, math.ceil(world.ShiftRemaining))
		instrumentLabels[1].Text = string.format("%02d:%02d until shift", math.floor(remaining / 60), remaining % 60)
	else instrumentLabels[1].Text = "Craft a Field Clock" end
	instrumentLabels[2].Text = world.UpcomingBiome and biomeName(world.UpcomingBiome) or "Craft a Biome Predictor"
	instrumentLabels[3].Text = world.UpcomingWeather or "Craft a Weather Predictor"
	local options = availableBiomes()
	if not table.find(options, selectedBiome) then selectedBiome = options[1] end
	destination.Text = selectedBiome and (biomeName(selectedBiome) .. "  ›") or "No other biome unlocked"
	for action, card in pairs(cards) do
		local state = snapshot.Actions and snapshot.Actions[action]
		if state then
			card.Ownership.Text = state.Owned and "DEVICE READY" or "NOT CRAFTED"
			card.Ownership.TextColor3 = state.Owned and C.Success or C.TextMuted
			local parts = {}
			for _, cost in ipairs(state.Fuel or {}) do
				table.insert(parts, string.format("%s %d/%d", itemName(cost.Id), cost.Owned, cost.N))
			end
			card.Fuel.Text = "FUEL  " .. table.concat(parts, "  ·  ")
			card.Fuel.TextColor3 = state.HasFuel and C.Success or C.Warning
			card.Reason.Text = state.Reason or "Fuel supplied by the proposer."
			card.Propose.Active = state.CanPropose and (action ~= "Select" or selectedBiome ~= nil)
			card.Propose.TextTransparency = card.Propose.Active and 0 or 0.45
			if action == "Select" then card.Description.Text = state.Reason or ControlConfig.Actions.Select.Description end
		end
	end
	local ballot = snapshot.Ballot
	ballotPanel.Visible = ballot ~= nil and not snapshot.GameOver
	if ballot then
		local def = ControlConfig.Actions[ballot.Action]
		ballotTitle.Text = def.Name .. (ballot.Biome and (" → " .. biomeName(ballot.Biome)) or "")
		ballotDetail.Text = ballot.Proposer .. " supplies the fuel. Device is retained."
		ballotCount.Text = string.format("%d / %d approvals needed   ·   %d declined   ·   %ds left", ballot.Yes, ballot.Required, ballot.No, ballot.ExpiresIn)
		yes.Active, no.Active = ballot.CanVote, ballot.CanVote
		yes.TextTransparency, no.TextTransparency = ballot.CanVote and 0 or 0.4, ballot.CanVote and 0 or 0.4
		if ballot.Vote == true then yes.Text = "APPROVAL RECORDED"
		elseif ballot.Vote == false then yes.Text = "VOTE RECORDED"
		else yes.Text = ballot.CanVote and "APPROVE" or "NEXT BALLOT" end
		if lastBallotId ~= ballot.Id then
			lastBallotId = ballot.Id
			Theme.Tween(ballotPanel, { BackgroundTransparency = 0.04 }, 0.25)
		end
	end
end
destination.Activated:Connect(function()
	local options = availableBiomes()
	if #options == 0 then return end
	selectedBiome = options[((table.find(options, selectedBiome) or 0) % #options) + 1]
	render()
end)
local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then remote:FireServer("RequestSnapshot") end
end
player:GetAttributeChangedSignal("FieldKitSurvey"):Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if Settings.Matches(input, "Survey") then toggle()
	elseif Settings.CanInput() and input.KeyCode == Enum.KeyCode.Escape then panel.Visible = false end
end)
remote.OnClientEvent:Connect(function(action, data)
	if action == "Snapshot" and type(data) == "table" then
		snapshot = data
		render()
	elseif action == "Feedback" then feedback(data) end
end)
gameStateRemote.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		world = data
		render()
	end
end)
remote:FireServer("RequestSnapshot")
render()
