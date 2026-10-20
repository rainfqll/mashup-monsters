--!strict
-- ChallengeService: one small challenge per island (Config/Challenges).
--
-- Chest: a prompt on a part tagged "ChallengeChest". Reaching it is the challenge (the summit of
-- Cliffside Peaks), so opening it only checks distance and that the island is unlocked.
-- Rings: parts tagged "ChallengeRing" (invisible cylinders, axis along the part's X) with an
-- "Order" number. The server watches each player's path and counts a ring when the path
-- crosses its disc, so the client never reports "I passed a ring". Ring 1 starts a run.
--
-- First completion gives the challenge's part; later completions pay a few coins, with a
-- cooldown kept in memory (a rejoin resets it; worth at most a few coins).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Challenges = require(ReplicatedStorage.Shared.Config.Challenges)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CHEST_TAG = "ChallengeChest"
local RING_TAG = "ChallengeRing"
local CHEST_DISTANCE = 14
local RING_CHECK_INTERVAL = 0.1
-- A teleport-sized jump between two checks is not flying through a ring.
local MAX_STEP = 40

type Run = {
	challengeId: string,
	nextRing: number,
	startedAt: number,
}

local rings: { [string]: { BasePart } } = {}
local runs: { [Player]: Run } = {}
local lastPositions: { [Player]: Vector3 } = {}
local cooldowns: { [Player]: { [string]: number } } = {}

local noticeRemote: RemoteEvent
local progressRemote: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- Gives the first-time part or the repeat coins. Returns the message for the player.
local function reward(player: Player, challenge: Challenges.ChallengeDefinition): string
	if not PlayerDataService.isChallengeDone(player, challenge.id) then
		if PlayerDataService.completeChallenge(player, challenge.id, challenge.firstReward) then
			local part = Parts.get(challenge.firstReward)
			local partName = if part ~= nil then part.displayName else challenge.firstReward
			return `{challenge.displayName} done! You got {partName}!`
		end
		return "Your lab is still loading. Try again!"
	end
	local playerCooldowns = cooldowns[player]
	if playerCooldowns == nil then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	local readyAt = playerCooldowns[challenge.id] or 0
	local now = os.clock()
	if now < readyAt then
		local minutes = math.ceil((readyAt - now) / 60)
		return `{challenge.displayName}: more coins in {minutes} min!`
	end
	playerCooldowns[challenge.id] = now + challenge.repeatCooldown
	PlayerDataService.addCoins(player, challenge.repeatCoins, `Challenge_{challenge.id}`)
	return `{challenge.displayName}: +{challenge.repeatCoins} coins!`
end

local function setUpChest(chest: Instance): ()
	local challengeId = chest:GetAttribute("Challenge")
	local challenge = if type(challengeId) == "string" then Challenges.get(challengeId) else nil
	if not chest:IsA("BasePart") or challenge == nil or challenge.kind ~= "Chest" then
		warn(
			`[Mashup Monsters] {chest:GetFullName()} is tagged {CHEST_TAG} without a Chest challenge`
		)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = challenge.displayName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player)
		if not RateLimit.allow(player, "ChallengeChest", 1) then
			return
		end
		local root = rootOf(player)
		if root == nil or (root.Position - chest.Position).Magnitude > CHEST_DISTANCE then
			return
		end
		if not PlayerDataService.isIslandUnlocked(player, challenge.island) then
			return
		end
		noticeRemote:FireClient(player, reward(player, challenge))
	end)
end

-- Did the path from `from` to `to` pass through the ring's disc?
local function crossed(ring: BasePart, from: Vector3, to: Vector3): boolean
	local radius = math.min(ring.Size.Y, ring.Size.Z) / 2
	local a = ring.CFrame:PointToObjectSpace(from)
	local b = ring.CFrame:PointToObjectSpace(to)
	if (a.X > 0) == (b.X > 0) then
		-- Same side: still count a slow pass right through the middle.
		return Vector3.new(b.X * 3, b.Y, b.Z).Magnitude <= radius * 0.6
	end
	local t = a.X / (a.X - b.X)
	local hit = a + (b - a) * t
	return Vector2.new(hit.Y, hit.Z).Magnitude <= radius
end

local function endRun(player: Player, run: Run): ()
	runs[player] = nil
	progressRemote:FireClient(player, run.challengeId, 0, #rings[run.challengeId], 0)
end

local function stepRings(player: Player, now: number): ()
	local root = rootOf(player)
	local previous = lastPositions[player]
	if root == nil then
		lastPositions[player] = nil
		return
	end
	local position = root.Position
	lastPositions[player] = position
	if previous == nil or (position - previous).Magnitude > MAX_STEP then
		return
	end

	local run = runs[player]
	if run ~= nil then
		local challenge = Challenges.get(run.challengeId) :: Challenges.ChallengeDefinition
		local course = rings[run.challengeId]
		local timeLimit = challenge.timeLimit or 60
		if now - run.startedAt > timeLimit then
			noticeRemote:FireClient(player, "Out of time! Fly through ring 1 to try again.")
			endRun(player, run)
			return
		end
		if crossed(course[run.nextRing], previous, position) then
			if run.nextRing >= #course then
				endRun(player, run)
				noticeRemote:FireClient(player, reward(player, challenge))
				return
			end
			run.nextRing += 1
			progressRemote:FireClient(
				player,
				run.challengeId,
				run.nextRing,
				#course,
				math.ceil(timeLimit - (now - run.startedAt))
			)
		end
		return
	end

	for challengeId, course in rings do
		local challenge = Challenges.get(challengeId) :: Challenges.ChallengeDefinition
		if
			PlayerDataService.isIslandUnlocked(player, challenge.island)
			and crossed(course[1], previous, position)
		then
			runs[player] = { challengeId = challengeId, nextRing = 2, startedAt = now }
			progressRemote:FireClient(player, challengeId, 2, #course, challenge.timeLimit or 60)
			return
		end
	end
end

local ChallengeService = {}

function ChallengeService.start(): ()
	noticeRemote = Remotes.event("Notice")
	progressRemote = Remotes.event("ChallengeProgress")

	for _, chest in CollectionService:GetTagged(CHEST_TAG) do
		setUpChest(chest)
	end

	for _, ring in CollectionService:GetTagged(RING_TAG) do
		local challengeId = ring:GetAttribute("Challenge")
		local challenge = if type(challengeId) == "string" then Challenges.get(challengeId) else nil
		if ring:IsA("BasePart") and challenge ~= nil and challenge.kind == "Rings" then
			local course = rings[challenge.id] or {}
			table.insert(course, ring)
			rings[challenge.id] = course
		else
			warn(
				`[Mashup Monsters] {ring:GetFullName()} is tagged {RING_TAG} without a Rings challenge`
			)
		end
	end
	for _, course in rings do
		table.sort(course, function(a, b)
			return (tonumber(a:GetAttribute("Order")) or 0)
				< (tonumber(b:GetAttribute("Order")) or 0)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		lastPositions[player] = nil
		cooldowns[player] = nil
	end)

	if next(rings) ~= nil then
		task.spawn(function()
			while true do
				task.wait(RING_CHECK_INTERVAL)
				local now = os.clock()
				for _, player in Players:GetPlayers() do
					stepRings(player, now)
				end
			end
		end)
	end
end

return ChallengeService
