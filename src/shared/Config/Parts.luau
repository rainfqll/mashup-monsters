--!strict
-- Every creature part in the game. Adding a part = one entry here plus a model in
-- ReplicatedStorage.PartModels (see tools/build_creature_parts.luau for the model contract).
-- Ids are saved in player data, so never rename or reuse an id once it has shipped; ids that
-- were replaced live in RetiredIds.luau (saves are converted on load) and can't be reused.
-- Stats are 0-5; they are rough first-pass numbers.
--
-- Six fantasy families (World Upgrade, spec 4.8), one part per slot each. The three starter
-- families are all Common and each opens a different first island: Tide (Swim) -> Lily
-- Lagoon, Thunder (Super Jump) -> Cliffside Peaks, Ember (Glide) -> Windy Canyons. The other
-- three are found on the islands: Crystal, Glowcap and Moss.

local RetiredIds = require(script.Parent.RetiredIds)
local Types = require(script.Parent.Parent.Types)

type PartDefinition = Types.PartDefinition

local function stats(
	speed: number,
	jump: number,
	swim: number,
	glide: number,
	carry: number
): Types.PartStats
	return { speed = speed, jump = jump, swim = swim, glide = glide, carry = carry }
end

local EMBER = Color3.fromRGB(255, 115, 50)
local TIDE = Color3.fromRGB(110, 215, 235)
local THUNDER = Color3.fromRGB(255, 220, 60)
local CRYSTAL = Color3.fromRGB(165, 110, 255)
local GLOWCAP = Color3.fromRGB(120, 170, 255)
local MOSS = Color3.fromRGB(110, 175, 80)

