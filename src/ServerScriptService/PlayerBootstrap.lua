-- PlayerBootstrap.server.lua
-- Sets baseline Attributes and starter items. No instance creation beyond Attributes.
local Players = game:GetService("Players")

local function initAttrs(char)
	-- basic resist defaults (0..0.5 typical)
	char:SetAttribute("Res_Heat", 0)
	char:SetAttribute("Res_Cold", 0)
	char:SetAttribute("Res_Toxin", 0)
	char:SetAttribute("Res_Wet", 0)
	char:SetAttribute("WetStacks", 0)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		task.defer(initAttrs, char)
	end)
end)
