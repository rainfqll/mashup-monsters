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
	-- Which creature family the part comes from (Ember, Tide, ...). 2+ parts of one family on a
	-- creature give a set bonus.
	family: string?,
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
	-- Includes set bonuses.
	stats: PartStats,
	-- Families with 2+ parts on this creature (set bonuses), sorted.
	sets: { string },
	-- Secret Mashup id (Config/Combos) if the parts match a recipe.
	secret: string?,
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
	-- Config/Starters id of the starter monster chosen at the stand, "" = none yet
	starterChosen: string,
	-- egg spot name -> os.time() this player last found it (Config/Eggs)
	eggSpots: { [string]: number },
	funnel: { [string]: true },
	unlockedIslands: { [string]: true },
	challengesDone: { [string]: true },
	secretsFound: { [string]: true },
	-- UTC day of the last free daily bundle (Daily.today()), 0 = never
	dailyBundleDay: number,
	-- Display shelf: coins waiting, coins per hour now, the cap, and when `shelfStored` was
	-- worked out (os.time()), so the client can count up between snapshots.
	shelfStored: number,
	shelfRate: number,
	shelfCap: number,
	shelfUpdatedAt: number,
	-- partId -> os.time() until which that part can't be traded (fresh Legendary+ finds)
	tradeLockUntil: { [string]: number },
}

-- One open trade as one player sees it (sent by TradeService).
export type TradeView = {
	partnerUserId: number,
	partnerName: string,
	myOffer: { string },
	theirOffer: { string },
	myReady: boolean,
	theirReady: boolean,
	-- Seconds left on the final countdown, or nil when it is not running.
	countdown: number?,
	-- Short status line, e.g. "Trade done!" or why something was refused.
	message: string?,
}

return {}
