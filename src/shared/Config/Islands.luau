--!strict
-- Every island, in progression order. The world pieces are built in Studio and point back here
-- by id (string attribute "Island"):
--   * "IslandZone" box parts: where the island is (gates, milestones, the arrival banner)
--   * "IslandArrival" parts: where travel pads drop you
--   * "TravelPad" parts: a pad that takes you to its Island (pads with "MeadowIsle" go home)
-- Ids are saved in player data (unlockedIslands), so never rename one once it has shipped.

local Types = require(script.Parent.Parent.Types)

type IslandDefinition = Types.IslandDefinition

local LIST: { IslandDefinition } = {
	{ id = "MeadowIsle", displayName = "Meadow Isle", order = 1 },
	{ id = "LilyLagoon", displayName = "Lily Lagoon", order = 2, requires = "Swim" },
	{ id = "CliffsidePeaks", displayName = "Cliffside Peaks", order = 3, requires = "SuperJump" },
	{ id = "WindyCanyons", displayName = "Windy Canyons", order = 4, requires = "Glide" },
}

-- Plain-language names for gate messages ("You need Super Jump to get there!").
local ABILITY_NAMES: { [string]: string } = {
	Swim = "Swim",
	SuperJump = "Super Jump",
	Glide = "Glide",
	Light = "Light",
}

local byId: { [string]: IslandDefinition } = {}
for _, island in LIST do
	assert(byId[island.id] == nil, `Duplicate island id "{island.id}" in Islands.luau`)
	byId[island.id] = table.freeze(island)
end

local Islands = {}

Islands.HOME = "MeadowIsle"
Islands.list = table.freeze(LIST)

function Islands.get(id: string): IslandDefinition?
	return byId[id]
end

function Islands.abilityName(ability: string): string
	return ABILITY_NAMES[ability] or ability
end

return table.freeze(Islands)
