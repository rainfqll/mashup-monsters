--!strict
-- BundleService: the mystery bundle machine. Players pay coins; the server rolls the part.
-- Machines are built in Studio: any BasePart or Model tagged "BundleMachine". Odds and price
-- live in Config/Bundles, which the client also shows, so the shown odds are the real ones.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bundles = require(ReplicatedStorage.Shared.Config.Bundles)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MACHINE_TAG = "BundleMachine"
-- Client code opens the bundle screen when a prompt with this tag is triggered.
local PROMPT_TAG = "BundlePrompt"
local MAX_MACHINE_DISTANCE = 20

local machines: { BasePart } = {}
local random = Random.new()

-- Parts each rarity can roll, built once. Free parts (the blob) never drop.
local partsByRarity: { [Types.Rarity]: { string } } = {}
for _, definition in Parts.list do
	if not definition.free then
		local list = partsByRarity[definition.rarity] or {}
		table.insert(list, definition.id)
		partsByRarity[definition.rarity] = list
	end
end

local function roll(): string
	local total = 0
	for _, entry in Bundles.odds do
		total += entry.weight
	end
	local pick = random:NextNumber(0, total)
	local rarity: Types.Rarity = Bundles.odds[1].rarity
	for _, entry in Bundles.odds do
		pick -= entry.weight
		if pick <= 0 then
			rarity = entry.rarity
			break
		end
	end
	local candidates = partsByRarity[rarity] or partsByRarity.Common :: { string }
	return candidates[random:NextInteger(1, #candidates)]
end

local function anchorOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function isNearMachine(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, anchor in machines do
		if (anchor.Position - root.Position).Magnitude <= MAX_MACHINE_DISTANCE then
			return true
		end
	end
	return false
end

local function onOpenBundle(player: Player): (string?, string?)
	if not RateLimit.allow(player, "OpenBundle", 1.5) then
		return nil, "Slow down a little!"
	end
	if not isNearMachine(player) then
		return nil, "Walk up to the Bundle Machine first."
	end
	local partId = roll()
	local ok, message = PlayerDataService.buyBundle(player, Bundles.price, partId, Bundles.sku)
	if not ok then
		return nil, message
	end
	return partId, nil
end

local BundleService = {}

function BundleService.start(): ()
	for _, instance in CollectionService:GetTagged(MACHINE_TAG) do
		local anchor = anchorOf(instance)
		if anchor == nil then
			warn(
				`[Mashup Monsters] {instance:GetFullName()} is tagged {MACHINE_TAG} but has no part`
			)
		else
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BundlePrompt"
			prompt.ActionText = "Open"
			prompt.ObjectText = "Bundle Machine"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = anchor
			CollectionService:AddTag(prompt, PROMPT_TAG)
			table.insert(machines, anchor)
		end
	end
	if #machines == 0 then
		warn(`[Mashup Monsters] no Bundle Machine found (tag a part "{MACHINE_TAG}" in Studio)`)
	end

	Remotes.func("OpenBundle").OnServerInvoke = onOpenBundle
end

return BundleService
