-- Shared ownership keeps the cursor free until the last interactive menu closes.
-- Bind any menu's visible root through Theme.CaptureCursor; this module handles
-- nested menus and restores normal camera ownership after the final one closes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local MenuCursor = {}
local roots = setmetatable({}, { __mode = "k" })
local started, open, previousIcon = false, false, true

local function isVisible(root, playerGui)
	local node = root
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") and not node.Enabled then return false end
		node = node.Parent
	end
	return node == playerGui
end

function MenuCursor.Bind(root)
	if not RunService:IsClient() then return end
	assert(typeof(root) == "Instance", "MenuCursor.Bind expects a UI instance")
	roots[root] = true
	if started then return root end
	started = true
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuCursorUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -100
	gui.Parent = playerGui
	local modal = Instance.new("TextButton")
	modal.Name = "CursorRelease"
	modal.Size = UDim2.fromOffset(1, 1)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	-- Roblox's camera controller only honors Modal while its GuiButton is active.
	-- This suspends shift lock without placing a click-blocking surface over menus.
	modal.Active = true
	modal.Selectable = false
	modal.Modal = true
	modal.Visible = false
	modal.Parent = gui
	playerGui:SetAttribute("MenuCursorOpen", false)
	RunService:BindToRenderStep("EcoShiftMenuVisibility", Enum.RenderPriority.Camera.Value - 1, function()
		local visible = false
		for frame in pairs(roots) do
			if isVisible(frame, playerGui) then visible = true; break end
		end
		if visible ~= open then
			open = visible
			modal.Visible = open
			if open then previousIcon = UIS.MouseIconEnabled else UIS.MouseIconEnabled = previousIcon end
			playerGui:SetAttribute("MenuCursorOpen", open)
		end
	end)
	-- Run after the stock camera and mouse-lock controller. Camera.Value + 1 is
	-- early enough for another camera callback to recapture the pointer.
	RunService:BindToRenderStep("EcoShiftMenuCursor", Enum.RenderPriority.Last.Value, function()
		if open then
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end
		-- On close, the stock camera restores its current mode/lock next frame.
	end)
	return root
end

return MenuCursor
