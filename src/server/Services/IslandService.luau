--!strict
-- IslandService: knows which island each player is on and keeps the progression honest.
--
-- Islands come from Config/Islands; the world pieces (zones, arrival points, travel pads) are
-- built in Studio and carry an "Island" id attribute (see that file).
-- * Ability gates: the first visit to an island needs its ability while riding (Swim for Lily
--   Lagoon, Super Jump for Cliffside Peaks, Glide for Windy Canyons). Arriving that way unlocks
--   the island for good; arriving any other way (an exploit, a glitch) sends you home. The
--   world itself is the real gate (water, high ledges, wide gaps); this is the server's check.
-- * Water: the client bounces non-swimmers out instantly (CreatureController). This is the
--   server's own check; it waits a moment so it never fights the client's smoother bounce.
-- * Falling off an island puts you back where you last stood (no deaths, no long walks).
-- * Travel pads at the lab take you to any unlocked island; a pad on each island goes home.
--   They use the ProximityPrompt's server-side Triggered, so no remote is needed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Water = require(ReplicatedStorage.Shared.Water)
local RateLimit = require(script.Parent.Parent.RateLimit)
local CreatureService = require(script.Parent.CreatureService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ZONE_TAG = "IslandZone"
local ARRIVAL_TAG = "IslandArrival"
local PAD_TAG = "TravelPad"
-- Client code styles prompts with this tag (lock state, labels).
local PAD_PROMPT_TAG = "TravelPrompt"
local CHECK_INTERVAL = 0.25
local ZONE_CHECK_INTERVAL = 0.5
-- Seconds in water without a swimmer before the server steps in.
local WATER_GRACE = 1
-- Below this height you have fallen off the islands.
local VOID_Y = -40
local PAD_DISTANCE = 16

type Watch = {
	lastSafe: CFrame?,
	inWaterSince: number?,
}

local watches: { [Player]: Watch } = {}
local noticeRemote: RemoteEvent

local function islandAt(position: Vector3): string?
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") then
			local localPoint = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(localPoint.X) <= half.X
				and math.abs(localPoint.Y) <= half.Y
				and math.abs(localPoint.Z) <= half.Z
			then
				local island = zone:GetAttribute("Island")
				return if type(island) == "string" then island else nil
			end
		end
	end
	return nil
end

local function arrivalFor(islandId: string): CFrame?
	for _, arrival in CollectionService:GetTagged(ARRIVAL_TAG) do
		if arrival:IsA("BasePart") and arrival:GetAttribute("Island") == islandId then
			return arrival.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

local function characterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function notify(player: Player, text: string): ()
	noticeRemote:FireClient(player, text)
end

local function sendHome(player: Player, watch: Watch): ()
	local home = arrivalFor(Islands.HOME)
	if home ~= nil then
		CreatureService.teleport(player, home)
		watch.lastSafe = home
	end
end

-- Somewhere you may stand: not water, and not an island you haven't unlocked yet.
local function isSafeSpot(player: Player, position: Vector3): boolean
	local island = islandAt(position)
	return island == nil or PlayerDataService.isIslandUnlocked(player, island)
end

local function checkFooting(player: Player, watch: Watch, now: number): ()
	local humanoid, root = characterParts(player)
	if humanoid == nil or root == nil then
		watch.inWaterSince = nil
		return
	end

	if root.Position.Y < VOID_Y then
		watch.inWaterSince = nil
		if watch.lastSafe ~= nil then
			CreatureService.teleport(player, watch.lastSafe :: CFrame)
		else
			sendHome(player, watch)
		end
		return
	end

	local inWater = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or Water.isWaterAt(Water.feetPosition(humanoid, root))
	if not inWater then
		watch.inWaterSince = nil
		if humanoid.FloorMaterial ~= Enum.Material.Air and isSafeSpot(player, root.Position) then
			watch.lastSafe = root.CFrame
		end
		return
	end
	if CreatureService.ridingWith(player, "Swim") then
		watch.inWaterSince = nil
		return
	end
	local since = watch.inWaterSince
	if since == nil then
		watch.inWaterSince = now
	elseif now - since >= WATER_GRACE and watch.lastSafe ~= nil then
		CreatureService.teleport(player, watch.lastSafe :: CFrame)
		watch.inWaterSince = nil
	end
end

local function checkIsland(player: Player, watch: Watch): ()
	local _, root = characterParts(player)
	local islandId = if root ~= nil then islandAt(root.Position) else nil
	if islandId == nil or islandId == Islands.HOME then
		return
	end
	local island = Islands.get(islandId)
	if island == nil then
		return
	end
	if not PlayerDataService.isIslandUnlocked(player, islandId) then
		local needed = island.requires
		if needed ~= nil and not CreatureService.ridingWith(player, needed) then
			notify(player, `You need {Islands.abilityName(needed)} to reach {island.displayName}!`)
			sendHome(player, watch)
			return
		end
		if PlayerDataService.unlockIsland(player, islandId) then
			notify(player, `{island.displayName} unlocked! Its travel pad at your lab works now.`)
		end
	end
	PlayerDataService.recordMilestone(player, "FirstNewIsland")
end

local function onPadTriggered(pad: BasePart, islandId: string, player: Player): ()
	if not RateLimit.allow(player, "TravelPad", 1) then
		return
	end
	local _, root = characterParts(player)
	if root == nil or (root.Position - pad.Position).Magnitude > PAD_DISTANCE then
		return
	end
	local island = Islands.get(islandId)
	if island == nil then
		return
	end
	if not PlayerDataService.isIslandUnlocked(player, islandId) then
		local needed = if island.requires ~= nil then Islands.abilityName(island.requires) else "?"
		notify(player, `Reach {island.displayName} once first! You need {needed}.`)
		return
	end
	local arrival = arrivalFor(islandId)
	if arrival == nil then
		warn(`[Mashup Monsters] no {ARRIVAL_TAG} part for island "{islandId}"`)
		return
	end
	CreatureService.teleport(player, arrival)
	local watch = watches[player]
	if watch ~= nil then
		watch.lastSafe = arrival
	end
end

local function setUpPad(pad: Instance): ()
	local islandId = pad:GetAttribute("Island")
	local island = if type(islandId) == "string" then Islands.get(islandId) else nil
	if not pad:IsA("BasePart") or type(islandId) ~= "string" or island == nil then
		warn(`[Mashup Monsters] {pad:GetFullName()} is tagged {PAD_TAG} without a valid Island`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.ActionText = if islandId == Islands.HOME then "Go home" else "Travel"
	prompt.ObjectText = island.displayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Island", islandId)
	prompt.Parent = pad
	CollectionService:AddTag(prompt, PAD_PROMPT_TAG)
	prompt.Triggered:Connect(function(player)
		onPadTriggered(pad, islandId, player)
	end)
end

local IslandService = {}

function IslandService.start(): ()
	noticeRemote = Remotes.event("Notice")

	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		setUpPad(pad)
	end
	if arrivalFor(Islands.HOME) == nil then
		warn(`[Mashup Monsters] no {ARRIVAL_TAG} part for the home island; falls can't be rescued`)
	end

	Players.PlayerRemoving:Connect(function(player)
		watches[player] = nil
	end)

	task.spawn(function()
		local nextZoneCheck = 0
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.clock()
			local checkZones = now >= nextZoneCheck
			if checkZones then
				nextZoneCheck = now + ZONE_CHECK_INTERVAL
			end
			for _, player in Players:GetPlayers() do
				if PlayerDataService.isLoaded(player) then
					local watch = watches[player]
					if watch == nil then
						watch = {}
						watches[player] = watch
					end
					checkFooting(player, watch, now)
					if checkZones then
						checkIsland(player, watch)
					end
				end
			end
		end
	end)
end

return IslandService
