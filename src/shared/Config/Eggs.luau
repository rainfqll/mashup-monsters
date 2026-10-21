--!strict
-- Monster eggs (spec 4.8): the rare finds that replaced loose parts lying around. Eggs sit at
-- spots on the outer islands (never on Meadow Isle) and hatch a part from the creature
-- families that live on that island, so where you search decides what you can find.
-- Eggs are personal: each player finds each egg once per `respawnHours`, so friends never race
-- for one. The roll happens on the server (EggService); the odds below are exactly what it uses.
--
-- World pieces (Studio): parts tagged "EggSpot" with string attributes "Island" (island id) and
-- "Tier" (a key of TIERS). A "Treasure" egg instead always hatches its "PartId" attribute: one
-- per island, holding the part that opens the next island, so every starter can go everywhere.
-- Spot names are saved in player data (eggSpots), so each must be unique and never renamed.

local Islands = require(script.Parent.Islands)
local Parts = require(script.Parent.Parts)
local Types = require(script.Parent.Parent.Types)

export type Odds = { rarity: Types.Rarity, weight: number }

export type TierDefinition = {
	displayName: string,
	-- Shell tint, so a shiny egg looks special from far away.
	color: Color3,
	-- Nil for Treasure eggs (they hatch a fixed part).
	odds: { Odds }?,
}

local TIERS: { [string]: TierDefinition } = {
	Plain = {
		displayName = "Monster Egg",
		color = Color3.fromRGB(255, 250, 240),
		odds = {
			{ rarity = "Common", weight = 60 },
			{ rarity = "Uncommon", weight = 30 },
			{ rarity = "Rare", weight = 10 },
		},
	},
	Shiny = {
		displayName = "Shiny Egg",
		color = Color3.fromRGB(255, 205, 70),
		odds = {
			{ rarity = "Uncommon", weight = 30 },
			{ rarity = "Rare", weight = 45 },
			{ rarity = "Epic", weight = 20 },
			{ rarity = "Legendary", weight = 5 },
		},
	},
	Treasure = {
		displayName = "Treasure Egg",
		color = Color3.fromRGB(170, 120, 255),
	},
}

-- Which creature families hatch from eggs on each island. Each island has its own family plus
-- the starter family that opens the next island.
local FAMILIES: { [string]: { string } } = {
	LilyLagoon = { "Tide", "Thunder", "Glowcap" },
	CliffsidePeaks = { "Thunder", "Ember", "Crystal" },
	WindyCanyons = { "Ember", "Tide", "Moss" },
}

for islandId, families in FAMILIES do
	assert(Islands.get(islandId) ~= nil, `Eggs: unknown island "{islandId}"`)
	for _, family in families do
		local found = false
		for _, part in Parts.list do
			found = found or part.family == family
		end
		assert(found, `Eggs: no parts for family "{family}"`)
	end
	table.freeze(families)
end
for _, tier in TIERS do
	if tier.odds ~= nil then
		for _, entry in tier.odds do
			table.freeze(entry)
		end
		table.freeze(tier.odds)
	end
	table.freeze(tier)
end

return table.freeze({
	tiers = table.freeze(TIERS),
	families = table.freeze(FAMILIES),
	-- Hours before a found egg is back for the same player.
	respawnHours = 6,
	-- Studs: how close you must be for the server to accept a find.
	collectDistance = 16,
})
