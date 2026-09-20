-- Runs before StarterPlayerScripts. This screen spans lobby departure, Roblox's
-- teleport handoff, server generation, and this client's arrival streaming.
local Players = game:GetService("Players")
local RF = game:GetService("ReplicatedFirst")
local RS = game:GetService("ReplicatedStorage")
local Teleport = game:GetService("TeleportService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local View = require(script.Parent:WaitForChild("ExpeditionLoadingView"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screen, template, mode, config
local initialDone, finishing, streamStarted, streamDone = false, false, false, false
local travelDismissed, reducedMotion = false, false
local ACTION = "ExpeditionLoadingMovement"

local function preferences()
	local raw = player:GetAttribute("PersonalSettings")
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "{}")
	reducedMotion = ok and type(decoded) == "table" and decoded.ReducedMotion == true
	if screen then screen.ReducedMotion = reducedMotion end
end
player:GetAttributeChangedSignal("PersonalSettings"):Connect(preferences)
preferences()

local function holdInput(held)
	playerGui:SetAttribute("ExpeditionLoading", held or nil)
	if held then
		ContextActionService:BindActionAtPriority(ACTION, function() return Enum.ContextActionResult.Sink end, false,
			Enum.ContextActionPriority.High.Value + 100, table.unpack(Enum.PlayerActions:GetEnumItems()))
	else
		ContextActionService:UnbindAction(ACTION)
	end
end

local function show()
	if screen then return screen end
	screen = View.Create(playerGui)
	screen.ReducedMotion = reducedMotion
	screen:Animate()
	holdInput(true)
	return screen
end

local function hide()
	if screen then screen:Destroy(); screen = nil end
	holdInput(false)
end

-- Cover arrival before removing either native screen. The destination owns a
-- fresh controller because scripts/animations do not run during teleport transit.
local arriving
pcall(function() arriving = Teleport:GetArrivingTeleportGui() end)
if RS:GetAttribute("PlaceMode") ~= "Lobby" then
	show():SetProgress(0, "Receiving expedition signal", 0, "Connecting your explorer")
	RF:RemoveDefaultLoadingScreen()
end
if arriving then arriving:Destroy() end

local function departure()
	if mode ~= "Lobby" then return end
	local state = player:GetAttribute("ExpeditionTravelState")
	if not state then
		travelDismissed = false
		hide()
		return
	end
	if travelDismissed then return end
	local view = show()
	if template and workspace.CurrentCamera then template:SetViewportSize(workspace.CurrentCamera.ViewportSize) end
	view.Signal.Text = "EXPEDITION  /  CROSSING THE SHIFT"
	view.Heading.Text = "BEYOND THE\nFAMILIAR"
	view:SetProgress(nil, "World signal arrives after teleport", nil, state == "Retrying" and "Travel interrupted; reconnecting" or "Transferring your explorer")
	view.Footer.Text = state == "Retrying" and "SIGNAL LOST   Travel will retry automatically. Your crew is preserved." or "FIELD NOTE   Your expedition is on the other side. Stay with your crew."
	view:SetDismiss(state == "Retrying", function()
		travelDismissed = true
		hide()
	end)
end

player:GetAttributeChangedSignal("ExpeditionTravelState"):Connect(departure)
player.OnTeleport:Connect(function(state, placeId)
	if not config or placeId ~= config.ExpeditionPlaceId then return end
	if state == Enum.TeleportState.Failed then
		if screen then
			screen.Footer.Text = "SIGNAL LOST   Travel will retry automatically. Your crew is preserved."
			screen:SetDismiss(true, function() travelDismissed = true; hide() end)
		end
	elseif state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress or state == Enum.TeleportState.WaitingForServer then
		travelDismissed = false
		local view = show()
		view.Signal.Text = "EXPEDITION  /  CROSSING THE SHIFT"
		view.Heading.Text = "BEYOND THE\nFAMILIAR"
		view:SetDismiss(false)
		view:SetProgress(nil, "Contacting your expedition", nil, "Travelling with your crew")
	end
end)

