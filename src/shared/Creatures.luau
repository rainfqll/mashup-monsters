--!strict
-- Rules about creatures that both sides need: which loadouts are valid, what a loadout is
-- called, and which abilities and stats it has. The server uses parseLoadout on every
-- request and every save, so a bad loadout can never be stitched or loaded.

local Parts = require(script.Parent.Config.Parts)
local Types = require(script.Parent.Types)

type Loadout = Types.Loadout

local Creatures = {}

Creatures.SLOTS = table.freeze({ "Head", "Body", "Legs", "Back" } :: { Types.Slot })
Creatures.DEFAULT_BODY = "StitchyBlob"
Creatures.MAX_SAVED = 3

-- Turns untrusted input (a remote argument or an old save) into a clean Loadout, or nil if it
-- is not one. Only the four slot keys are read; each must name a real, non-free part of the
-- matching slot. A free part (the blob) is stored as an empty slot.
function Creatures.parseLoadout(value: unknown): Loadout?
	if type(value) ~= "table" then
		return nil
	end
	local input = value :: { [unknown]: unknown }
	local loadout: Loadout = {}
	local partCount = 0
	for _, slot in Creatures.SLOTS do
		local id = input[slot]
		if id ~= nil then
			if type(id) ~= "string" then
				return nil
			end
			local definition = Parts.get(id)
			if definition == nil or definition.slot ~= slot then
				return nil
			end
			if not definition.free then
				(loadout :: any)[slot] = id
				partCount += 1
			end
		end
	end
	-- A creature needs at least one real part; a bare blob is not a mashup.
	if partCount == 0 then
		return nil
	end
	return loadout
end

-- The real (non-free) part ids in a loadout, in slot order.
function Creatures.partIds(loadout: Loadout): { string }
	local ids = {}
	for _, slot in Creatures.SLOTS do
		local id = (loadout :: any)[slot] :: string?
		if id ~= nil then
			table.insert(ids, id)
		end
	end
	return ids
end

-- The parts actually built, including the blob when Body is empty.
function Creatures.definitions(loadout: Loadout): { Types.PartDefinition }
	local definitions = {}
	for _, slot in Creatures.SLOTS do
		local id = (loadout :: any)[slot] :: string?
		if id == nil and slot == "Body" then
			id = Creatures.DEFAULT_BODY
		end
		local definition = if id ~= nil then Parts.get(id) else nil
		if definition ~= nil then
			table.insert(definitions, definition)
		end
	end
	return definitions
end

-- A funny name from the first word of each part: Duck Head + Frog Legs -> "Duck-Frog".
function Creatures.summarize(loadout: Loadout): Types.CreatureSummary
	local words: { string } = {}
	local abilities: { [Types.Ability]: true } = {}
	local stats: Types.PartStats = { speed = 0, jump = 0, swim = 0, glide = 0, carry = 0 }

	for _, definition in Creatures.definitions(loadout) do
		local word = string.match(definition.displayName, "^%S+") or definition.displayName
		-- The blob is everyone's default body, so it adds nothing to the name.
		if not definition.free and not table.find(words, word) then
			table.insert(words, word)
		end
		for _, ability in definition.abilities do
			abilities[ability] = true
		end
		stats.speed += definition.stats.speed
		stats.jump += definition.stats.jump
		stats.swim += definition.stats.swim
		stats.glide += definition.stats.glide
		stats.carry += definition.stats.carry
	end

	return {
		name = table.concat(words, "-"),
		abilities = abilities,
		stats = stats,
	}
end

return table.freeze(Creatures)
