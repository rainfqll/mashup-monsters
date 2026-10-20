--!strict
-- Shared type vocabulary from docs/GAME_DESIGN.md section 4.2.
-- Literal unions (not plain strings) so a typo like "Lgs" is a type error, not a silent bug.

export type Slot = "Head" | "Body" | "Legs" | "Back"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

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
	ability: string?,
	stats: PartStats,
	modelName: string,
	colorTheme: Color3,
}

return {}