task.spawn(function()
	config = require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig"))
	mode = config.GetMode()
	if mode == "Lobby" then
		initialDone = true
		hide()
		-- Register well before TeleportAsync. The template has no LocalScripts,
		-- external images, or camera references outside its own ViewportFrame.
		template = View.Create(nil)
		template.Signal.Text = "EXPEDITION  /  CROSSING THE SHIFT"
		template.Heading.Text = "BEYOND THE\nFAMILIAR"
		template:SetProgress(nil, "Contacting your expedition", nil, "Travelling with your crew")
		template.Footer.Text = "FIELD NOTE   Your expedition is on the other side. Stay with your crew."
		-- An unparented template needs a usable scale before Roblox mounts it.
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		template:SetViewportSize(size)
		pcall(function() Teleport:SetTeleportGui(template.Gui) end)
		departure()
	end
end)

local notes = {
	"FIELD NOTE   A torch lights the trail, but offers no heat protection.",
	"FIELD NOTE   Keep supplies close. Your next biome may demand different gear.",
	"FIELD NOTE   The camp is only the beginning. Distant terrain unfolds as you explore.",
	"FIELD NOTE   A standing lamp casts a wider light across your camp.",
}

task.spawn(function()
	while not initialDone do
		local view = show()
		local worldProgress = RS:GetAttribute("WorldLoadProgress") or 0
		local worldStage = RS:GetAttribute("WorldLoadStage") or "Receiving expedition signal"
		local boot = RS:GetAttribute("ServerBootState")
		local ready = player:GetAttribute("WorldPlayerReady") == true
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hasView = workspace.CurrentCamera ~= nil and (root ~= nil or player:GetAttribute("IsDead") == true)
		if ready and game:IsLoaded() and hasView and not streamStarted then
			streamStarted = true
			task.spawn(function()
				-- Only preload the arrival area; the world deliberately streams the
				-- rest during exploration. The server already secured collision here.
				if workspace.StreamingEnabled and root then
					pcall(function() player:RequestStreamAroundAsync(root.Position, 8) end)
				end
				streamDone = true
			end)
		end
		local playerProgress = (player:GetAttribute("PlayerLoadProgress") or 0) * .9
		if game:IsLoaded() then playerProgress += .03 end
		if hasView then playerProgress += .02 end
		if streamDone then playerProgress += .05 end
		local playerStage = player:GetAttribute("PlayerLoadStage") or "Opening your field record"
		if ready then
			if not game:IsLoaded() then playerStage = "Receiving world data"
			elseif not hasView then playerStage = "Preparing your view of the world"
			elseif not streamDone then playerStage = "Streaming your surroundings"
			else playerStage = "Explorer ready" end
		end
		if worldStage == "Waiting for your original crew" then
			worldStage = string.format("Gathering crew: %d / %d arrived", #Players:GetPlayers(), RS:GetAttribute("OriginalCrewSize") or #Players:GetPlayers())
		end
		view:SetProgress(worldProgress, worldStage, playerProgress, playerStage)
		local elapsed = os.clock() - view.StartedAt
		view.Footer.Text = notes[math.floor(elapsed / 9) % #notes + 1]
		if elapsed > 45 then view.Footer.Text = "STILL PREPARING   Large worlds and saved explorers can take a little longer." end
		if ready and streamDone and boot == "LoadingCrew" then view.Footer.Text = "CREW CHECK   You are ready. The remaining explorers are preparing to arrive." end
		if boot == "Failed" or player:GetAttribute("PlayerLoadFailed") then
			view:Error("ARRIVAL INTERRUPTED   Please leave and rejoin your expedition from the lobby.")
		elseif mode == "Expedition" and boot == "Ready" and worldProgress >= 1 and ready and streamDone and hasView
			and not RS:GetAttribute("WorldRestoring") and not RS:GetAttribute("WorldShifting")
			and not player:GetAttribute("WorldPlayerLoading") and not player:GetAttribute("WorldPlayerRestoring") then
			initialDone, finishing = true, true
			view:Finish(reducedMotion)
			if screen == view then screen = nil end
			finishing = false
			holdInput(false)
			break
		end
		task.wait(.1)
	end
end)

script.Destroying:Connect(function()
	if not finishing then hide() end
	if template then template:Destroy() end
end)
