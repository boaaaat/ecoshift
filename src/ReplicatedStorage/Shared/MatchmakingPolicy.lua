-- Pure selection policy; shared code contains no player signal records.
-- Call only on the server with live queue tickets. This is a preference scorer,
-- never a chat-permission check. Roblox still authorizes all communication.
local Policy = {
	TeamSize = 6,
	SignalMaxAgeSeconds = 60,
	MaxChatGroups = 64,
	MaxInputTickets = 100,
	MaxCandidateTickets = 20,
	MaxSearchStates = 40000,
	-- Optional future progression hint, populated only from authoritative server data.
	MaxLevel = 1000000,
	LevelWeight = 6,
}
local MATCHMAKING_TYPES = { Default = true, XboxOnly = true, PlayStationOnly = true }

function Policy.IsMatchmakingType(value)
	return type(value) == "string" and MATCHMAKING_TYPES[value] == true
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function fresh(capturedAt, expiresAt, now)
	return finite(capturedAt) and finite(expiresAt) and capturedAt <= now + 5
		and now - capturedAt <= Policy.SignalMaxAgeSeconds and expiresAt > now
		and expiresAt <= capturedAt + Policy.SignalMaxAgeSeconds
end
local function chatGroups(signal, now)
	if signal.ChatStatus ~= "Known" or not fresh(signal.ChatCapturedAt, signal.ChatExpiresAt, now)
		or type(signal.ChatGroups) ~= "table" then return nil end
	local result, count = {}, 0
	for _, value in pairs(signal.ChatGroups) do
		count += 1
		if count > Policy.MaxChatGroups or type(value) ~= "string" or #value == 0 or #value > 256 then return nil end
		result[value] = true
	end
	return result
end
local function prepare(ticket, now, matchmakingType)
	if type(ticket) ~= "table" or type(ticket.Id) ~= "string" or #ticket.Id == 0 or #ticket.Id > 128
		or not finite(ticket.QueuedAt) or ticket.QueuedAt > now + 5
		or not finite(ticket.ExpiresAt) or ticket.ExpiresAt <= now
		or ticket.MatchmakingType ~= matchmakingType or type(ticket.Members) ~= "table" then return nil end
	local result = { Ticket = ticket, Id = ticket.Id, QueuedAt = ticket.QueuedAt, Members = {}, UserIds = {} }
	for _, signal in pairs(ticket.Members) do
		if #result.Members >= Policy.TeamSize or type(signal) ~= "table"
			or not finite(signal.UserId) or signal.UserId % 1 ~= 0 or signal.UserId == 0
			or result.UserIds[signal.UserId] or signal.MatchmakingType ~= matchmakingType
			or not fresh(signal.CapturedAt, signal.ExpiresAt, now) then return nil end
		local class = type(signal.Class) == "string" and #signal.Class > 0 and #signal.Class <= 80 and signal.Class or nil
		local language = type(signal.Language) == "string" and signal.Language:match("^[a-z][a-z][a-z]?$") and signal.Language or nil
		result.UserIds[signal.UserId] = true
		local level = finite(signal.Level) and signal.Level % 1 == 0
			and signal.Level >= 1 and signal.Level <= Policy.MaxLevel and signal.Level or nil
		table.insert(result.Members, { Signal = signal, Class = class, Language = language, Level = level, Groups = chatGroups(signal, now) })
	end
	if #result.Members == 0 then return nil end
	table.sort(result.Members, function(a, b) return a.Signal.UserId < b.Signal.UserId end)
	return result
end
local function oldestFirst(a, b)
	if a.QueuedAt ~= b.QueuedAt then return a.QueuedAt < b.QueuedAt end
	return a.Id < b.Id
end

