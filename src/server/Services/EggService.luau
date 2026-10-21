--!strict
-- EggService: monster eggs on the outer islands (Config/Eggs). Each client draws the eggs it may
-- still find and asks when its character touches one (CollectEgg); the server checks the spot is
-- real and that the player is next to it, rolls the part from that island's creature families,
-- and saves the find (PlayerDataService.collectEgg).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SPOT_TAG = "EggSpot"

-- spot name -> spot part, from the tagged parts at startup (names are save keys).
local spots: { [string]: BasePart } = {}
local random = Random.new()

-- An island's egg parts grouped by rarity.
local poolByIsland: { [string]: { [Types.Rarity]: { string } } } = {}
for islandId, families in Eggs.families do
	local pool: { [Types.Rarity]: { string } } = {}
	for _, part in Parts.list do
		if not part.free and part.family ~= nil and table.find(families, part.family) then
			local list = pool[part.rarity] or {}
			table.insert(list, part.id)
			pool[part.rarity] = list
		end
	end
	poolByIsland[islandId] = pool
end

local function rollRarity(odds: { Eggs.Odds }): Types.Rarity
	local total = 0
	for _, entry in odds do
		total += entry.weight
	end
	local pick = random:NextNumber(0, total)
	for _, entry in odds do
		pick -= entry.weight
		if pick <= 0 then
			return entry.rarity
		end
	end
	return odds[#odds].rarity
end

-- A part of the rolled rarity from this island's families. If the island has none of that
-- rarity, the nearest rarity it does have (a tie goes to the rarer one, so shiny eggs never
-- turn plain).
local function rollPart(islandId: string, odds: { Eggs.Odds }): string?
	local pool = poolByIsland[islandId]
	if pool == nil then
		return nil
	end
	local wanted = Rarities[rollRarity(odds)].order
	local bestRarity: Types.Rarity? = nil
	local bestScore = math.huge
	for rarity, list in pool do
		if #list > 0 then
			local order = Rarities[rarity].order
			-- Distance first; the small bonus breaks ties toward rarer.
			local score = math.abs(order - wanted) - order * 0.01
			if score < bestScore then
				bestScore = score
				bestRarity = rarity
			end
		end
	end
	if bestRarity == nil then
		return nil
	end
	local list = pool[bestRarity]
	return list[random:NextInteger(1, #list)]
end

local function onCollectEgg(player: Player, spotName: unknown): (string?, string?)
	if type(spotName) ~= "string" or not RateLimit.allow(player, "CollectEgg", 0.3) then
		return nil, nil
	end
	local spot = spots[spotName]
	if spot == nil then
		return nil, nil
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if
		root == nil
		or not root:IsA("BasePart")
		or (root.Position - spot.Position).Magnitude > Eggs.collectDistance
	then
		return nil, nil
	end

	local tier = Eggs.tiers[spot:GetAttribute("Tier") :: string]
	local odds = tier.odds
	local partId = if odds ~= nil
		then rollPart(spot:GetAttribute("Island") :: string, odds)
		else spot:GetAttribute("PartId") :: string
	if partId == nil then
		return nil, "Something went wrong. Try again!"
	end
	local ok, reason = PlayerDataService.collectEgg(player, spotName, partId)
	if not ok then
		return nil, reason
	end
	return partId, nil
end

local EggService = {}

function EggService.start(): ()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		local tierName = spot:GetAttribute("Tier")
		local tier = if type(tierName) == "string" then Eggs.tiers[tierName] else nil
		local islandId = spot:GetAttribute("Island")
		local partId = spot:GetAttribute("PartId")
		local valid = spot:IsA("BasePart")
			and tier ~= nil
			and (
				if tier.odds ~= nil
					then type(islandId) == "string" and poolByIsland[islandId] ~= nil
					else type(partId) == "string" and Parts.get(partId) ~= nil
			)
		if not valid then
			warn(`[Mashup Monsters] egg spot {spot:GetFullName()} has a bad Tier, Island or PartId`)
		elseif spots[spot.Name] ~= nil then
			warn(`[Mashup Monsters] two egg spots are named "{spot.Name}"; names must be unique`)
		else
			spots[spot.Name] = spot :: BasePart
		end
	end
	Remotes.func("CollectEgg").OnServerInvoke = onCollectEgg
end

return EggService
