--!strict
-- Giant fossils (spec 4.4 "team pickups"): a big dig spot that 2+ players clear quickly. A solo
-- player gets Bolt, the lab helper robot, who digs with them, just slower. Everyone who dug
-- gets their own reward. World pieces: a part tagged "GiantFossil" (built in Studio).

local Types = require(script.Parent.Parent.Types)

export type Odds = { rarity: Types.Rarity, weight: number }

return table.freeze({
	-- Seconds to dig out with 2+ players, and with one player plus Bolt.
	coopSeconds = 5,
	soloSeconds = 30,
	-- A lone digger waits this long for a friend before Bolt comes to help.
	helperDelay = 3,
	-- Diggers must stay this close, or they stop counting.
	digRange = 14,
	-- After a dig, the fossil is gone for everyone in the server for this long.
	respawnSeconds = 300,
	-- Every digger gets one part rolled from these (fossils are the "rare and better" pickups)
	-- plus some coins.
	rewardOdds = table.freeze({
		{ rarity = "Rare", weight = 70 },
		{ rarity = "Epic", weight = 30 },
	} :: { Odds }),
	rewardCoins = 15,
})
