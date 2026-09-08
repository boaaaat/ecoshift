local RS=game:GetService("ReplicatedStorage")
local Bootstrap={}
function Bootstrap:Init()
	RS:SetAttribute("PlaceMode","Lobby")
	local S=script.Parent.Services
	require(S.LobbyWorldService):Init()
	require(S.ProfileService):Init()
	require(S.RoleService):Init()
	require(S.PartyService):Init()
	require(S.WorldSaveService):Init()
	require(S.WorldSessionService):Init()
	require(S.MatchmakingService):Init()
	require(S.LobbyService):Init()
end
return Bootstrap
