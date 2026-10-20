--!strict
-- SocialService: pings and friends.
-- Pings: the client asks to place one (kind + where); the server checks it and shows it to
-- everyone in the server. Only a kind and a position travel, never typed text, so there is
-- nothing to filter or moderate.
-- Friends: who is friends with whom among the players in this server (asked once per pair on
-- join, since IsFriendsWith is a web call). Drives the friend coin bonus and friend notices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Social = require(ReplicatedStorage.Shared.Config.Social)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

-- A ping near another player counts as the first co-op action for the analytics funnel.
local COOP_DISTANCE = 120

local friendsOf: { [Player]: { [Player]: true } } = {}
local noticeRemote: RemoteEvent
local pingShownRemote: RemoteEvent

local function isFinite(vector: Vector3): boolean
	for _, value in { vector.X, vector.Y, vector.Z } do
		if value ~= value or math.abs(value) == math.huge then
			return false
		end
	end
	return true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function areFriends(a: Player, b: Player): boolean
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	return ok and result == true
end

local function onPlayerAdded(player: Player): ()
	friendsOf[player] = friendsOf[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and areFriends(player, other) and player.Parent == Players then
			(friendsOf[player] :: { [Player]: true })[other] = true
			local theirs = friendsOf[other]
			if theirs ~= nil then
				theirs[player] = true
			end
			noticeRemote:FireClient(
				other,
				`Your friend {player.DisplayName} is here! Friends find more coins.`
			)
			noticeRemote:FireClient(
				player,
				`Your friend {other.DisplayName} is here! Friends find more coins.`
			)
		end
	end
end

local function onPing(player: Player, kind: unknown, position: unknown): ()
	if not RateLimit.allow(player, "Ping", Social.pingCooldown) then
		return
	end
	if type(kind) ~= "string" or Social.pings[kind :: Social.PingKind] == nil then
		return
	end
	if typeof(position) ~= "Vector3" or not isFinite(position :: Vector3) then
		return
	end
	local root = rootOf(player)
	local where = position :: Vector3
	if root == nil or (where - root.Position).Magnitude > Social.pingRange then
		return
	end
	pingShownRemote:FireAllClients(player.UserId, player.DisplayName, kind, where)

	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if
			other ~= player
			and otherRoot ~= nil
			and (otherRoot.Position - root.Position).Magnitude <= COOP_DISTANCE
		then
			PlayerDataService.recordMilestone(player, "FirstCoopAction")
			break
		end
	end
end

local SocialService = {}

-- How many friends of this player are in the server (capped for the bonus).
function SocialService.friendCount(player: Player): number
	local count = 0
	for other in friendsOf[player] or {} do
		if other.Parent == Players then
			count += 1
		end
	end
	return count
end

-- Extra coins per coin pickup for playing with friends.
function SocialService.coinBonus(player: Player): number
	return math.min(SocialService.friendCount(player), Social.maxFriendsCounted)
		* Social.friendCoinBonus
end

function SocialService.start(): ()
	noticeRemote = Remotes.event("Notice")
	pingShownRemote = Remotes.event("PingShown")
	Remotes.event("Ping").OnServerEvent:Connect(onPing)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		friendsOf[player] = nil
		for _, friends in friendsOf do
			friends[player] = nil
		end
	end)
end

return SocialService
