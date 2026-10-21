--!strict
-- Client entry point. The only LocalScript; everything else is a ModuleScript it starts.
-- Lives in StarterPlayerScripts, so it runs once per session and survives respawns.

local Controllers = script.Controllers

type Controller = { start: () -> () }

local START_ORDER: { Controller } = {
	require(Controllers.InputController),
	-- Before UI, so screens can subscribe to data as they are built.
	require(Controllers.DataController),
	require(Controllers.UIController),
	require(Controllers.PickupController),
	require(Controllers.CreatureController),
	-- After Data and Creature controllers: the tutorial step is worked out from both.
	require(Controllers.TutorialController),
	require(Controllers.IslandController),
	-- After IslandController: the ambience follows the region you are in.
	require(Controllers.AmbienceController),
	require(Controllers.ChallengeController),
	require(Controllers.ShelfController),
	require(Controllers.EggController),
	require(Controllers.FossilController),
	require(Controllers.TradeController),
	require(Controllers.PingController),
}

for _, controller in START_ORDER do
	controller.start()
end

print(`[Mashup Monsters] client ready ({#START_ORDER} controllers started)`)
