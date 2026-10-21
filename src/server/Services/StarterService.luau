--!strict
-- StarterService: the starter stand on Meadow Isle (spec 4.8). Each pedestal (a part tagged
-- "StarterPedestal" with a "Starter" attribute, built in Studio) gets a "Choose" prompt; the
-- save decides whether this player may still choose (PlayerDataService.chooseStarter).
-- The monsters on the pedestals, and hiding the prompts once you have a monster, are the
-- client's job (StarterController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Starters = require(ReplicatedStorage.Shared.Config.Starters)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PEDESTAL_TAG = "StarterPedestal"
-- StarterController looks for this tag to hide the prompts for players who already chose.
local PROMPT_TAG = "StarterPrompt"
local MAX_DISTANCE = 16

local StarterService = {}

function StarterService.start(): ()
	local noticeRemote = Remotes.event("Notice")

	for _, pedestal in CollectionService:GetTagged(PEDESTAL_TAG) do
		local starter = Starters.get(pedestal:GetAttribute("Starter"))
		if not pedestal:IsA("BasePart") or starter == nil then
			warn(
				`[Mashup Monsters] {pedestal:GetFullName()} needs to be a part with a known Starter`
			)
			continue
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StarterPrompt"
		prompt.ActionText = "Choose"
		prompt.ObjectText = starter.displayName
		-- A short hold, so brushing past a pedestal never picks for you.
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal
		CollectionService:AddTag(prompt, PROMPT_TAG)

		-- Config/Starters checks at load that every starter's island exists.
		local island = Islands.get(starter.island) :: Types.IslandDefinition
		prompt.Triggered:Connect(function(player)
			if not RateLimit.allow(player, "ChooseStarter", 1) then
				return
			end
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if
				root == nil
				or not root:IsA("BasePart")
				or (root.Position - pedestal.Position).Magnitude > MAX_DISTANCE
			then
				return
			end
			if PlayerDataService.chooseStarter(player, starter.id) then
				noticeRemote:FireClient(
					player,
					`{starter.displayName} is yours! Hop on and ride to {island.displayName}!`
				)
			end
		end)
	end
end

return StarterService
