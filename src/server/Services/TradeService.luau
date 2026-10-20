--!strict
-- TradeService: safe two-sided trades between friends (spec 4.4 + Config/Trading).
--
-- Flow: request -> the friend accepts -> both pick up to 4 loose parts -> both press Ready ->
-- a short countdown -> the swap. The server owns the whole trade: clients only ask, every
-- offer is checked against the real inventory, any change un-readies both sides and stops
-- the countdown, and the swap itself (PlayerDataService.executeTrade) re-checks everything
-- and moves both sides in one step. Walking away, leaving, or cancelling closes the trade
-- and nothing moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Trading = require(ReplicatedStorage.Shared.Config.Trading)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SocialService = require(script.Parent.SocialService)

type Session = {
	players: { Player },
	offers: { [Player]: { string } },
	ready: { [Player]: boolean },
	-- Bumped on every change, so an old countdown knows it was cancelled.
	version: number,
	countdownEnds: number?,
	messages: { [Player]: string? },
	open: boolean,
}

type Invite = { from: Player, expires: number }

local sessions: { [Player]: Session } = {}
local invites: { [Player]: Invite } = {}

local noticeRemote: RemoteEvent
local inviteRemote: RemoteEvent
local stateRemote: RemoteEvent

local function partnerOf(session: Session, player: Player): Player
	return if session.players[1] == player then session.players[2] else session.players[1]
end

local function distanceBetween(a: Player, b: Player): number
	local rootA = if a.Character ~= nil then a.Character:FindFirstChild("HumanoidRootPart") else nil
	local rootB = if b.Character ~= nil then b.Character:FindFirstChild("HumanoidRootPart") else nil
	if rootA == nil or rootB == nil or not rootA:IsA("BasePart") or not rootB:IsA("BasePart") then
		return math.huge
	end
	return (rootA.Position - rootB.Position).Magnitude
end

local function mayTrade(a: Player, b: Player): (boolean, string?)
	if a == b then
		return false, nil
	end
	local friends = SocialService.areFriends(a, b)
		or (RunService:IsStudio() and Trading.studioAllowsAnyone)
	if not friends then
		return false, "You can only trade with friends."
	end
	if sessions[a] ~= nil or sessions[b] ~= nil then
		return false, "One of you is already trading."
	end
	if not PlayerDataService.isLoaded(a) or not PlayerDataService.isLoaded(b) then
		return false, "Still loading. Try again in a moment!"
	end
	if distanceBetween(a, b) > Trading.maxDistance then
		return false, "Walk closer to trade."
	end
	return true, nil
end

local function push(session: Session): ()
	local now = os.clock()
	for _, player in session.players do
		local partner = partnerOf(session, player)
		local view: Types.TradeView = {
			partnerUserId = partner.UserId,
			partnerName = partner.DisplayName,
			myOffer = table.clone(session.offers[player]),
			theirOffer = table.clone(session.offers[partner]),
			myReady = session.ready[player],
			theirReady = session.ready[partner],
			countdown = if session.countdownEnds ~= nil
				then math.max(0, math.ceil(session.countdownEnds - now))
				else nil,
			message = session.messages[player],
		}
		stateRemote:FireClient(player, view)
	end
end

local function close(session: Session, reason: string?): ()
	if not session.open then
		return
	end
	session.open = false
	session.version += 1
	for _, player in session.players do
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent == Players then
			stateRemote:FireClient(player, nil)
			if reason ~= nil then
				noticeRemote:FireClient(player, reason)
			end
		end
	end
end

-- Anything changed: nobody is ready any more, and a running countdown stops.
local function changed(session: Session): ()
	session.version += 1
	session.countdownEnds = nil
	for _, player in session.players do
		session.ready[player] = false
	end
end

local function finish(session: Session): ()
	local a, b = session.players[1], session.players[2]
	local ok, reason = PlayerDataService.executeTrade(a, session.offers[a], b, session.offers[b])
	if ok then
		close(session, "Trade done! Check your bag.")
	else
		changed(session)
		session.messages[a] = reason
		session.messages[b] = reason
		push(session)
	end
end

local function startCountdown(session: Session): ()
	session.version += 1
	local version = session.version
	session.countdownEnds = os.clock() + Trading.countdownSeconds
	push(session)
	for second = Trading.countdownSeconds - 1, 0, -1 do
		task.wait(1)
		if not session.open or session.version ~= version then
			return
		end
		if second > 0 then
			push(session)
		end
	end
	finish(session)
end

