-- Shared place routing and tunable session policy. Never put reserved-server codes here.
local Config = {
	UniverseId = 8439909753,
	LobbyPlaceId = 94125768885713,
	ExpeditionPlaceId = 120274921310527,
	MaxPartySize = 6,
	Namespace = "EcoshiftSessions_v1",
	PartyTTL = 86400,
	PresenceTTL = 75,
	HeartbeatSeconds = 15,
	TransferSeconds = 120,
	InviteSeconds = 120,
	QueueWaitSeconds = 60,
}

function Config.GetMode()
	local override = game:GetService("ReplicatedStorage"):GetAttribute("PlaceMode")
	if override == "Lobby" or override == "Expedition" then return override end
	return game.PlaceId == Config.LobbyPlaceId and "Lobby" or "Expedition"
end

return Config
