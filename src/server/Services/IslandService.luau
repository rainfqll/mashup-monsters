--!strict
-- IslandService: knows which region ("island" in code and saves) each player is in and keeps
-- the progression honest. Since the World Upgrade the regions are parts of one connected land.
--
-- Regions come from Config/Islands; the world pieces (zones, arrival points) are
-- built in Studio and carry an "Island" id attribute (see that file).
-- * Ability gates: the first visit to a region needs its ability while riding (Swim across the
--   river to Lily Lagoon, Super Jump up the cliff to Cliffside Peaks, Glide over the chasm to
--   Windy Canyons). Arriving that way unlocks it for good; arriving any other way (an exploit, a
--   glitch) puts you back where you last stood. The land itself is the real gate; this is the
--   server's check.
-- * Water: the client bounces non-swimmers out instantly (CreatureController). This is the
--   server's own check; it waits a moment so it never fights the client's smoother bounce.
-- * Falling off an island puts you back where you last stood (no deaths, no long walks).
-- * Arrival points ("IslandArrival" parts) are where portal travellers appear (PortalService)
--   and where a failed gate sends you when there is no safe spot to go back to.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Water = require(ReplicatedStorage.Shared.Water)
local CreatureService = require(script.Parent.CreatureService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ZONE_TAG = "IslandZone"
local ARRIVAL_TAG = "IslandArrival"
local CHECK_INTERVAL = 0.25
local ZONE_CHECK_INTERVAL = 0.5
-- Seconds in water without a swimmer before the server steps in.
local WATER_GRACE = 1
-- Below this height you have fallen off the islands.
local VOID_Y = -40
-- Characters can't walk up anything steeper (Roblox allows 89 degrees by default). Smooth
-- terrain turns cliffs and the jump steps into very steep slopes, and those must stay gates.
local MAX_SLOPE_ANGLE = 50

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

-- Back to the last safe spot (outside the region you weren't allowed into), or home.
local function sendBack(player: Player, watch: Watch): ()
	local safe = watch.lastSafe
	if safe ~= nil then
		CreatureService.teleport(player, safe)
	else
		sendHome(player, watch)
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
		sendBack(player, watch)
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
			sendBack(player, watch)
			return
		end
		if PlayerDataService.unlockIsland(player, islandId) then
			notify(player, `You found {island.displayName}!`)
		end
	end
	PlayerDataService.recordMilestone(player, "FirstNewIsland")
end

local IslandService = {}

-- Where travellers to a region appear (its "IslandArrival" part, a little above), or nil.
function IslandService.arrivalFor(islandId: string): CFrame?
	return arrivalFor(islandId)
end

-- After a teleport: falls and failed gates bring the player back here, not to the old spot.
function IslandService.setSafeSpot(player: Player, cframe: CFrame): ()
	local watch = watches[player]
	if watch ~= nil then
		watch.lastSafe = cframe
	end
end

function IslandService.start(): ()
	noticeRemote = Remotes.event("Notice")

	if arrivalFor(Islands.HOME) == nil then
		warn(`[Mashup Monsters] no {ARRIVAL_TAG} part for the home island; falls can't be rescued`)
	end

	local function limitSlope(character: Model): ()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			humanoid.MaxSlopeAngle = MAX_SLOPE_ANGLE
		end
	end
	local function watchCharacters(player: Player): ()
		player.CharacterAdded:Connect(limitSlope)
		if player.Character ~= nil then
			task.spawn(limitSlope, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchCharacters)
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
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
