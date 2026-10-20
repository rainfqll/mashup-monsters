--!strict
-- Shared type vocabulary from docs/GAME_DESIGN.md section 4.2.
-- Literal unions (not plain strings) so a typo like "Lgs" is a type error, not a silent bug.

export type Slot = "Head" | "Body" | "Legs" | "Back"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

-- Movement and world abilities a part can grant (spec 4.2). Behaviour arrives in Phase 2.
export type Ability =
	"Swim"
	| "SuperJump"
	| "Speed"
	| "Glide"
	| "Light"
	| "Dig"
	| "Reveal"
	| "Climb"
	| "Carry"
	| "Shield"
	| "Glow"

export type PartStats = {
	speed: number,
	jump: number,
	swim: number,
	glide: number,
	carry: number,
}

export type PartDefinition = {
	id: string,
	displayName: string,
	slot: Slot,
	rarity: Rarity,
	abilities: { Ability },
	stats: PartStats,
	modelName: string,
	colorTheme: Color3,
	-- Free parts (the Stitchy Blob body) are owned by everyone, never run out, and never drop.
	free: boolean?,
	-- Which animal the part comes from. 2+ parts of one animal on a creature give a set bonus.
	animal: string?,
}

-- One island (Config/Islands). `requires` is the ability that gets you there the first time;
-- after that, the travel pads at the lab take you straight there.
export type IslandDefinition = {
	id: string,
	displayName: string,
	order: number,
	requires: Ability?,
}

export type RarityInfo = {
	order: number,
	color: Color3,
}

-- Which part sits in each slot of a creature. Any slot may be empty; an empty Body means the
-- free Stitchy Blob.
export type Loadout = {
	Head: string?,
	Body: string?,
	Legs: string?,
	Back: string?,
}

export type CreatureSummary = {
	name: string,
	abilities: { [Ability]: true },
	stats: PartStats,
}

-- What the server sends the client about its own save. A copy, never the live save table.
export type PlayerSnapshot = {
	coins: number,
	inventory: { [string]: number },
	creatures: { Loadout },
	-- Index into `creatures` of the one that is out, or 0 for none.
	activeCreature: number,
	discovered: { [string]: true },
	tutorialDone: boolean,
	starterCollected: { [string]: true },
	funnel: { [string]: true },
	unlockedIslands: { [string]: true },
	challengesDone: { [string]: true },
}

return {}
