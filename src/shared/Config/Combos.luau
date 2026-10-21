--!strict
-- Part combinations that are worth more than their parts (spec 4.2).
--
-- Set bonus: 2+ parts from the same family (the `family` field in Parts.luau). Each extra part
-- of that family adds `setBonusPerExtraPart` to every stat those parts already give, so a
-- Thunder set jumps higher and a Glowcap set glides better.
--
-- Secret Mashups: a recipe of specific parts in specific slots (slots not listed can hold
-- anything). Stitching one gives the creature a secret name and a sparkly aura, and adds it to
-- the creature book. Looks only, no extra power, so hunting them never becomes mandatory.
-- Ids are saved in player data (secretsFound), so never rename one once it has shipped;
-- replaced ids live in RetiredIds.luau.

local Types = require(script.Parent.Parent.Types)
local Parts = require(script.Parent.Parts)
local RetiredIds = require(script.Parent.RetiredIds)

export type SecretDefinition = {
	id: string,
	displayName: string,
	recipe: Types.Loadout,
	auraColor: Color3,
}

local SECRETS: { SecretDefinition } = {
	{
		id = "SteamDragon",
		displayName = "Steam Dragon",
		recipe = { Head = "EmberHead", Body = "TideBody", Back = "TideTail" },
		auraColor = Color3.fromRGB(255, 175, 120),
	},
	{
		id = "StormRunner",
		displayName = "Storm Runner",
		recipe = { Head = "ThunderHead", Legs = "ThunderLegs", Back = "EmberWings" },
		auraColor = Color3.fromRGB(120, 200, 255),
	},
	{
		id = "GemGuardian",
		displayName = "Gem Guardian",
		recipe = { Head = "CrystalHead", Body = "MossBody", Back = "CrystalShell" },
		auraColor = Color3.fromRGB(200, 120, 255),
	},
	{
		id = "MoonLantern",
		displayName = "Moon Lantern",
		recipe = { Head = "GlowcapHead", Body = "TideBody", Back = "GlowcapWings" },
		auraColor = Color3.fromRGB(190, 230, 255),
	},
	{
		id = "PuddleHopper",
		displayName = "Puddle Hopper",
		recipe = { Head = "TideHead", Legs = "ThunderLegs", Back = "TideTail" },
		auraColor = Color3.fromRGB(120, 230, 90),
	},
}

local byId: { [string]: SecretDefinition } = {}
for _, secret in SECRETS do
	assert(byId[secret.id] == nil, `Duplicate secret id "{secret.id}" in Combos.luau`)
	assert(RetiredIds.secrets[secret.id] == nil, `Secret id "{secret.id}" was retired`)
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
