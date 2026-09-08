-- Shared ownership keeps the cursor free until the last interactive menu closes.
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
	roots[root] = true
	if started then return end
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
	modal.Active = false
	modal.Selectable = false
	modal.Modal = true
	modal.Visible = false
	modal.Parent = gui
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
	RunService:BindToRenderStep("EcoShiftMenuCursor", Enum.RenderPriority.Camera.Value + 1, function()
		if open then
			-- Modal also tells the stock camera to suspend first-person rotation.
			-- Override after the camera so holding RMB cannot recapture the cursor.
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end
		-- On close, the stock camera restores its current mode/lock next frame.
	end)
end

return MenuCursor
