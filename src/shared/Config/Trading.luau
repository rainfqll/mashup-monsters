--!strict
-- Trading rules (spec 4.4 + our agreed adjustments): friends only, loose parts only, a short
-- countdown after both press Ready, and freshly found Legendary+ parts locked for a day so
-- nobody gets pressured into trading a big find away on the spot.

local Types = require(script.Parent.Parent.Types)

local LOCKED_RARITIES: { [Types.Rarity]: true } = {
	Legendary = true,
	Mythic = true,
	Secret = true,
}

return table.freeze({
	-- Parts per side.
	maxItems = 4,
	-- Seconds between both pressing Ready and the swap; any change cancels it.
	countdownSeconds = 3,
	-- How long a trade request waits for an answer.
	inviteSeconds = 20,
	-- Trade partners must stay this close (studs).
	maxDistance = 40,
	lockedRarities = table.freeze(LOCKED_RARITIES),
	lockSeconds = 24 * 60 * 60,
	-- Studio's test players are never real friends, so in Studio anyone may trade (testing only).
	studioAllowsAnyone = true,
})
