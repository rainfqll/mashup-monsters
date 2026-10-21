--!strict
-- PlayerDataService: the only module that reads or writes saved player data. Keeping saves
-- behind one owner is what makes session locking and safe saving possible.
--
-- ProfileStore does the hard parts: a session lock (one server owns a save at a time, so two
-- servers can't overwrite each other), autosave every few minutes, retries, and a final save
-- on leave and on server shutdown (it binds BindToClose itself).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RetiredIds = require(ReplicatedStorage.Shared.Config.RetiredIds)
local Shelf = require(ReplicatedStorage.Shared.Config.Shelf)
local Trading = require(ReplicatedStorage.Shared.Config.Trading)
local Types = require(ReplicatedStorage.Shared.Types)

-- Bump CURRENT_VERSION and add a step to migrate() whenever the save shape changes.
local CURRENT_VERSION = 7

export type PlayerData = {
	version: number,
	coins: number,
	-- partId -> how many loose parts the player owns (parts inside creatures are not counted)
	inventory: { [string]: number },
	-- v2: stitched creatures; their parts left the inventory and come back on unstitch
	creatures: { Types.Loadout },
	-- v2: index into creatures of the one that is out, 0 = none
	activeCreature: number,
	-- v2: every part ever found, for the creature book
	discovered: { [string]: true },
	-- v3: the guided first session is over (set on the first ride)
	tutorialDone: boolean,
	-- v3: which personal starter pickups (by spot name) were collected during the old tutorial.
	-- Unused since v7 (the starter stand); kept so old saves load unchanged.
	starterCollected: { [string]: true },
	-- v3: first-time milestones already logged to analytics (see MILESTONES)
	funnel: { [string]: true },
	-- v4: islands reached at least once (the travel pads go there). Meadow Isle is implied.
	unlockedIslands: { [string]: true },
	-- v4: challenges whose first-time reward was given
	challengesDone: { [string]: true },
	-- v4: display shelf coins earned but not collected yet (fractional), and the os.time() they
	-- were last worked out (0 = never). See settleShelf.
	shelfStored: number,
	shelfUpdatedAt: number,
	-- v4: UTC day (Daily.today()) of the last free daily bundle, 0 = never
	dailyBundleDay: number,
	-- v4: Secret Mashups ever stitched, for the creature book
	secretsFound: { [string]: true },
	-- v5: partId -> os.time() until which it can't be traded (fresh Legendary+ parts)
	tradeLockUntil: { [string]: number },
	-- v7: the player built their first monster in the starter pop-up (Config/Starters)
	starterMade: boolean,
	-- v7: egg spot name -> os.time() it was last found (it comes back after Eggs.respawnHours)
	eggSpots: { [string]: number },
}

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	coins = 0,
	inventory = {},
	creatures = {},
	activeCreature = 0,
	discovered = {},
	tutorialDone = false,
	starterCollected = {},
	funnel = {},
	unlockedIslands = {},
	challengesDone = {},
	shelfStored = 0,
	shelfUpdatedAt = 0,
	dailyBundleDay = 0,
	secretsFound = {},
	tradeLockUntil = {},
	starterMade = false,
	eggSpots = {},
}

-- Onboarding funnel steps (Roblox AnalyticsService), logged once per player in this order.
local MILESTONES: { [string]: number } = {
	Joined = 1,
	FirstPart = 2,
	FirstStitch = 3,
	FirstRide = 4,
	FirstNewIsland = 5,
	FirstCoopAction = 6,
}
local COIN_CURRENCY = "Coins"

-- Studio gets its own store so testing never touches real players' saves.
-- In Studio only, a string attribute "DevStoreSuffix" on ServerStorage (e.g. "_Fresh1") switches
-- to another empty test store, to replay the first session without deleting the usual test save.
local function storeName(): string
	if not RunService:IsStudio() then
		return "PlayerData"
	end
	local suffix = ServerStorage:GetAttribute("DevStoreSuffix")
	return "PlayerData_Studio" .. (if type(suffix) == "string" then suffix else "")
end
local STORE_NAME = storeName()

-- Keys keep the UserId as plain text so Roblox's "right to be forgotten" deletion requests match.
local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local store = ProfileStore.New(STORE_NAME, TEMPLATE)

