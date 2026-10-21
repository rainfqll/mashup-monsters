--!strict
-- The starter monsters new players choose from at the stand on Meadow Isle (spec 4.8). Each is a
-- whole creature of one starter family, and each opens a different first island, so the first
-- trip out depends on the choice. Finding the other families' parts opens the rest.
-- World pieces (Studio): parts tagged "StarterPedestal" with a string attribute "Starter" (id),
-- turned to face where players come from (the creature on top faces the pedestal's front).
-- Ids are saved in player data (starterChosen), so never rename one once it has shipped.

local Islands = require(script.Parent.Islands)
local Parts = require(script.Parent.Parts)
local Types = require(script.Parent.Parent.Types)

export type StarterDefinition = {
	id: string,
	displayName: string,
	loadout: Types.Loadout,
	-- What it can do (shown on its sign) and the island that ability opens first.
	ability: Types.Ability,
	island: string,
	color: Color3,
}

local LIST: { StarterDefinition } = {
	{
		id = "Splash",
		displayName = "Splash",
		loadout = { Head = "TideHead", Body = "TideBody", Legs = "TideLegs", Back = "TideTail" },
		ability = "Swim",
		island = "LilyLagoon",
		color = Color3.fromRGB(110, 215, 235),
	},
	{
		id = "Zippy",
		displayName = "Zippy",
		loadout = {
			Head = "ThunderHead",
			Body = "ThunderBody",
			Legs = "ThunderLegs",
			Back = "ThunderTail",
		},
		ability = "SuperJump",
		island = "CliffsidePeaks",
		color = Color3.fromRGB(255, 220, 60),
	},
	{
		id = "Ember",
		displayName = "Ember",
		loadout = {
			Head = "EmberHead",
			Body = "EmberBody",
			Legs = "EmberLegs",
			Back = "EmberWings",
		},
		ability = "Glide",
		island = "WindyCanyons",
		color = Color3.fromRGB(255, 115, 50),
	},
}

local byId: { [string]: StarterDefinition } = {}
for _, starter in LIST do
	assert(byId[starter.id] == nil, `Duplicate starter id "{starter.id}"`)
	local island = Islands.get(starter.island)
	assert(
		island ~= nil and island.requires == starter.ability,
		`Starter "{starter.id}": island mismatch`
	)
	local hasAbility = false
	for slot, partId in starter.loadout :: { [string]: string } do
		local part = Parts.get(partId)
		assert(
			part ~= nil and part.slot == slot,
			`Starter "{starter.id}": {partId} is not a {slot} part`
		)
		if table.find(part.abilities, starter.ability) then
			hasAbility = true
		end
	end
	assert(hasAbility, `Starter "{starter.id}" can't {starter.ability}`)
	table.freeze(starter.loadout)
	byId[starter.id] = table.freeze(starter)
end

local Starters = {}

Starters.list = table.freeze(LIST)

function Starters.get(id: unknown): StarterDefinition?
	return if type(id) == "string" then byId[id] else nil
end

return table.freeze(Starters)
