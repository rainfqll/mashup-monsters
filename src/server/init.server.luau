--!strict
-- Server entry point. The only server Script; everything else is a ModuleScript it starts.
-- Services start one at a time in this exact order because later ones depend on earlier
-- ones (everything needs player data). If one errors, startup stops loudly in Output
-- instead of running a half-started game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Services = script.Services

type Service = { start: () -> () }

local START_ORDER: { Service } = {
	require(Services.PlayerDataService),
	require(Services.PickupService),
	require(Services.StitchService),
	require(Services.BundleService),
	require(Services.CreatureService),
	-- After CreatureService: the island and water gates ask it who rides with which ability.
	require(Services.IslandService),
	require(Services.ChallengeService),
	require(Services.TradeService),
	require(Services.CrewService),
}

-- Remotes must exist before any service connects handlers or any client asks for them.
Remotes.createAll()

for _, service in START_ORDER do
	service.start()
end

print(`[Mashup Monsters] server ready ({#START_ORDER} services started)`)
