-- Server-only, transient hints for the live queue. Never serialize these records
-- into DataStores, party membership, resume tickets, teleport data or client UI.
-- https://create.roblox.com/docs/reference/engine/classes/TextChatService#GetChatGroupsAsync
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Policy = require(ReplicatedStorage.Shared.MatchmakingPolicy)
assert(RunService:IsServer(), "RobloxMatchmakingSignals is server-only")

local Signals = {}
local cache = {}
local invalidated = Instance.new("BindableEvent")
Signals.Invalidated = invalidated.Event
Signals.ConfigurationHint = "Chat groups require Chat & Voice Groups APIs in Experience Settings > Communication. The owner must opt in and accept Roblox's terms. Studio requires Team Test."
local CACHE_SECONDS, RETRY_SECONDS = 25, 10

local function localPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

function Signals.MatchmakingType()
	local ok, value = pcall(function() return game.MatchmakingType.Name end)
	return ok and Policy.IsMatchmakingType(value) and value or "Unknown"
end

local function locale(player)
	local ok, value = pcall(function() return player.LocaleId end)
	if not ok or type(value) ~= "string" or #value > 32 then return nil, nil end
	value = string.lower(value):gsub("_", "-")
	if not value:match("^[a-z][a-z][a-z]?[%w%-]*$") then return nil, nil end
	local language = value:match("^([a-z]+)")
	if not language or #language < 2 or #language > 3 then return nil, nil end
	-- An account language setting is a preference, not a claim about location.
	return value, language
end

local function groupsFromResponse(response)
	if type(response) ~= "table" then return nil end
	local groups, seen = {}, {}
	-- Query one local Player at a time, so every returned group belongs to that
	-- player. Do not assume the API's sorted outer array preserves input order.
	for _, list in pairs(response) do
		if type(list) ~= "table" then return nil end
		for _, id in pairs(list) do
			if type(id) ~= "string" or #id == 0 or #id > 256 then return nil end
			if not seen[id] then
				if #groups >= Policy.MaxChatGroups then return nil end
				seen[id] = true
				table.insert(groups, id)
			end
		end
	end
	table.sort(groups)
	return groups
end

-- Yields only when the short local cache needs refreshing. Failures, missing
-- opt-in and unsupported Studio sessions remain Unknown; no inferred fallback.
function Signals.Capture(player)
	if not localPlayer(player) then return nil, "PlayerNotLocal" end
	local now = os.time()
	local chat = cache[player]
	if not chat or (not chat.Pending and now >= chat.RefreshAt) then
		chat = { Pending = true, Status = "Unknown", Reason = "CapturePending", Groups = {}, CapturedAt = now, RefreshAt = now + RETRY_SECONDS }
		cache[player] = chat
		local ok, response = pcall(function() return TextChatService:GetChatGroupsAsync({ player }) end)
		if not localPlayer(player) or cache[player] ~= chat then return nil, "PlayerLeft" end
		local groups = ok and groupsFromResponse(response) or nil
		chat.Pending = false
		chat.CapturedAt = os.time()
		chat.Status = groups and "Known" or "Unknown"
		if groups then chat.Reason = nil
		else chat.Reason = ok and "UnsupportedResponse" or "ChatGroupsUnavailable" end
		chat.Groups = groups or {}
		chat.RefreshAt = chat.CapturedAt + (groups and CACHE_SECONDS or RETRY_SECONDS)
	end
	if not localPlayer(player) then return nil, "PlayerLeft" end
	now = os.time()
	local localeId, language = locale(player)
	local role = player:GetAttribute("Role")
	if type(role) ~= "string" or not Config.ROLES.Definitions[role] then role = nil end
	return {
		Version = 1, UserId = player.UserId, UniverseId = game.GameId,
		Class = role, LocaleId = localeId, Language = language,
		MatchmakingType = Signals.MatchmakingType(), CapturedAt = now,
		ExpiresAt = now + Policy.SignalMaxAgeSeconds,
		ChatStatus = chat.Pending and "Unknown" or chat.Status,
		ChatReason = chat.Reason, ChatCapturedAt = chat.CapturedAt,
		ChatExpiresAt = chat.CapturedAt + Policy.SignalMaxAgeSeconds,
		ChatGroups = chat.Pending and {} or table.clone(chat.Groups),
	}
end

function Signals.Forget(player)
	local chat = cache[player]
	if chat then
		table.clear(chat.Groups)
		cache[player] = nil
	end
	-- The queue owner must remove any exported MemoryStore hints immediately,
	-- including on teleport. Crashed-server records also need a short TTL.
	invalidated:Fire(player.UserId)
end

Players.PlayerRemoving:Connect(Signals.Forget)
return Signals
