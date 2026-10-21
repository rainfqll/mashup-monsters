--!strict
-- The first monster (spec 4.8): new players build it themselves in a pop-up, picking each slot
-- from the three starter part sets. Every combination is allowed, so everyone's first monster is
-- their own mashup, and the abilities it ends up with decide where it can go first (Ember Wings
-- glide, Tide Tail swims, Thunder Legs super jump).

local Creatures = require(script.Parent.Parent.Creatures)
local Parts = require(script.Parent.Parts)
local Types = require(script.Parent.Parent.Types)

local FAMILIES = { "Ember", "Tide", "Thunder" }

-- slot -> the part ids you can pick for it, in FAMILIES order
local OPTIONS: { [Types.Slot]: { string } } = {}
for _, slot in Creatures.SLOTS do
	local list = {}
	for _, family in FAMILIES do
		for _, part in Parts.list do
			if part.slot == slot and part.family == family and not part.free then
				table.insert(list, part.id)
			end
		end
	end
	assert(#list == #FAMILIES, `Starters: each family needs exactly one {slot} part`)
	OPTIONS[slot] = table.freeze(list)
end

local Starters = {}

Starters.families = table.freeze(FAMILIES)
Starters.options = table.freeze(OPTIONS)

-- A starter loadout from untrusted input: all four slots filled, each with one of its options.
function Starters.parse(value: unknown): Types.Loadout?
	local loadout = Creatures.parseLoadout(value)
	if loadout == nil then
		return nil
	end
	for _, slot in Creatures.SLOTS do
		local partId = (loadout :: any)[slot] :: string?
		if partId == nil or not table.find(OPTIONS[slot], partId) then
			return nil
		end
	end
	return loadout
end

return table.freeze(Starters)
