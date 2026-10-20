--!strict
-- Client entry point. The only LocalScript; everything else is a ModuleScript it starts.
-- Lives in StarterPlayerScripts, so it runs once per session and survives respawns.

local Controllers = script.Controllers

type Controller = { start: () -> () }

local START_ORDER: { Controller } = {
	require(Controllers.InputController),
	require(Controllers.UIController),
	require(Controllers.CreatureController),
	require(Controllers.PingController),
}

for _, controller in START_ORDER do
	controller.start()
end

print(`[Mashup Monsters] client ready ({#START_ORDER} controllers started)`)
