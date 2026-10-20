--!strict
-- Every creature part in the game. Adding a part = one entry here (plus a model in Phase 2).
-- Ids are saved in player data, so never rename or reuse an id once it has shipped.
-- Stats are 0-5 and only matter from Phase 2 on; they are rough first-pass numbers.

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

local LIST: { PartDefinition } = {
	-- Head
	{
		id = "DuckHead",
		displayName = "Duck Head",
		slot = "Head",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 1, 0, 0),
		modelName = "DuckHead",
		colorTheme = Color3.fromRGB(255, 220, 60),
	},
	{
		id = "MoleNose",
		displayName = "Mole Nose",
		slot = "Head",
		rarity = "Uncommon",
		abilities = { "Dig" },
		stats = stats(0, 0, 0, 0, 1),
		modelName = "MoleNose",
		colorTheme = Color3.fromRGB(150, 100, 80),
	},
	{
		id = "OwlHead",
		displayName = "Owl Head",
		slot = "Head",
		rarity = "Rare",
		abilities = { "Reveal" },
		stats = stats(0, 0, 0, 1, 0),
		modelName = "OwlHead",
		colorTheme = Color3.fromRGB(180, 130, 70),
	},
	{
		id = "FireflyHead",
		displayName = "Firefly Head",
		slot = "Head",
		rarity = "Epic",
		abilities = { "Light" },
		stats = stats(1, 0, 0, 1, 0),
		modelName = "FireflyHead",
		colorTheme = Color3.fromRGB(240, 255, 110),
	},

	-- Body
	{
		id = "PigBody",
		displayName = "Pig Body",
		slot = "Body",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 0, 0, 0, 1),
		modelName = "PigBody",
		colorTheme = Color3.fromRGB(255, 160, 190),
	},
	{
		id = "SnailBody",
		displayName = "Snail Body",
		slot = "Body",
		rarity = "Uncommon",
		abilities = { "Climb" },
		stats = stats(0, 0, 0, 0, 1),
		modelName = "SnailBody",
		colorTheme = Color3.fromRGB(200, 170, 230),
	},
	{
		id = "BearBody",
		displayName = "Bear Body",
		slot = "Body",
		rarity = "Rare",
		abilities = { "Carry" },
		stats = stats(0, 0, 0, 0, 3),
		modelName = "BearBody",
		colorTheme = Color3.fromRGB(140, 90, 60),
	},
	{
		id = "FrogBody",
		displayName = "Frog Body",
		slot = "Body",
		rarity = "Epic",
		abilities = {},
		stats = stats(1, 2, 2, 0, 0),
		modelName = "FrogBody",
		colorTheme = Color3.fromRGB(90, 200, 90),
	},

	-- Legs
	{
		id = "DuckFeet",
		-- Common on purpose: swimming opens Lily Lagoon, the second island.
		displayName = "Duck Feet",
		slot = "Legs",
		rarity = "Common",
		abilities = { "Swim" },
		stats = stats(0, 0, 2, 0, 0),
		modelName = "DuckFeet",
		colorTheme = Color3.fromRGB(255, 150, 40),
	},
	{
		id = "FrogLegs",
		displayName = "Frog Legs",
		slot = "Legs",
		rarity = "Uncommon",
		abilities = { "SuperJump" },
		stats = stats(0, 3, 1, 0, 0),
		modelName = "FrogLegs",
		colorTheme = Color3.fromRGB(60, 180, 70),
	},
	{
		id = "CheetahLegs",
		displayName = "Cheetah Legs",
		slot = "Legs",
		rarity = "Rare",
		abilities = { "Speed" },
		stats = stats(3, 1, 0, 0, 0),
		modelName = "CheetahLegs",
		colorTheme = Color3.fromRGB(240, 180, 60),
	},
	{
		id = "ChickenLegs",
		displayName = "Chicken Legs",
		slot = "Legs",
		rarity = "Epic",
		abilities = {},
		stats = stats(2, 2, 0, 1, 0),
		modelName = "ChickenLegs",
		colorTheme = Color3.fromRGB(255, 200, 80),
	},

	-- Back
	{
		id = "PigTail",
		displayName = "Pig Tail",
		slot = "Back",
		rarity = "Common",
		abilities = {},
		stats = stats(1, 0, 0, 0, 0),
		modelName = "PigTail",
		colorTheme = Color3.fromRGB(255, 140, 180),
	},
	{
		id = "TurtleShell",
		displayName = "Turtle Shell",
		slot = "Back",
		rarity = "Uncommon",
		abilities = { "Shield" },
		stats = stats(0, 0, 1, 0, 1),
		modelName = "TurtleShell",
		colorTheme = Color3.fromRGB(70, 150, 90),
	},
	{
		id = "BatWings",
		displayName = "Bat Wings",
		slot = "Back",
		rarity = "Rare",
		abilities = { "Glide" },
		stats = stats(0, 0, 0, 3, 0),
		modelName = "BatWings",
		colorTheme = Color3.fromRGB(90, 70, 120),
	},
	{
		id = "JellyfishTail",
		displayName = "Jellyfish Tail",
		slot = "Back",
		rarity = "Epic",
		abilities = { "Swim", "Glow" },
		stats = stats(0, 0, 3, 1, 0),
		modelName = "JellyfishTail",
		colorTheme = Color3.fromRGB(150, 220, 255),
	},
}

local byId: { [string]: PartDefinition } = {}
for _, part in LIST do
	assert(byId[part.id] == nil, `Duplicate part id "{part.id}" in Parts.luau`)
	table.freeze(part.abilities)
	table.freeze(part.stats)
	byId[part.id] = table.freeze(part)
end

local Parts = {}

Parts.list = table.freeze(LIST)

-- Returns nil for unknown ids, so callers handling client or save input must check.
function Parts.get(id: string): PartDefinition?
	return byId[id]
end

return table.freeze(Parts)
