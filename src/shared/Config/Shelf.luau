--!strict
-- The lab display shelf: saved creatures that are not out earn coins while you are away.
-- Each part earns by rarity; earnings stop growing after `capHours`, so checking in once or
-- twice a day is enough (no punishment for a long break beyond missing extra coins).

local Types = require(script.Parent.Parent.Types)

local COINS_PER_HOUR: { [Types.Rarity]: number } = {
	Common = 2,
	Uncommon = 3,
	Rare = 5,
	Epic = 8,
	Legendary = 12,
	Mythic = 16,
	Secret = 20,
}

return table.freeze({
	coinsPerHour = table.freeze(COINS_PER_HOUR),
	capHours = 8,
})
