-- ReplicatedStorage/MusicSystem#RS@2.1/PlaylistModule
--!nonstrict
local M = {}

M.Tracks = {
	{ id = "rbxassetid://82906251380066", title = "Recvyx Here!! Concrete Angel - Remix 2025", genre = "ZERO AREA PLAYLIST 1" },
	{ id = "rbxassetid://84335489881849", title = "Recvyx Here!! You Don't Even Me - Remix Edit 2026", genre = "ZERO AREA PLAYLIST 1" },
	{ id = "rbxassetid://113905292860677", title = "Recvyx Here!! Be As One - Remix Edit 2026", genre = "ZERO AREA PLAYLIST 1" },
	{ id = "rbxassetid://106656341998562", title = "Recvyx Here!! Bloodline [New] - Remix Edit 2026", genre = "ZERO AREA PLAYLIST 1" },
}

local function normalizeId(x)
	if not x then return nil end
	local raw = tostring(x):gsub("%s+", "")
	if raw == "" then return nil end
	if raw:match("^rbxassetid://%d+$") then return raw end
	if raw:match("^%d+$") then return "rbxassetid://" .. raw end
	local num = raw:match("(%d+)")
	if num then return "rbxassetid://" .. num end
	return nil
end

local function normalizeGenre(g)
	g = tostring(g or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if g == "" then return "Uncategorized" end
	return g
end

function M.GetTracks()
	local out = {}
	for _, t in ipairs(M.Tracks) do
		local id = normalizeId(t.id)
		if id then
			table.insert(out, {
				id = id,
				title = tostring(t.title or ("Sound " .. id:gsub("rbxassetid://", ""))),
				genre = normalizeGenre(t.genre),
			})
		end
	end
	return out
end

return M
