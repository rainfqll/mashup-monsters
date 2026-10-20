--!strict
-- Rarity tiers in ascending order. `order` drives sorting in the UI; `color` is used for card
-- borders, pickup glow and (Phase 3) the reveal burst, so every screen agrees on what "Rare" looks like.

local Types = require(script.Parent.Parent.Types)

local Rarities: { [Types.Rarity]: Types.RarityInfo } = {
	Common = { order = 1, color = Color3.fromRGB(205, 210, 220) },
	Uncommon = { order = 2, color = Color3.fromRGB(110, 220, 70) },
	Rare = { order = 3, color = Color3.fromRGB(60, 150, 255) },
	Epic = { order = 4, color = Color3.fromRGB(175, 85, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40) },
	Mythic = { order = 6, color = Color3.fromRGB(255, 80, 140) },
	Secret = { order = 7, color = Color3.fromRGB(60, 240, 225) },
}

return table.freeze(Rarities)
