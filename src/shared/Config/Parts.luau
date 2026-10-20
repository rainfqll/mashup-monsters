--!strict
-- Every creature part in the game. Adding a part = one entry here plus a model in
-- ReplicatedStorage.PartModels (see tools/build_part_models.luau for the model contract).
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
		animal = "Duck",
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
		animal = "Mole",
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
		animal = "Owl",
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
		animal = "Firefly",
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
		animal = "Pig",
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
		animal = "Snail",
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
		animal = "Bear",
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
		animal = "Frog",
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
		animal = "Duck",
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
		animal = "Frog",
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
		animal = "Cheetah",
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
		animal = "Chicken",
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
		animal = "Pig",
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
		animal = "Turtle",
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
		animal = "Bat",
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
		animal = "Jellyfish",
	},

	-- Phase 4: Cliffside Peaks and Windy Canyons. Each new animal has 2 parts so set bonuses work.
	{
		id = "GoatHorns",
		displayName = "Goat Horns",
		slot = "Head",
		rarity = "Common",
		abilities = {},
		stats = stats(0, 1, 0, 0, 1),
		modelName = "GoatHorns",
		colorTheme = Color3.fromRGB(235, 230, 220),
		animal = "Goat",
	},
	{
		id = "BatEars",
		displayName = "Bat Ears",
		slot = "Head",
		rarity = "Uncommon",
		abilities = {},
		stats = stats(0, 0, 0, 1, 0),
		modelName = "BatEars",
		colorTheme = Color3.fromRGB(110, 85, 140),
		animal = "Bat",
	},
	{
		id = "EagleHead",
		displayName = "Eagle Head",
		slot = "Head",
		rarity = "Epic",
		abilities = {},
		stats = stats(1, 0, 0, 2, 0),
		modelName = "EagleHead",
		colorTheme = Color3.fromRGB(250, 250, 245),
		animal = "Eagle",
	},
	{
		id = "ChickenBody",
		displayName = "Chicken Body",
		slot = "Body",
		rarity = "Uncommon",
		abilities = {},
		stats = stats(0, 1, 0, 1, 0),
		modelName = "ChickenBody",
		colorTheme = Color3.fromRGB(250, 245, 235),
		animal = "Chicken",
	},
	{
		id = "CheetahBody",
		displayName = "Cheetah Body",
		slot = "Body",
		rarity = "Rare",
		abilities = { "Speed" },
		stats = stats(2, 1, 0, 0, 0),
		modelName = "CheetahBody",
		colorTheme = Color3.fromRGB(240, 180, 60),
		animal = "Cheetah",
	},
	{
		-- A second way to super jump, found on Cliffside Peaks.
		id = "GoatLegs",
		displayName = "Goat Legs",
		slot = "Legs",
		rarity = "Uncommon",
		abilities = { "SuperJump" },
		stats = stats(0, 3, 0, 0, 1),
		modelName = "GoatLegs",
		colorTheme = Color3.fromRGB(235, 230, 220),
		animal = "Goat",
	},
	{
		-- First reward of the Cliffside summit chest.
		id = "OwlWings",
		displayName = "Owl Wings",
		slot = "Back",
		rarity = "Rare",
		abilities = { "Glide" },
		stats = stats(0, 0, 0, 3, 0),
		modelName = "OwlWings",
		colorTheme = Color3.fromRGB(180, 130, 70),
		animal = "Owl",
	},
	{
		-- Legendary: only from the Windy Canyons ring course (bundles never roll Legendary).
		id = "EagleWings",
		displayName = "Eagle Wings",
		slot = "Back",
		rarity = "Legendary",
		abilities = { "Glide", "Speed" },
		stats = stats(2, 0, 0, 5, 0),
		modelName = "EagleWings",
		colorTheme = Color3.fromRGB(120, 80, 50),
		animal = "Eagle",
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
