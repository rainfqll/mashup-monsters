--!strict
-- The daily clock: one UTC day for everyone, so friends share the same Part of the Day and the
-- free bundle resets at the same moment (midnight UTC). os.time() is UTC on server and client.

local Bundles = require(script.Parent.Config.Bundles)
local Parts = require(script.Parent.Config.Parts)

local SECONDS_PER_DAY = 86400

-- Parts that bundles can actually roll, in a fixed order so every server picks the same one.
local eligible: { string } = {}
do
	local rollable: { [string]: true } = {}
	for _, entry in Bundles.odds do
		rollable[entry.rarity] = true
	end
	for _, definition in Parts.list do
		if not definition.free and rollable[definition.rarity] then
			table.insert(eligible, definition.id)
		end
	end
end

local Daily = {}

-- Days since 1 Jan 1970 (UTC).
function Daily.today(): number
	return os.time() // SECONDS_PER_DAY
end

-- Seconds until the next daily reset.
function Daily.secondsUntilReset(): number
	return SECONDS_PER_DAY - os.time() % SECONDS_PER_DAY
end

-- Same answer for everyone on the same day, without any shared storage.
function Daily.partOfTheDay(day: number): string
	local random = Random.new(day * 7919)
	return eligible[random:NextInteger(1, #eligible)]
end

return table.freeze(Daily)