local function evaluate(parties, now)
	local members, classes, totalWait, oldestWait = {}, {}, 0, 0
	for _, party in ipairs(parties) do
		local wait = math.max(0, now - party.QueuedAt)
		oldestWait = math.max(oldestWait, wait)
		for _, member in ipairs(party.Members) do
			table.insert(members, member)
			totalWait += math.min(wait, 300)
			if member.Class then classes[member.Class] = true end
		end
	end
	local classCount, chatKnown, compatible, sameLanguage = 0, 0, 0, 0
	local levelKnownPairs, levelSimilarity, levelRelativeGap = 0, 0, 0
	for _ in pairs(classes) do classCount += 1 end
	for first = 1, #members - 1 do
		for second = first + 1, #members do
			local a, b = members[first], members[second]
			if a.Level and b.Level then
				local gap = math.abs(a.Level - b.Level) / math.max(a.Level, b.Level)
				levelKnownPairs += 1
				levelRelativeGap += gap
				levelSimilarity += 1 - gap
			end
			if a.Language and a.Language == b.Language then sameLanguage += 1 end
			if a.Groups and b.Groups then
				chatKnown += 1
				for id in pairs(a.Groups) do
					if b.Groups[id] then compatible += 1; break end
				end
			end
		end
	end
	local pairCount = Policy.TeamSize * (Policy.TeamSize - 1) / 2
	-- Early matching favors complementary roles, similar known levels and communication. As the oldest
	-- party waits, age of the other parties matters more, without changing size.
	local relaxation = math.clamp((oldestWait - 30) / 120, 0, 1)
	local quality = 45 * classCount / Policy.TeamSize + 35 * compatible / pairCount + 20 * sameLanguage / pairCount
	-- Missing/invalid levels are neutral. Cap this preference below one extra class,
	-- even when tuned, so level similarity alone never costs a complementary role.
	local levelWeight = finite(Policy.LevelWeight) and math.clamp(Policy.LevelWeight, 0, 45 / Policy.TeamSize - 0.01) or 0
	local levelBonus = levelWeight * levelSimilarity / pairCount
	quality += levelBonus
	local fairness = totalWait / (Policy.TeamSize * 300)
	local score = quality * (1 - relaxation * 0.65) + fairness * (5 + 60 * relaxation)
	return score, {
		ClassCount = classCount, ChatKnownPairs = chatKnown, ChatCompatiblePairs = compatible,
		ChatUnknownPairs = pairCount - chatKnown, SameLanguagePairs = sameLanguage,
		LevelKnownPairs = levelKnownPairs, LevelUnknownPairs = pairCount - levelKnownPairs,
		MeanRelativeLevelGap = levelKnownPairs > 0 and levelRelativeGap / levelKnownPairs or nil,
		LevelBonus = levelBonus,
		OldestWaitSeconds = oldestWait, MeanCappedWaitSeconds = totalWait / Policy.TeamSize,
		Relaxation = relaxation,
	}
end

-- Score({ticket, ...}, unixNow) -> number, diagnostics OR nil, reason.
-- A ticket is {Id, QueuedAt, ExpiresAt, MatchmakingType, Members={signal,...}}.
-- signal.Level is optional: a server-sourced integer in [1, MaxLevel]. Unknown
-- levels do not block matching or change the existing no-level score. Diagnostics
-- expose only aggregate pair counts/gaps; they contain no individual levels.
function Policy.Score(tickets, now)
	now = now or os.time()
	if not finite(now) or type(tickets) ~= "table" then return nil, "InvalidInput" end
	local prepared, ids, users, size, matchmakingType = {}, {}, {}, 0, nil
	for _, ticket in pairs(tickets) do
		if #prepared >= Policy.TeamSize or type(ticket) ~= "table" then return nil, "InvalidTicket" end
		matchmakingType = matchmakingType or ticket.MatchmakingType
		if not Policy.IsMatchmakingType(matchmakingType) then return nil, "UnknownMatchmakingType" end
		local party = prepare(ticket, now, matchmakingType)
		if not party or ids[party.Id] then return nil, "InvalidTicket" end
		ids[party.Id] = true
		for userId in pairs(party.UserIds) do
			if users[userId] then return nil, "DuplicatePlayer" end
			users[userId] = true
		end
		size += #party.Members
		table.insert(prepared, party)
	end
	if size ~= Policy.TeamSize then return nil, "NeedExactlySix" end
	table.sort(prepared, oldestFirst)
	return evaluate(prepared, now)