local profiles: { [Player]: ProfileStore.Profile<PlayerData> } = {}
local readyPlayers: { [Player]: true } = {}

local snapshotRemote: RemoteEvent
local collectedRemote: RemoteEvent

type ActiveListener = (Player) -> ()
local activeListeners: { ActiveListener } = {}

local function isCount(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function isIndex(value: unknown, max: number): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0 and value <= max
end

-- v6: every retired part or secret id in a save becomes its replacement (RetiredIds). Counts
-- add up when two old parts became the same new part. Malformed values are left for sanitize().
local function convertRetiredIds(data: PlayerData): ()
	local newPartId = RetiredIds.parts
	local inventory: { [string]: number } = {}
	for partId, count in data.inventory do
		local id = newPartId[partId] or partId
		if isCount(count) then
			inventory[id] = (inventory[id] or 0) + count
		end
	end
	data.inventory = inventory

	for _, loadout in data.creatures do
		if type(loadout) == "table" then
			for _, slot in Creatures.SLOTS do
				local partId = (loadout :: any)[slot]
				if newPartId[partId] ~= nil then
					(loadout :: any)[slot] = newPartId[partId]
				end
			end
		end
	end

	local discovered: { [string]: true } = {}
	for partId in data.discovered do
		discovered[newPartId[partId] or partId] = true
	end
	data.discovered = discovered

	local locks: { [string]: number } = {}
	for partId, untilTime in data.tradeLockUntil do
		local id = newPartId[partId] or partId
		if isCount(untilTime) then
			locks[id] = math.max(locks[id] or 0, untilTime)
		end
	end
	data.tradeLockUntil = locks

	local secrets: { [string]: true } = {}
	for secretId in data.secretsFound do
		secrets[RetiredIds.secrets[secretId] or secretId] = true
	end
	data.secretsFound = secrets
end

-- Upgrades older saves one version at a time. Runs after Reconcile(), so fields that are new
-- in this version already exist (empty) and only need filling in.
local function migrate(data: PlayerData): ()
	if data.version > CURRENT_VERSION then
		-- Saved by a newer server build; leave it untouched rather than downgrading it.
		warn(
			`[Mashup Monsters] save version {data.version} is newer than this server ({CURRENT_VERSION})`
		)
		return
	end
	if data.version < 2 then
		-- v1 -> v2: everything already owned counts as discovered for the creature book.
		for partId in data.inventory do
			data.discovered[partId] = true
		end
	end
	if data.version < 3 then
		-- v2 -> v3: anyone who already stitched a creature has done what the tutorial teaches.
		data.tutorialDone = #data.creatures > 0
	end
	-- v4 -> v5 needs no step: tradeLockUntil starts empty (Reconcile adds it), so parts found
	-- before trading existed are tradable.
	if data.version < 4 then
		-- v3 -> v4: anyone who already swam to Lily Lagoon keeps it on the travel pads.
		if data.funnel.FirstNewIsland then
			data.unlockedIslands.LilyLagoon = true
		end
	end
	if data.version < 6 then
		-- v5 -> v6: the farm-animal parts became the fantasy families.
		convertRetiredIds(data)
	end
	-- v6 -> v7 needs no step: starterMade starts false and eggSpots empty, and players who
	-- already have a creature are past the tutorial, so the starter pop-up never offers them one.
	data.version = CURRENT_VERSION
end

-- A bad value (NaN, negative, wrong type) would make every later save fail, so repair on load.
-- Unknown part ids are kept: a part removed from Parts.luau may come back, and deleting saved
-- items is not reversible.
local function sanitize(data: PlayerData): ()
	if not isCount(data.coins) then
		data.coins = 0
	end
	data.coins = math.floor(data.coins)

	for partId, count in data.inventory do
		if type(partId) ~= "string" or not isCount(count) or count < 1 then
			data.inventory[partId] = nil
		else
			data.inventory[partId] = math.floor(count)
		end
	end

	-- A creature that no longer parses (e.g. a part changed slot) is taken apart instead of
	-- deleted: every part id it held goes back to the inventory.
	local creatures: { Types.Loadout } = {}
	for _, raw in data.creatures do
		local loadout = Creatures.parseLoadout(raw)
		if loadout ~= nil then
			table.insert(creatures, loadout)
		elseif type(raw) == "table" then
			for _, slot in Creatures.SLOTS do
				local partId = (raw :: any)[slot]
				local definition = if type(partId) == "string" then Parts.get(partId) else nil
				if type(partId) == "string" and (definition == nil or not definition.free) then
					data.inventory[partId] = (data.inventory[partId] or 0) + 1
				end
			end
		end
	end
	data.creatures = creatures

	if not isIndex(data.activeCreature, #data.creatures) then
		data.activeCreature = 0
	end

	for _, flags in
		{
			data.discovered,
			data.starterCollected,
			data.funnel,
			data.unlockedIslands,
			data.challengesDone,
			data.secretsFound,
		}
	do
		for key, value in flags do
			if type(key) ~= "string" or value ~= true then
				flags[key] = nil
			end
		end
	end
	if type(data.tutorialDone) ~= "boolean" then
		data.tutorialDone = false
	end
	if type(data.starterMade) ~= "boolean" then
		data.starterMade = false
	end
	for _, field in { "shelfUpdatedAt", "dailyBundleDay" } do
		local value = (data :: any)[field]
		if not isCount(value) then
			(data :: any)[field] = 0
		else
			(data :: any)[field] = math.floor(value)
		end
	end
	if not isCount(data.shelfStored) then
		data.shelfStored = 0
	end
	local now = os.time()
	for partId, untilTime in data.tradeLockUntil do
		if type(partId) ~= "string" or not isCount(untilTime) or untilTime <= now then
			data.tradeLockUntil[partId] = nil
		end
	end
	-- Eggs that are back already need no entry; dropping them keeps the save small.
	local eggSeconds = Eggs.respawnHours * 3600
	for spotName, foundAt in data.eggSpots do
		if type(spotName) ~= "string" or not isCount(foundAt) or foundAt + eggSeconds <= now then
			data.eggSpots[spotName] = nil
		end
	end
end

-- Coins per hour from every saved creature that is not out (those sit on the lab shelf).
local function shelfRate(data: PlayerData): number
	local rate = 0
	for index, loadout in data.creatures do
		if index ~= data.activeCreature then
			for _, partId in Creatures.partIds(loadout) do
				local definition = Parts.get(partId)
				if definition ~= nil then
					rate += Shelf.coinsPerHour[definition.rarity] or 0
				end
			end
		end
	end
	return rate
end

-- Adds what the shelf earned since it was last worked out, up to the cap. Called before
-- anything that changes which creatures are on the shelf, so a swap never earns backwards.
local function settleShelf(data: PlayerData): ()
	local now = os.time()
	if data.shelfUpdatedAt <= 0 or data.shelfUpdatedAt > now then
		data.shelfUpdatedAt = now
		return
	end
	local rate = shelfRate(data)
	local cap = rate * Shelf.capHours
	local earned = rate * (now - data.shelfUpdatedAt) / 3600
	-- Never takes coins away: if a swap lowered the cap below what is stored, it just stops growing.
	if data.shelfStored < cap then
		data.shelfStored = math.min(data.shelfStored + earned, cap)
	end
	data.shelfUpdatedAt = now
end

local PlayerDataService = {}

local function notifyActiveChanged(player: Player): ()
	for _, listener in activeListeners do
		task.spawn(listener, player)
	end
end

local function sendSnapshot(player: Player): ()
	local profile = profiles[player]
	if profile == nil or not readyPlayers[player] then
		return
	end
	local creatures = {}
	for index, loadout in profile.Data.creatures do
		creatures[index] = table.clone(loadout)
	end
	local snapshot: Types.PlayerSnapshot = {
		coins = profile.Data.coins,
		inventory = table.clone(profile.Data.inventory),
		creatures = creatures,
		activeCreature = profile.Data.activeCreature,
		discovered = table.clone(profile.Data.discovered),
		tutorialDone = profile.Data.tutorialDone,
		funnel = table.clone(profile.Data.funnel),
		unlockedIslands = table.clone(profile.Data.unlockedIslands),
		challengesDone = table.clone(profile.Data.challengesDone),
		secretsFound = table.clone(profile.Data.secretsFound),
		dailyBundleDay = profile.Data.dailyBundleDay,
		shelfStored = profile.Data.shelfStored,
		shelfRate = shelfRate(profile.Data),
		shelfCap = shelfRate(profile.Data) * Shelf.capHours,
		shelfUpdatedAt = profile.Data.shelfUpdatedAt,
		tradeLockUntil = table.clone(profile.Data.tradeLockUntil),
		starterMade = profile.Data.starterMade,
		eggSpots = table.clone(profile.Data.eggSpots),
	}
	snapshotRemote:FireClient(player, snapshot)
end

local function onPlayerAdded(player: Player): ()
	local profile = store:StartSessionAsync(
		keyFor(player),
		{
			-- Stop waiting for the lock if the player already left.
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)

	if profile == nil then
		-- Roblox's DataStores are down or another server will not let go. Playing without
		-- a save would lose everything they collect, so ask them to rejoin instead.
		player:Kick("Your monster lab could not load. Please rejoin!")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	sanitize(profile.Data)
	-- Counts the time since the last session: the shelf kept earning while they were away.
	settleShelf(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		-- Ends early only if another server took the save (e.g. the player joined elsewhere).
		if player.Parent == Players then
			player:Kick("Your monster lab was opened somewhere else. Please rejoin!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	PlayerDataService.recordMilestone(player, "Joined")
	sendSnapshot(player)
	notifyActiveChanged(player)
end

local function onPlayerRemoving(player: Player): ()
	readyPlayers[player] = nil
	local profile = profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Logs a first-time milestone to the onboarding funnel once per player, ever. Recording
-- "FirstRide" also ends the tutorial. Unknown names are ignored.
function PlayerDataService.recordMilestone(player: Player, name: string): ()
	local profile = profiles[player]
	local step = MILESTONES[name]
	if profile == nil or step == nil or profile.Data.funnel[name] then
		return
	end
	profile.Data.funnel[name] = true
	if name == "FirstRide" then
		profile.Data.tutorialDone = true
	end
	-- Analytics must never break gameplay (e.g. if the service is unavailable in some context).
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, name)
	sendSnapshot(player)
end

-- The single way to give parts. `partId` must be a real part; returns false (and gives
-- nothing) if it is unknown or the player's save is not loaded, so callers can keep the item.
-- `quiet` skips the "+ part" pop-up (the bundle reveal shows the part itself).
function PlayerDataService.addPart(
	player: Player,
	partId: string,
	amount: number,
	quiet: boolean?
): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	if Parts.get(partId) == nil then
		warn(`[Mashup Monsters] addPart: unknown part id "{partId}"`)
		return false
	end
	if amount ~= amount or amount < 1 or amount % 1 ~= 0 then
		warn(`[Mashup Monsters] addPart: bad amount {amount}`)
		return false
	end

	local inventory = profile.Data.inventory
	inventory[partId] = (inventory[partId] or 0) + amount
	profile.Data.discovered[partId] = true
	local definition = Parts.get(partId) :: Types.PartDefinition
	if Trading.lockedRarities[definition.rarity] then
		profile.Data.tradeLockUntil[partId] = os.time() + Trading.lockSeconds
	end

	sendSnapshot(player)
	if not quiet then
		collectedRemote:FireClient(player, partId)
	end
	PlayerDataService.recordMilestone(player, "FirstPart")
	return true
end

-- Gives coins earned in play (pickups). `source` names what paid out, for the economy dashboard.
function PlayerDataService.addCoins(player: Player, amount: number, source: string): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	if amount ~= amount or amount < 1 or amount % 1 ~= 0 then
		warn(`[Mashup Monsters] addCoins: bad amount {amount}`)
		return false
	end
	profile.Data.coins += amount
	local balance = profile.Data.coins
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		COIN_CURRENCY,
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		source
	)
	sendSnapshot(player)
	return true
end

-- Buys one bundle: takes `price` coins and gives `partId` in one step, so a player can never pay
-- without getting the part (or get it without paying). The server rolls `partId` beforehand.
function PlayerDataService.buyBundle(
	player: Player,
	price: number,
	partId: string,
	sku: string
): (boolean, string?)
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false, "Your lab is still loading."
	end
	if profile.Data.coins < price then
		return false, `You need {price} coins.`
	end
	if Parts.get(partId) == nil then
		return false, "Something went wrong. Try again!"
	end
	profile.Data.coins -= price
	local balance = profile.Data.coins
	PlayerDataService.addPart(player, partId, 1, true)
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		COIN_CURRENCY,
		price,
		balance,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		sku
	)
	return true, nil
end

function PlayerDataService.isTutorialDone(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Data.tutorialDone
end

local function activeProfile(player: Player): ProfileStore.Profile<PlayerData>?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	return profile
end

-- A new player's first monster, built in the starter pop-up: stitched and out right away, in
-- one step. `loadout` must already be checked (Starters.parse). Only before the first
-- creature, so the pop-up is the first minute of the game and never a free monster later.
function PlayerDataService.createStarter(player: Player, loadout: Types.Loadout): boolean
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	local data = profile.Data
	if data.starterMade or data.tutorialDone or #data.creatures > 0 then
		return false
	end
	settleShelf(data)
	data.starterMade = true
	table.insert(data.creatures, table.clone(loadout))
	data.activeCreature = #data.creatures
	for _, partId in Creatures.partIds(loadout) do
		data.discovered[partId] = true
	end
	local secret = Creatures.findSecret(loadout)
	if secret ~= nil then
		data.secretsFound[secret.id] = true
	end

	sendSnapshot(player)
	notifyActiveChanged(player)
	-- The starter is the player's first part and first creature for the onboarding funnel.
	PlayerDataService.recordMilestone(player, "FirstPart")
	PlayerDataService.recordMilestone(player, "FirstStitch")
	return true
end

-- Finds an egg: marks the spot as found (it comes back for this player after
-- Eggs.respawnHours) and gives the server-rolled part, in one step. The caller (EggService)
-- checks the spot is real and the player is next to it.
function PlayerDataService.collectEgg(
	player: Player,
	spotName: string,
	partId: string
): (boolean, string?)
	local profile = activeProfile(player)
	if profile == nil then
		return false, "Your lab is still loading."
	end
	local data = profile.Data
	local foundAt = data.eggSpots[spotName]
	if foundAt ~= nil and foundAt + Eggs.respawnHours * 3600 > os.time() then
		return false, "You found this egg already. It comes back later!"
	end
	if Parts.get(partId) == nil then
		return false, "Something went wrong. Try again!"
	end
	data.eggSpots[spotName] = os.time()
	PlayerDataService.addPart(player, partId, 1, true)
	return true, nil
end

-- Empties the display shelf into the player's coins. Returns the whole coins paid (0 if none
-- were ready); the fraction stays on the shelf.
function PlayerDataService.collectShelf(player: Player): number
	local profile = activeProfile(player)
	if profile == nil then
		return 0
	end
	local data = profile.Data
	settleShelf(data)
	local coins = math.floor(data.shelfStored)
	if coins < 1 then
		sendSnapshot(player)
		return 0
	end
	data.shelfStored -= coins
	PlayerDataService.addCoins(player, coins, "Shelf")
	return coins
end

function PlayerDataService.isDailyBundleReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Data.dailyBundleDay < Daily.today()
end

-- The free daily bundle: marks today as used and gives the (server-rolled) part in one step.
function PlayerDataService.claimDailyBundle(player: Player, partId: string): (boolean, string?)
	local profile = activeProfile(player)
	if profile == nil then
		return false, "Your lab is still loading."
	end
	local today = Daily.today()
	if profile.Data.dailyBundleDay >= today then
		return false, "Today's free bundle is used. Come back tomorrow!"
	end
	if Parts.get(partId) == nil then
		return false, "Something went wrong. Try again!"
	end
	profile.Data.dailyBundleDay = today
	PlayerDataService.addPart(player, partId, 1, true)
	return true, nil
end

-- Counts how many of each part an offer uses.
local function countOffer(offer: { string }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, partId in offer do
		counts[partId] = (counts[partId] or 0) + 1
	end
	return counts
end

-- Can this player put these loose parts into a trade? Returns (ok, reason).
function PlayerDataService.canOffer(player: Player, offer: { string }): (boolean, string?)
	local profile = activeProfile(player)
	if profile == nil then
		return false, "Your lab is still loading."
	end
	local now = os.time()
	for partId, count in countOffer(offer) do
		if Parts.get(partId) == nil or (profile.Data.inventory[partId] or 0) < count then
			return false, "You don't have that part anymore."
		end
		local lockedUntil = profile.Data.tradeLockUntil[partId]
		if lockedUntil ~= nil and lockedUntil > now then
			local hours = math.ceil((lockedUntil - now) / 3600)
			return false, `That part is too new to trade. Try again in {hours} h.`
		end
	end
	return true, nil
end

-- Swaps two players' offers in one step: every check passes before anything changes, then
-- both inventories change together and both saves are written right away, so a trade can't
-- lose or copy a part. Offers must already be checked lists of part ids.
function PlayerDataService.executeTrade(
	a: Player,
	aGives: { string },
	b: Player,
	bGives: { string }
): (boolean, string?)
	local profileA = activeProfile(a)
	local profileB = activeProfile(b)
	if profileA == nil or profileB == nil then
		return false, "A lab is still loading. Try again!"
	end
	local okA, reasonA = PlayerDataService.canOffer(a, aGives)
	if not okA then
		return false, reasonA
	end
	local okB, reasonB = PlayerDataService.canOffer(b, bGives)
	if not okB then
		return false, reasonB
	end

	local function move(from: PlayerData, to: PlayerData, offer: { string }): ()
		for partId, count in countOffer(offer) do
			local remaining = from.inventory[partId] - count
			from.inventory[partId] = if remaining > 0 then remaining else nil
			to.inventory[partId] = (to.inventory[partId] or 0) + count
			to.discovered[partId] = true
			local definition = Parts.get(partId) :: Types.PartDefinition
			if Trading.lockedRarities[definition.rarity] then
				to.tradeLockUntil[partId] = os.time() + Trading.lockSeconds
			end
		end
	end
	move(profileA.Data, profileB.Data, aGives)
	move(profileB.Data, profileA.Data, bGives)

	for _, profile in { profileA, profileB } do
		pcall(function()
			profile:Save()
		end)
	end
	sendSnapshot(a)
	sendSnapshot(b)
	PlayerDataService.recordMilestone(a, "FirstCoopAction")
	PlayerDataService.recordMilestone(b, "FirstCoopAction")
	return true, nil
end

function PlayerDataService.isIslandUnlocked(player: Player, islandId: string): boolean
	if islandId == Islands.HOME then
		return true
	end
	local profile = profiles[player]
	return profile ~= nil and profile.Data.unlockedIslands[islandId] == true
end

-- Remembers that the player reached an island. Returns true the first time only.
function PlayerDataService.unlockIsland(player: Player, islandId: string): boolean
	local profile = activeProfile(player)
	if
		profile == nil
		or Islands.get(islandId) == nil
		or PlayerDataService.isIslandUnlocked(player, islandId)
	then
		return false
	end
	profile.Data.unlockedIslands[islandId] = true
	sendSnapshot(player)
	return true
end

function PlayerDataService.isChallengeDone(player: Player, challengeId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Data.challengesDone[challengeId] == true
end

-- First completion of a challenge: marks it done and gives its reward part, in one step.
function PlayerDataService.completeChallenge(
	player: Player,
	challengeId: string,
	partId: string
): boolean
	local profile = activeProfile(player)
	if profile == nil or profile.Data.challengesDone[challengeId] then
		return false
	end
	profile.Data.challengesDone[challengeId] = true
	if not PlayerDataService.addPart(player, partId, 1) then
		-- Unknown reward id (a config mistake): undo, so the player can still earn it once fixed.
		profile.Data.challengesDone[challengeId] = nil
		return false
	end
	return true
end

-- Moves the loadout's parts out of the inventory into a new creature and makes it the active
-- one. `loadout` must already be parsed (Creatures.parseLoadout). All checks happen before any
-- change, so a refused stitch never touches the save.
-- Returns (true, nil) or (false, reason) where reason is shown to the player.
function PlayerDataService.stitch(player: Player, loadout: Types.Loadout): (boolean, string?)
	local profile = activeProfile(player)
	if profile == nil then
		return false, "Your lab is still loading."
	end
	local data = profile.Data
	if #data.creatures >= Creatures.MAX_SAVED then
		return false, "Your lab is full! Unstitch a creature first."
	end
	local partIds = Creatures.partIds(loadout)
	for _, partId in partIds do
		if (data.inventory[partId] or 0) < 1 then
			return false, "You don't have that part anymore."
		end
	end

	settleShelf(data)
	for _, partId in partIds do
		local remaining = data.inventory[partId] - 1
		data.inventory[partId] = if remaining > 0 then remaining else nil
	end
	table.insert(data.creatures, table.clone(loadout))
	data.activeCreature = #data.creatures
	local secret = Creatures.findSecret(loadout)
	if secret ~= nil then
		data.secretsFound[secret.id] = true
	end

	sendSnapshot(player)
	notifyActiveChanged(player)
	PlayerDataService.recordMilestone(player, "FirstStitch")
	return true, nil
end

-- Takes a creature apart: its parts go back to the inventory. `index` is untrusted.
function PlayerDataService.unstitch(player: Player, index: unknown): boolean
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	local data = profile.Data
	if not isIndex(index, #data.creatures) or index == 0 then
		return false
	end
	local slotIndex = index :: number

	settleShelf(data)
	local loadout = table.remove(data.creatures, slotIndex) :: Types.Loadout
	for _, partId in Creatures.partIds(loadout) do
		data.inventory[partId] = (data.inventory[partId] or 0) + 1
	end
	if data.activeCreature == slotIndex then
		data.activeCreature = 0
	elseif data.activeCreature > slotIndex then
		data.activeCreature -= 1
	end

	sendSnapshot(player)
	notifyActiveChanged(player)
	return true
end

-- Chooses which creature is out; 0 puts it away. `index` is untrusted.
function PlayerDataService.setActive(player: Player, index: unknown): boolean
	local profile = activeProfile(player)
	if profile == nil or not isIndex(index, #profile.Data.creatures) then
		return false
	end
	if profile.Data.activeCreature == index then
		return true
	end
	settleShelf(profile.Data)
	profile.Data.activeCreature = index :: number
	sendSnapshot(player)
	notifyActiveChanged(player)
	return true
end

-- The creature that should be out right now, or nil. Returns a copy.
function PlayerDataService.getActiveLoadout(player: Player): Types.Loadout?
	local profile = profiles[player]
	if profile == nil or profile.Data.activeCreature == 0 then
		return nil
	end
	local loadout = profile.Data.creatures[profile.Data.activeCreature]
	return if loadout ~= nil then table.clone(loadout) else nil
end

-- Called (on its own thread) whenever a player's active creature may have changed, including
-- right after their save loads.
function PlayerDataService.onActiveCreatureChanged(listener: ActiveListener): ()
	table.insert(activeListeners, listener)
end

function PlayerDataService.start(): ()
	snapshotRemote = Remotes.event("DataSnapshot")
	collectedRemote = Remotes.event("PartCollected")

	-- Only the first ClientReady per player matters; repeats are ignored, so spamming it
	-- costs the server one table lookup.
	Remotes.event("ClientReady").OnServerEvent:Connect(function(player: Player)
		if readyPlayers[player] then
			return
		end
		readyPlayers[player] = true
		sendSnapshot(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players who joined before this ran (common in Studio) would otherwise never load.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Tells you in Output whether saves are real or temporary.
	task.spawn(function()
		while ProfileStore.DataStoreState == "NotReady" do
			task.wait(0.5)
		end
		if ProfileStore.DataStoreState == "Access" then
			print(`[Mashup Monsters] saving to DataStore "{STORE_NAME}"`)
		else
			warn(
				`[Mashup Monsters] saves are TEMPORARY ({ProfileStore.DataStoreState}). In Studio, turn on `
					.. "Game Settings > Security > Enable Studio Access to API Services."
			)
		end
	end)
end

return PlayerDataService