-- A clean list of part ids from untrusted input, or nil.
local function parseOffer(value: unknown): { string }?
	if type(value) ~= "table" then
		return nil
	end
	local offer: { string } = {}
	local input = value :: { [unknown]: unknown }
	for index = 1, Trading.maxItems + 1 do
		local partId = input[index]
		if partId == nil then
			break
		end
		if index > Trading.maxItems or type(partId) ~= "string" then
			return nil
		end
		local definition = Parts.get(partId)
		if definition == nil or definition.free then
			return nil
		end
		table.insert(offer, partId)
	end
	-- Extra keys (holes, names) mean it is not a plain list.
	local keys = 0
	for _ in input do
		keys += 1
	end
	if keys ~= #offer then
		return nil
	end
	return offer
end

local function onRequest(player: Player, targetUserId: unknown): ()
	if not RateLimit.allow(player, "TradeRequest", 2) or type(targetUserId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil then
		return
	end
	local ok, reason = mayTrade(player, target)
	if not ok then
		if reason ~= nil then
			noticeRemote:FireClient(player, reason)
		end
		return
	end
	invites[target] = { from = player, expires = os.clock() + Trading.inviteSeconds }
	inviteRemote:FireClient(target, player.UserId, player.DisplayName)
	noticeRemote:FireClient(player, `Asked {target.DisplayName} to trade...`)
end

local function onRespond(player: Player, fromUserId: unknown, accept: unknown): ()
	if not RateLimit.allow(player, "TradeRespond", 0.5) then
		return
	end
	local invite = invites[player]
	if invite == nil or invite.from.UserId ~= fromUserId or os.clock() > invite.expires then
		return
	end
	invites[player] = nil
	local from = invite.from
	if accept ~= true then
		if from.Parent == Players then
			noticeRemote:FireClient(from, `{player.DisplayName} said no thanks.`)
		end
		return
	end
	local ok, reason = mayTrade(from, player)
	if not ok then
		noticeRemote:FireClient(player, reason or "Can't trade right now.")
		return
	end
	local session: Session = {
		players = { from, player },
		offers = { [from] = {}, [player] = {} },
		ready = { [from] = false, [player] = false },
		version = 0,
		messages = {},
		open = true,
	}
	sessions[from] = session
	sessions[player] = session
	push(session)
end

local function onSetOffer(player: Player, value: unknown): ()
	local session = sessions[player]
	if session == nil or not RateLimit.allow(player, "TradeSetOffer", 0.2) then
		return
	end
	local offer = parseOffer(value)
	if offer == nil then
		return
	end
	local ok, reason = PlayerDataService.canOffer(player, offer)
	changed(session)
	session.messages[player] = reason
	session.messages[partnerOf(session, player)] = nil
	if ok then
		session.offers[player] = offer
	end
	push(session)
end

local function onReady(player: Player, ready: unknown): ()
	local session = sessions[player]
	if
		session == nil
		or type(ready) ~= "boolean"
		or not RateLimit.allow(player, "TradeReady", 0.3)
	then
		return
	end
	if not ready then
		changed(session)
		push(session)
		return
	end
	local partner = partnerOf(session, player)
	if #session.offers[player] == 0 and #session.offers[partner] == 0 then
		session.messages[player] = "Put a part in first!"
		push(session)
		return
	end
	session.ready[player] = true
	session.messages[player] = nil
	if session.ready[partner] then
		task.spawn(startCountdown, session)
	else
		push(session)
	end
end

local TradeService = {}

function TradeService.start(): ()
	noticeRemote = Remotes.event("Notice")
	inviteRemote = Remotes.event("TradeInvite")
	stateRemote = Remotes.event("TradeState")

	Remotes.event("TradeRequest").OnServerEvent:Connect(onRequest)
	Remotes.event("TradeRespond").OnServerEvent:Connect(onRespond)
	Remotes.event("TradeSetOffer").OnServerEvent:Connect(onSetOffer)
	Remotes.event("TradeReady").OnServerEvent:Connect(onReady)
	Remotes.event("TradeCancel").OnServerEvent:Connect(function(player: Player)
		local session = sessions[player]
		if session ~= nil then
			close(session, `{player.DisplayName} closed the trade.`)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		for target, invite in invites do
			if invite.from == player then
				invites[target] = nil
			end
		end
		local session = sessions[player]
		if session ~= nil then
			close(session, "Your trade partner left. Nothing was traded.")
		end
	end)

	-- Walking away ends the trade (nothing moves).
	task.spawn(function()
		while true do
			task.wait(1)
			local checked: { [Session]: true } = {}
			for _, session in sessions do
				if not checked[session] then
					checked[session] = true
					local a, b = session.players[1], session.players[2]
					if distanceBetween(a, b) > Trading.maxDistance then
						close(session, "You walked too far apart. Nothing was traded.")
					end
				end
			end
		end
	end)
end

return TradeService