end

-- Choose(tickets, {Now=unixTime, MatchmakingType=name}) -> match OR nil, reason.
-- Searches the oldest feasible anchor first; party IDs break equal-time ties.
-- Results require queue leases and a final presence/roster check before teleport.
function Policy.Choose(tickets, options)
	options = options or {}
	local now, matchmakingType = options.Now or os.time(), options.MatchmakingType
	if not finite(now) or type(tickets) ~= "table" then return nil, "InvalidInput" end
	if not Policy.IsMatchmakingType(matchmakingType) then return nil, "UnknownMatchmakingType" end
	local available = {}
	for index, ticket in ipairs(tickets) do
		if index > Policy.MaxInputTickets then break end
		local party = prepare(ticket, now, matchmakingType)
		if party then table.insert(available, party) end
	end
	table.sort(available, oldestFirst)
	local pool, ids, oldestBySize = {}, {}, {}
	for _, party in ipairs(available) do
		local size = #party.Members
		if not oldestBySize[size] then oldestBySize[size] = party end
		if #pool < Policy.MaxCandidateTickets - Policy.TeamSize and not ids[party.Id] then
			ids[party.Id] = true
			table.insert(pool, party)
		end
	end
	-- Preserve size variety beyond the oldest window so many large parties do
	-- not hide the small party needed to complete six seats.
	for size = 1, Policy.TeamSize do
		local party = oldestBySize[size]
		if party and not ids[party.Id] then ids[party.Id] = true; table.insert(pool, party) end
	end
	table.sort(pool, oldestFirst)
	if #pool == 0 then return nil, "NoLiveCandidates" end
	local reachable = { [#pool + 1] = { [0] = true } }
	for index = #pool, 1, -1 do
		reachable[index] = {}
		local size = #pool[index].Members
		for remaining = 0, Policy.TeamSize do
			reachable[index][remaining] = reachable[index + 1][remaining] or (remaining >= size and reachable[index + 1][remaining - size])
		end
	end
	local visited = 0
	for anchor = 1, #pool do
		local chosen, users = { pool[anchor] }, table.clone(pool[anchor].UserIds)
		local best, bestScore, bestDetails
		local function search(start, remaining)
			if visited >= Policy.MaxSearchStates then return end
			visited += 1
			if remaining == 0 then
				local score, details = evaluate(chosen, now)
				-- Traversal is chronological, so equal scores keep the older roster.
				if not bestScore or score > bestScore then
					best, bestScore, bestDetails = table.clone(chosen), score, details
				end
				return
			end
			if not reachable[start] or not reachable[start][remaining] then return end
			for index = start, #pool do
				local party, overlap = pool[index], false
				if #party.Members <= remaining then
					for userId in pairs(party.UserIds) do if users[userId] then overlap = true; break end end
					if not overlap then
						for userId in pairs(party.UserIds) do users[userId] = true end
						table.insert(chosen, party)
						search(index + 1, remaining - #party.Members)
						table.remove(chosen)
						for userId in pairs(party.UserIds) do users[userId] = nil end
					end
				end
				if visited >= Policy.MaxSearchStates then break end
			end
		end
		search(anchor + 1, Policy.TeamSize - #pool[anchor].Members)
		if best then
			local result = { Parties = {}, PartyIds = {}, Members = {}, Score = bestScore, Diagnostics = bestDetails, MatchmakingType = matchmakingType }
			for _, party in ipairs(best) do
				table.insert(result.Parties, party.Ticket)
				table.insert(result.PartyIds, party.Id)
				for _, member in ipairs(party.Members) do table.insert(result.Members, member.Signal) end
			end
			result.Diagnostics.CandidateCount = #pool
			result.Diagnostics.SearchStates = visited
			result.Diagnostics.SearchTruncated = visited >= Policy.MaxSearchStates
			return result
		end
		if visited >= Policy.MaxSearchStates then return nil, "SearchBudgetReached" end
	end
	return nil, "NeedExactlySix"
end

return Policy
