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
}

export type RarityInfo = {
	order: number,
	color: Color3,
}

-- What the server sends the client about its own save. A copy, never the live save table.
export type PlayerSnapshot = {
	coins: number,
	inventory: { [string]: number },
}

return {}
