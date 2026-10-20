--!strict
-- Per-player cooldowns for remotes. Stops a spammed remote from costing real server work;
-- it is not a security check on its own (handlers still validate everything).

local Players = game:GetService("Players")

local lastUse: { [Player]: { [string]: number } } = {}

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
end)

local RateLimit = {}

-- True if `player` has not used `key` within the last `interval` seconds (and records this use).
function RateLimit.allow(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local uses = lastUse[player]
	if uses == nil then
		uses = {}
		lastUse[player] = uses
	end
	local last = uses[key]
	if last ~= nil and now - last < interval then
		return false
	end
	uses[key] = now
	return true
end

return RateLimit
