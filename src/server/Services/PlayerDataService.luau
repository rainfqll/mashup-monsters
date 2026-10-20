--!strict
-- PlayerDataService: the only module that reads or writes saved player data. Keeping saves
-- behind one owner is what makes session locking and safe saving possible.
--
-- ProfileStore does the hard parts: a session lock (one server owns a save at a time, so two
-- servers can't overwrite each other), autosave every few minutes, retries, and a final save
-- on leave and on server shutdown (it binds BindToClose itself).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

-- Bump CURRENT_VERSION and add a step to migrate() whenever the save shape changes.
local CURRENT_VERSION = 2

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
}

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	coins = 0,
	inventory = {},
	creatures = {},
	activeCreature = 0,
	discovered = {},
}

-- Studio gets its own store so testing never touches real players' saves.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"

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

	for partId, value in data.discovered do
		if type(partId) ~= "string" or value ~= true then
			data.discovered[partId] = nil
		end
	end
end

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

local PlayerDataService = {}

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- The single way to give parts. `partId` must be a real part; returns false (and gives
-- nothing) if it is unknown or the player's save is not loaded, so callers can keep the item.
function PlayerDataService.addPart(player: Player, partId: string, amount: number): boolean
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

	sendSnapshot(player)
	collectedRemote:FireClient(player, partId)
	return true
end

local function activeProfile(player: Player): ProfileStore.Profile<PlayerData>?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	return profile
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

	for _, partId in partIds do
		local remaining = data.inventory[partId] - 1
		data.inventory[partId] = if remaining > 0 then remaining else nil
	end
	table.insert(data.creatures, table.clone(loadout))
	data.activeCreature = #data.creatures

	sendSnapshot(player)
	notifyActiveChanged(player)
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
