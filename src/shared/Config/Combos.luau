--!strict
-- Part combinations that are worth more than their parts (spec 4.2).
--
-- Set bonus: 2+ parts from the same animal (the `animal` field in Parts.luau). Each extra part
-- of that animal adds `setBonusPerExtraPart` to every stat those parts already give, so a
-- Frog set jumps and swims better and an Eagle set glides better.
--
-- Secret Mashups: a recipe of specific parts in specific slots (slots not listed can hold
-- anything). Stitching one gives the creature a secret name and a sparkly aura, and adds it to
-- the creature book. Looks only, no extra power, so hunting them never becomes mandatory.
-- Ids are saved in player data (secretsFound), so never rename one once it has shipped.

local Types = require(script.Parent.Parent.Types)
local Parts = require(script.Parent.Parts)

export type SecretDefinition = {
	id: string,
	displayName: string,
	recipe: Types.Loadout,
	auraColor: Color3,
}

local SECRETS: { SecretDefinition } = {
	{
		id = "MountainKing",
		displayName = "Mountain King",
		recipe = { Head = "GoatHorns", Body = "BearBody", Legs = "GoatLegs" },
		auraColor = Color3.fromRGB(255, 200, 60),
	},
	{
		id = "NightHopper",
		displayName = "Night Hopper",
		recipe = { Head = "BatEars", Legs = "FrogLegs", Back = "BatWings" },
		auraColor = Color3.fromRGB(170, 90, 255),
	},
	{
		id = "SkyRacer",
		displayName = "Sky Racer",
		recipe = { Head = "EagleHead", Legs = "CheetahLegs", Back = "EagleWings" },
		auraColor = Color3.fromRGB(110, 200, 255),
	},
	{
		id = "LanternJelly",
		displayName = "Lantern Jelly",
		recipe = { Head = "FireflyHead", Back = "JellyfishTail" },
		auraColor = Color3.fromRGB(200, 255, 140),
	},
	{
		id = "PuddlePrince",
		displayName = "Puddle Prince",
		recipe = { Head = "DuckHead", Body = "FrogBody", Legs = "DuckFeet" },
		auraColor = Color3.fromRGB(120, 230, 90),
	},
}

local byId: { [string]: SecretDefinition } = {}
for _, secret in SECRETS do
	assert(byId[secret.id] == nil, `Duplicate secret id "{secret.id}" in Combos.luau`)
	for slot, partId in secret.recipe :: { [string]: string } do
		local part = Parts.get(partId)
		assert(
			part ~= nil and part.slot == slot,
			`Secret "{secret.id}": {partId} is not a {slot} part`
		)
	end
	table.freeze(secret.recipe)
	byId[secret.id] = table.freeze(secret)
end

local Combos = {}

Combos.setBonusPerExtraPart = 1
Combos.secrets = table.freeze(SECRETS)

function Combos.getSecret(id: string): SecretDefinition?
	return byId[id]
end

return table.freeze(Combos)
