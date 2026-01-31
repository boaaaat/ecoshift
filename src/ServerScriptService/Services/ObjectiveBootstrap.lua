-- ObjectiveBootstrap.lua
-- Bridges objective anchors you placed in Workspace/Objectives with ObjectiveService logic.
-- It doesn't create anything; you should wire your triggers to call the Interact remote with Action="ObjectiveProgress"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ObjectiveService = require(script.Parent.Parent.Services.ObjectiveService)

local ObjectiveBootstrap = {}

function ObjectiveBootstrap:Init()
	-- This module doesn't need to do anything unless you want to auto-map anchors to IDs.
	-- Example (optional): read anchors and set a readable Attribute you can use on client UI.
	local folder = Util.WaitForDescendant(Config.Paths.ObjectivesFolder, 3)
	if not folder then return end
	for _, anchor in ipairs(folder:GetChildren()) do
		if not anchor:GetAttribute("ObjectiveId") then
			-- don't set one automatically; leave to designers to choose. We keep it pure.
			-- You can name your parts exactly the objective id and set this attribute yourself in Studio.
		end
	end
end

return ObjectiveBootstrap
