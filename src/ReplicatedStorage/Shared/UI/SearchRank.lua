-- Shared station search scoring. Output names always outrank incidental matches
-- in ingredients, descriptions, categories, sources, or station names.
local SearchRank = {}

function SearchRank.Normalize(value)
	local text = tostring(value or "")
	text = text:gsub("(%l)(%u)", "%1 %2")
	text = text:gsub("[_%-%./]+", " ")
	text = string.lower(text)
	local trimmed = text:match("^%s*(.-)%s*$")
	return (trimmed:gsub("%s+", " "))
end

local function textScore(value, query)
	local text = SearchRank.Normalize(value)
	if text == "" then return nil end
	if text == query then return 0 end
	if text:sub(1, #query) == query then return 10 + math.min(9, #text - #query) end
	local wordAt = string.find(" " .. text, " " .. query, 1, true)
	if wordAt then return 25 + math.min(9, wordAt - 1) end
	local at = string.find(text, query, 1, true)
	if at then return 40 + math.min(19, at - 1) end
	local matched = 0
	for token in query:gmatch("%S+") do
		if not string.find(text, token, 1, true) then return nil end
		matched += 1
	end
	return matched > 1 and 70 or nil
end

local function visit(values, query, base, best)
	if type(values) ~= "table" then values = {values} end
	for _, value in ipairs(values) do
		local score = textScore(value, query)
		if score then best = math.min(best or math.huge, base + score) end
	end
	return best
end

function SearchRank.Score(query, primary, secondary)
	query = SearchRank.Normalize(query)
	if query == "" then return 0 end
	local best = visit(primary, query, 0, nil)
	best = visit(secondary, query, 100, best)
	return best
end

function SearchRank.Less(a, b, query, nameAccessor, fallback)
	if SearchRank.Normalize(query) ~= "" and a.SearchScore ~= b.SearchScore then
		return a.SearchScore < b.SearchScore
	end
	if fallback then
		local decided = fallback(a, b)
		if decided ~= nil then return decided end
	end
	local aName = SearchRank.Normalize(nameAccessor(a))
	local bName = SearchRank.Normalize(nameAccessor(b))
	if aName ~= bName then return aName < bName end
	return tostring(a.Id or "") < tostring(b.Id or "")
end

return SearchRank
