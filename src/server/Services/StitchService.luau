--!strict
-- StitchService: the Stitch Station. Turns a client's "stitch these parts" request into a
-- creature after checking the player is at a station and owns every part.
--
-- Stations are built in Studio: any BasePart or Model tagged "StitchStation". This service
-- adds the prompt players use to open the stitch screen, and a particle burst for successes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local STATION_TAG = "StitchStation"
-- Client code opens the stitch screen when a prompt with this tag is triggered.
local PROMPT_TAG = "StitchPrompt"
-- A little more than the prompt range, so a player who opened the screen can still stitch
-- after shuffling a step back.
local MAX_STATION_DISTANCE = 20

type Station = { anchor: BasePart, burst: ParticleEmitter }

local stations: { Station } = {}

local function anchorOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function setUpStation(instance: Instance): ()
	local anchor = anchorOf(instance)
	if anchor == nil then
		warn(`[Mashup Monsters] {instance:GetFullName()} is tagged {STATION_TAG} but has no part`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StitchPrompt"
	prompt.ActionText = "Stitch"
	prompt.ObjectText = "Stitch Station"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, PROMPT_TAG)

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "StitchBurst"
	burst.Enabled = false
	burst.Color = ColorSequence.new(Color3.fromRGB(150, 230, 50), Color3.fromRGB(175, 85, 255))
	burst.LightEmission = 0.8
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(10, 20)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(0.8, 0)
	burst.Parent = anchor

	table.insert(stations, { anchor = anchor, burst = burst })
end

local function nearestStation(player: Player): Station?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	for _, station in stations do
		if (station.anchor.Position - root.Position).Magnitude <= MAX_STATION_DISTANCE then
			return station
		end
	end
	return nil
end

local function onStitch(player: Player, rawLoadout: unknown): (boolean, string?)
	if not RateLimit.allow(player, "Stitch", 1) then
		return false, "Slow down a little!"
	end
	local station = nearestStation(player)
	if station == nil then
		return false, "Walk up to the Stitch Station first."
	end
	local loadout = Creatures.parseLoadout(rawLoadout)
	if loadout == nil then
		return false, "Pick at least one part."
	end

	local ok, message = PlayerDataService.stitch(player, loadout)
	if ok then
		station.burst:Emit(60)
	end
	return ok, message
end

local StitchService = {}

function StitchService.start(): ()
	for _, instance in CollectionService:GetTagged(STATION_TAG) do
		setUpStation(instance)
	end
	if #stations == 0 then
		warn(`[Mashup Monsters] no Stitch Station found (tag a part "{STATION_TAG}" in Studio)`)
	end

	Remotes.func("Stitch").OnServerInvoke = onStitch

	Remotes.event("Unstitch").OnServerEvent:Connect(function(player: Player, index: unknown)
		if RateLimit.allow(player, "Unstitch", 0.5) and nearestStation(player) ~= nil then
			PlayerDataService.unstitch(player, index)
		end
	end)

	-- Choosing which creature is out works anywhere; it only swaps between owned creatures.
	Remotes.event("SetActiveCreature").OnServerEvent
		:Connect(function(player: Player, index: unknown)
			if RateLimit.allow(player, "SetActiveCreature", 0.5) then
				PlayerDataService.setActive(player, index)
			end
		end)
end

return StitchService
