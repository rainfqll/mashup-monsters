--!strict
-- PortalService: the portals of the One World (one in Stitch Square, one in each region).
-- Stepping up to one and pressing "Travel" opens the travel map on that player's screen
-- (PortalOpened). Travelling (PortalTravel) needs the Portal Pass, a portal close by, and a
-- destination you have already reached on foot (Stitch Square always works), so the pass
-- saves walking but never skips the ability gates.
-- World pieces (Studio): parts tagged "Portal" with an "Island" attribute (the region they
-- stand in), and an "IslandArrival" part per region where travellers appear.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.RateLimit)
local CreatureService = require(script.Parent.CreatureService)
local IslandService = require(script.Parent.IslandService)
local PassService = require(script.Parent.PassService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PORTAL_TAG = "Portal"
-- Client code styles these prompts.
local PROMPT_TAG = "PortalPrompt"
local MAX_DISTANCE = 20

local noticeRemote: RemoteEvent
local openedRemote: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- The portal this player is standing at, if any.
local function nearbyPortal(player: Player): BasePart?
	local root = rootOf(player)
	if root == nil then
		return nil
	end
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		if
			portal:IsA("BasePart")
			and (portal.Position - root.Position).Magnitude <= MAX_DISTANCE
		then
			return portal
		end
	end
	return nil
end

local function onTravel(player: Player, destination: unknown): ()
	if type(destination) ~= "string" or not RateLimit.allow(player, "PortalTravel", 2) then
		return
	end
	local island = Islands.get(destination)
	local from = nearbyPortal(player)
	if island == nil or from == nil then
		return
	end
	if not PassService.ownsPortalPass(player) then
		noticeRemote:FireClient(player, `Portals need the {Monetization.portalPassName}.`)
		return
	end
	if not PlayerDataService.isIslandUnlocked(player, destination) then
		noticeRemote:FireClient(player, `Reach {island.displayName} on foot first!`)
		return
	end
	if from:GetAttribute("Island") == destination then
		return
	end
	local arrival = IslandService.arrivalFor(destination)
	if arrival == nil then
		warn(`[Mashup Monsters] no IslandArrival for "{destination}"`)
		return
	end
	CreatureService.teleport(player, arrival)
	IslandService.setSafeSpot(player, arrival)
end

local function setUp(portal: Instance): ()
	local islandId = portal:GetAttribute("Island")
	if not portal:IsA("BasePart") or type(islandId) ~= "string" or Islands.get(islandId) == nil then
		warn(`[Mashup Monsters] {portal:GetFullName()} needs to be a part with a valid Island`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = "Travel"
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	CollectionService:AddTag(prompt, PROMPT_TAG)
	prompt.Triggered:Connect(function(player)
		if not RateLimit.allow(player, "PortalOpen", 1) or nearbyPortal(player) == nil then
			return
		end
		openedRemote:FireClient(player, islandId)
	end)
end

local PortalService = {}

function PortalService.start(): ()
	noticeRemote = Remotes.event("Notice")
	openedRemote = Remotes.event("PortalOpened")
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		setUp(portal)
	end
	Remotes.event("PortalTravel").OnServerEvent:Connect(onTravel)
end

return PortalService