local LIST: { PartDefinition } = {
	-- Free starter body: used whenever a creature's Body slot is empty.
	{
		id = "StitchyBlob",
		displayName = "Stitchy Blob",
		slot = "Body",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 0, 0, 0, 0),
		modelName = "StitchyBlob",
		colorTheme = Color3.fromRGB(190, 165, 240),
		free = true,
	},

	-- Ember Drake (starter): a little fire dragon whose wings glide.
	{
		id = "EmberHead",
		displayName = "Ember Head",
		slot = "Head",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 0, 1, 0),
		modelName = "EmberHead",
		colorTheme = EMBER,
		family = "Ember",
	},
	{
		id = "EmberBody",
		displayName = "Ember Body",
		slot = "Body",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 0, 0, 1, 1),
		modelName = "EmberBody",
		colorTheme = EMBER,
		family = "Ember",
	},
	{
		id = "EmberLegs",
		displayName = "Ember Legs",
		slot = "Legs",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 1, 0, 0, 0),
		modelName = "EmberLegs",
		colorTheme = EMBER,
		family = "Ember",
	},
	{
		id = "EmberWings",
		displayName = "Ember Wings",
		slot = "Back",
		rarity = "Common",
		abilities = { "Glide" },
		stats = stats(0, 0, 0, 3, 0),
		modelName = "EmberWings",
		colorTheme = EMBER,
		family = "Ember",
	},

	-- Tide Axolotl (starter): a water friend whose tail swims.
	{
		id = "TideHead",
		displayName = "Tide Head",
		slot = "Head",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 0, 1, 0, 0),
		modelName = "TideHead",
		colorTheme = TIDE,
		family = "Tide",
	},
	{
		id = "TideBody",
		displayName = "Tide Body",
		slot = "Body",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 0, 1, 0, 1),
		modelName = "TideBody",
		colorTheme = TIDE,
		family = "Tide",
	},
	{
		id = "TideLegs",
		displayName = "Tide Legs",
		slot = "Legs",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 1, 0, 0),
		modelName = "TideLegs",
		colorTheme = TIDE,
		family = "Tide",
	},
	{
		id = "TideTail",
		displayName = "Tide Tail",
		slot = "Back",
		rarity = "Common",
		abilities = { "Swim" },
		stats = stats(0, 0, 3, 0, 0),
		modelName = "TideTail",
		colorTheme = TIDE,
		family = "Tide",
	},

	-- Thunder Hare (starter): a speedy hare whose legs super jump.
	{
		id = "ThunderHead",
		displayName = "Thunder Head",
		slot = "Head",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 0, 0, 0),
		modelName = "ThunderHead",
		colorTheme = THUNDER,
		family = "Thunder",
	},
	{
		id = "ThunderBody",
		displayName = "Thunder Body",
		slot = "Body",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 1, 0, 0, 0),
		modelName = "ThunderBody",
		colorTheme = THUNDER,
		family = "Thunder",
	},
	{
		id = "ThunderLegs",
		displayName = "Thunder Legs",
		slot = "Legs",
		rarity = "Common",
		abilities = { "SuperJump" },
		stats = stats(1, 3, 0, 0, 0),
		modelName = "ThunderLegs",
		colorTheme = THUNDER,
		family = "Thunder",
	},
	{
		id = "ThunderTail",
		displayName = "Thunder Tail",
		slot = "Back",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 0, 0, 0),
		modelName = "ThunderTail",
		colorTheme = THUNDER,
		family = "Thunder",
	},

	-- Crystal Beetle (Cliffside Peaks): sturdy, climbs, and its shell shields.
	{
		id = "CrystalHead",
		displayName = "Crystal Head",
		slot = "Head",
		rarity = "Uncommon",
		abilities = {},
		stats = stats(0, 0, 0, 0, 1),
		modelName = "CrystalHead",
		colorTheme = CRYSTAL,
		family = "Crystal",
	},
	{
		id = "CrystalBody",
		displayName = "Crystal Body",
		slot = "Body",
		rarity = "Rare",
		abilities = {},
		stats = stats(0, 0, 0, 0, 2),
		modelName = "CrystalBody",
		colorTheme = CRYSTAL,
		family = "Crystal",
	},
	{
		id = "CrystalLegs",
		displayName = "Crystal Legs",
		slot = "Legs",
		rarity = "Uncommon",
		abilities = { "Climb" },
		stats = stats(0, 1, 0, 0, 1),
		modelName = "CrystalLegs",
		colorTheme = CRYSTAL,
		family = "Crystal",
	},
	{
		-- First reward of the Cliffside summit chest.
		id = "CrystalShell",
		displayName = "Crystal Shell",
		slot = "Back",
		rarity = "Rare",
		abilities = { "Shield" },
		stats = stats(0, 0, 1, 0, 2),
		modelName = "CrystalShell",
		colorTheme = CRYSTAL,
		family = "Crystal",
	},

	-- Glowcap Moth (Lily Lagoon): lights the dark and spots hidden things.
	{
		id = "GlowcapHead",
		displayName = "Glowcap Head",
		slot = "Head",
		rarity = "Rare",
		abilities = { "Reveal" },
		stats = stats(0, 0, 0, 1, 0),
		modelName = "GlowcapHead",
		colorTheme = GLOWCAP,
		family = "Glowcap",
	},
	{
		id = "GlowcapBody",
		displayName = "Glowcap Body",
		slot = "Body",
		rarity = "Epic",
		abilities = { "Light" },
		stats = stats(1, 0, 0, 1, 0),
		modelName = "GlowcapBody",
		colorTheme = GLOWCAP,
		family = "Glowcap",
	},
	{
		id = "GlowcapLegs",
		displayName = "Glowcap Legs",
		slot = "Legs",
		rarity = "Uncommon",
		abilities = {},
		stats = stats(1, 1, 0, 0, 0),
		modelName = "GlowcapLegs",
		colorTheme = GLOWCAP,
		family = "Glowcap",
	},
	{
		-- Legendary: the Windy Canyons ring course (bundles never roll Legendary).
		id = "GlowcapWings",
		displayName = "Glowcap Wings",
		slot = "Back",
		rarity = "Legendary",
		abilities = { "Glide", "Glow" },
		stats = stats(2, 0, 0, 5, 0),
		modelName = "GlowcapWings",
		colorTheme = GLOWCAP,
		family = "Glowcap",
	},

	-- Moss Golem (Windy Canyons): strong, digs, and carries a whole garden on its back.
	{
		id = "MossHead",
		displayName = "Moss Head",
		slot = "Head",
		rarity = "Epic",
		abilities = { "Dig" },
		stats = stats(0, 1, 0, 0, 2),
		modelName = "MossHead",
		colorTheme = MOSS,
		family = "Moss",
	},
	{
		id = "MossBody",
		displayName = "Moss Body",
		slot = "Body",
		rarity = "Legendary",
		abilities = { "Carry" },
		stats = stats(0, 0, 0, 0, 4),
		modelName = "MossBody",
		colorTheme = MOSS,
		family = "Moss",
	},
	{
		id = "MossLegs",
		displayName = "Moss Legs",
		slot = "Legs",
		rarity = "Rare",
		abilities = { "Climb" },
		-- Jump stays low: without Super Jump, the best jump stat (with a full set) must stay
		-- under the 12-stud Cliffside ledges.
		stats = stats(0, 1, 0, 0, 2),
		modelName = "MossLegs",
		colorTheme = MOSS,
		family = "Moss",
	},
	{
		id = "MossBack",
		displayName = "Moss Back",
		slot = "Back",
		rarity = "Mythic",
		abilities = { "Shield", "Glow" },
		stats = stats(0, 0, 1, 0, 3),
		modelName = "MossBack",
		colorTheme = MOSS,
		family = "Moss",
	},
}

local byId: { [string]: PartDefinition } = {}
for _, part in LIST do
	assert(byId[part.id] == nil, `Duplicate part id "{part.id}" in Parts.luau`)
	assert(RetiredIds.parts[part.id] == nil, `Part id "{part.id}" was retired; pick a new id`)
	table.freeze(part.abilities)
	table.freeze(part.stats)
	byId[part.id] = table.freeze(part)
end
for oldId, newId in RetiredIds.parts do
	assert(byId[newId] ~= nil, `RetiredIds: "{oldId}" points to unknown part "{newId}"`)
end

local Parts = {}

Parts.list = table.freeze(LIST)

-- Returns nil for unknown ids, so callers handling client or save input must check.
function Parts.get(id: string): PartDefinition?
	return byId[id]
end

return table.freeze(Parts)
