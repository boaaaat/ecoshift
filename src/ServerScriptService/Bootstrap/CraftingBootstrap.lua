-- CraftingBootstrap.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftingService = require(script.Parent.Parent.Services.CraftingService)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
local rCraft = Util.GetRemote(remotesFolder, Config.RemoteNames.Craft)

if rCraft then
	rCraft.OnServerEvent:Connect(function(plr, itemId)
		local ok, reason = CraftingService:Craft(plr, itemId)
		if not ok then
			-- optionally fire a client toast through another remote you provide
		end
	end)
end
