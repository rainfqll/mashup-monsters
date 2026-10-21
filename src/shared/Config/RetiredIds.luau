--!strict
-- Ids that shipped in saves and were later replaced, with what they became. Player data is
-- converted on load (PlayerDataService migrate, save v6), and Parts.luau / Combos.luau refuse
-- to reuse any of these ids, so an old save can never turn into the wrong thing.
--
-- v6 (World Upgrade): the farm animals became the six fantasy families. Each old part maps to
-- a new part of the same slot, matching rarity or ability where possible.

local PARTS: { [string]: string } = {
	-- Head
	DuckHead = "TideHead",
	GoatHorns = "EmberHead",
	BatEars = "ThunderHead",
	MoleNose = "CrystalHead",
	OwlHead = "GlowcapHead",
	FireflyHead = "MossHead",
	EagleHead = "MossHead",
	-- Body
	PigBody = "TideBody",
	ChickenBody = "EmberBody",
	CheetahBody = "ThunderBody",
	SnailBody = "CrystalBody",
	BearBody = "CrystalBody",
	FrogBody = "GlowcapBody",
	-- Legs
	DuckFeet = "TideLegs",
	FrogLegs = "ThunderLegs",
	GoatLegs = "ThunderLegs",
	ChickenLegs = "GlowcapLegs",
	CheetahLegs = "MossLegs",
	-- Back
	PigTail = "ThunderTail",
	JellyfishTail = "TideTail",
	BatWings = "EmberWings",
	OwlWings = "EmberWings",
	TurtleShell = "CrystalShell",
	EagleWings = "GlowcapWings",
}

local SECRETS: { [string]: string } = {
	MountainKing = "GemGuardian",
	NightHopper = "StormRunner",
	SkyRacer = "SteamDragon",
	LanternJelly = "MoonLantern",
	PuddlePrince = "PuddleHopper",
}

return table.freeze({
	parts = table.freeze(PARTS),
	secrets = table.freeze(SECRETS),
})
