--!strict
-- StarterService: answers the "Make your first Mashup!" pop-up (StarterScreen). The client only
-- sends the four parts it picked; the server checks each one is a starter option and that the
-- player has no monster yet, then PlayerDataService.createStarter stitches it in one step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Starters = require(ReplicatedStorage.Shared.Config.Starters)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local function onCreateStarter(player: Player, value: unknown): (boolean, string?)
	if not RateLimit.allow(player, "CreateStarter", 1) then
		return false, nil
	end
	local loadout = Starters.parse(value)
	if loadout == nil then
		return false, "Pick a part for every slot!"
	end
	if not PlayerDataService.createStarter(player, loadout) then
		return false, "You already have a monster!"
	end
	return true, nil
end

local StarterService = {}

function StarterService.start(): ()
	Remotes.func("CreateStarter").OnServerInvoke = onCreateStarter
end

return StarterService
