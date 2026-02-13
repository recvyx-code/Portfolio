--!strict
-- Shared admin authority config

local Players = game:GetService("Players")

type RankSet = {[number]: boolean}

type GroupAdminRule = {
	groupId: number,
	ranks: RankSet,
}

local M = {}

M.AdminUserIds = {
	[9731608376] = true,
	[9731628814] = true,
	[8992404409] = true,
} :: {[number]: boolean}

M.GroupRules = {
	{
		groupId = 651612788,
		ranks = {
			[235] = true,
			[240] = true,
			[245] = true,
			[250] = true,
			[255] = true,
		},
	},
} :: {GroupAdminRule}

function M.IsAdminUserId(userId: number): boolean
	return M.AdminUserIds[userId] == true
end

function M.IsAdminPlayer(plr: Player): boolean
	if M.IsAdminUserId(plr.UserId) then
		return true
	end

	for _, rule in ipairs(M.GroupRules) do
		local ok, rank = pcall(function()
			return plr:GetRankInGroup(rule.groupId)
		end)
		if ok and rule.ranks[rank] == true then
			return true
		end
	end

	return false
end

function M.GetCachedAdminResolver()
	local cache: {[number]: boolean} = {}

	Players.PlayerRemoving:Connect(function(plr)
		cache[plr.UserId] = nil
	end)

	return function(plr: Player): boolean
		local cached = cache[plr.UserId]
		if cached ~= nil then
			return cached
		end
		local res = M.IsAdminPlayer(plr)
		cache[plr.UserId] = res
		return res
	end
end

return M
