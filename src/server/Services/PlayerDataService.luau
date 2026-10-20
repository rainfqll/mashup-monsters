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

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

-- Bump CURRENT_VERSION and add a step to migrate() whenever the save shape changes.
local CURRENT_VERSION = 1

export type PlayerData = {
	version: number,
	coins: number,
	-- partId -> how many the player owns
	inventory: { [string]: number },
}

local TEMPLATE: PlayerData = {
	version = CURRENT_VERSION,
	coins = 0,
	inventory = {},
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

local function isCount(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- Upgrades older saves step by step. Version 1 is the first, so there is nothing to upgrade yet.
local function migrate(data: PlayerData): ()
	if data.version > CURRENT_VERSION then
		-- Saved by a newer server build; leave it untouched rather than downgrading it.
		warn(
			`[Mashup Monsters] save version {data.version} is newer than this server ({CURRENT_VERSION})`
		)
		return
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
end

local function sendSnapshot(player: Player): ()
	local profile = profiles[player]
	if profile == nil or not readyPlayers[player] then
		return
	end
	local snapshot: Types.PlayerSnapshot = {
		coins = profile.Data.coins,
		inventory = table.clone(profile.Data.inventory),
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

	sendSnapshot(player)
	collectedRemote:FireClient(player, partId)
	return true
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
