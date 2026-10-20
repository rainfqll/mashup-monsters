--!strict
-- Mystery bundles (coins only). The server rolls a rarity by these weights, then picks a part of
-- that rarity at random. The same table is shown to players as drop chances, so what the
-- machine says is exactly what the code does.

local Types = require(script.Parent.Parent.Types)

export type Odds = { rarity: Types.Rarity, weight: number }

return table.freeze({
	price = 50,
	-- Weights add up to 100 so they read directly as percentages.
	odds = table.freeze({
		{ rarity = "Common", weight = 55 },
		{ rarity = "Uncommon", weight = 28 },
		{ rarity = "Rare", weight = 13 },
		{ rarity = "Epic", weight = 4 },
	} :: { Odds }),
	-- Analytics item name for the purchase.
	sku = "MysteryBundle",
	-- Within its rarity, the Part of the Day (Daily.luau) is this many times as likely as each
	-- other part. Rarity chances stay exactly as shown.
	partOfTheDayWeight = 3,
	-- Coins per coin pickup, and how long a taken coin takes to come back.
	coinPickupValue = 5,
	coinRespawnSeconds = 20,
})
