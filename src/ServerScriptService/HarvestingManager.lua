-- Location: ServerScriptService/HarvestingManager.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Load the InventoryService module
local InventoryService = require(ServerScriptService.Services.InventoryService)
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local giveResourceEvent = remotesFolder:WaitForChild("GiveResourceEvent", 5)

if not giveResourceEvent then
	warn("[HarvestingManager] Missing Remotes/GiveResourceEvent; harvest requests disabled.")
	return
end

print("[HarvestingManager] Ready and listening for harvest requests.")

-- This function runs every time any player clicks with the Harvester tool
giveResourceEvent.OnServerEvent:Connect(function(player, resourceType, amount)
	-- Basic server-side validation to prevent exploiting
	if type(resourceType) == "string" and type(amount) == "number" and amount > 0 then
		print(("[Server] Received harvest request from %s for %d %s"):format(player.Name, amount, resourceType))

		-- Tell the InventoryService to give the items.
		-- The InventoryService will then automatically update the player's UI.
		InventoryService:Give(player, resourceType, amount)
	end
end)
