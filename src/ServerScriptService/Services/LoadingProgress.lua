-- Public presentation milestones only; never publish reservation or save data.
local RS = game:GetService("ReplicatedStorage")
local Progress = {}

function Progress.World(fraction, stage)
	RS:SetAttribute("WorldLoadProgress", math.max(RS:GetAttribute("WorldLoadProgress") or 0, math.clamp(fraction, 0, 1)))
	RS:SetAttribute("WorldLoadStage", stage)
end

local stages = {
	CharacterLoad1 = { .2, "Assembling your explorer" },
	CharacterLoad2 = { .2, "Retrying explorer appearance" },
	CharacterLoad3 = { .2, "Retrying explorer appearance" },
	SavedState = { .3, "Unpacking expedition records" },
	Role = { .32, "Preparing your class" }, Stats = { .38, "Restoring your vitals" },
	Inventory = { .44, "Unpacking your field kit" }, Position = { .52, "Finding your arrival point" },
	CraftRefund = { .6, "Recovering crafting supplies" }, ClassAbility = { .64, "Preparing class abilities" },
	StarterInventory = { .44, "Packing your starter supplies" },
	CreativeState = { .68, "Preparing your equipment" }, FoodEffects = { .72, "Restoring provisions" },
	GearEffects = { .76, "Checking your gear" }, DeathState = { .8, "Restoring explorer condition" },
	StreamingPosition = { .85, "Loading the ground beneath you" },
	Checkpoint = { .94, "Recording your arrival" }, GameState = { .97, "Synchronizing expedition status" },
}

function Progress.BindPlayer(player)
	if player:GetAttribute("PlayerLoadProgress") ~= nil then return end
	player:SetAttribute("WorldPlayerReady", false)
	player:SetAttribute("PlayerLoadProgress", 0)
	local function update()
		if player:GetAttribute("WorldPlayerReady") then return end
		local stage = stages[player:GetAttribute("WorldRestoreStage")]
		local fraction = stage and stage[1] or (player:GetAttribute("ProfileLoaded") and .15 or .05)
		player:SetAttribute("PlayerLoadProgress", math.max(player:GetAttribute("PlayerLoadProgress") or 0, fraction))
		player:SetAttribute("PlayerLoadStage", stage and stage[2] or (player:GetAttribute("ProfileLoaded") and "Field record ready; awaiting world" or "Opening your field record"))
	end
	local stageConnection = player:GetAttributeChangedSignal("WorldRestoreStage"):Connect(update)
	local profileConnection = player:GetAttributeChangedSignal("ProfileLoaded"):Connect(update)
	local readyConnection
	readyConnection = player:GetAttributeChangedSignal("WorldPlayerReady"):Connect(function()
		if not player:GetAttribute("WorldPlayerReady") then return end
		stageConnection:Disconnect(); profileConnection:Disconnect(); readyConnection:Disconnect()
	end)
	update()
end

function Progress.PlayerReady(player)
	player:SetAttribute("PlayerLoadProgress", 1)
	player:SetAttribute("PlayerLoadStage", "Explorer ready")
	player:SetAttribute("WorldPlayerReady", true)
end

return Progress
