--!strict
-- PickupService: owns pickups in the world (parts and coins) and decides who gets them.
--
-- Spots are built in Studio as invisible BaseParts:
--   "PickupSpot" + string attribute "PartId"  -> a glowing part bubble (respawns)
--   "CoinSpot"                                 -> a spinning coin (respawns)
-- Part and coin pickups use the server's own Touched event, so there is no "I collected X"
-- remote for those; the server still checks the toucher is alive and actually nearby.
-- Pickups are hidden and reused instead of destroyed, so respawning creates no new instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bundles = require(ReplicatedStorage.Shared.Config.Bundles)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SocialService = require(script.Parent.SocialService)

local PART_SPOT_TAG = "PickupSpot"
local COIN_SPOT_TAG = "CoinSpot"
-- Client code looks for this tag to animate pickups.
local PICKUP_TAG = "PartPickup"

local PART_RESPAWN_SECONDS = 30
-- Touched can report contacts slightly late or from a lagging character; anything farther
-- than this from the pickup's center is treated as not really touching.
local MAX_COLLECT_DISTANCE = 12
local HITBOX_SIZE = 4
local PART_BUBBLE_TRANSPARENCY = 0.45
local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_DIAMETER = 2.4
-- Rarity order (Config/Rarities) from which part pickups get a light: Rare and up.
local GLOW_FROM_ORDER = 3

type Kind = "Part" | "Coin"

type Pickup = {
	kind: Kind,
	partId: string?,
	model: Model,
	hitbox: BasePart,
	core: BasePart,
	-- How see-through the hitbox is while active (coins hide theirs; parts show a bubble).
	hitboxTransparency: number,
	sparkles: ParticleEmitter,
	active: boolean,
}

local pickups: { Pickup } = {}

-- Studio-made coin mesh (ReplicatedStorage.Art.Coin), or nil to fall back to a plain disc.
local function coinTemplate(): MeshPart?
	local art = ReplicatedStorage:FindFirstChild("Art")
	local coin = if art ~= nil then art:FindFirstChild("Coin") else nil
	return if coin ~= nil and coin:IsA("MeshPart") then coin else nil
end

local function buildPickup(spot: BasePart, kind: Kind, partId: string?, folder: Folder): Pickup
	local definition = if partId ~= nil then assert(Parts.get(partId)) else nil
	local glowColor = if definition ~= nil then Rarities[definition.rarity].color else COIN_COLOR

	local model = Instance.new("Model")
	model.Name = if partId ~= nil then `Pickup_{partId}` else "Pickup_Coin"
	model:SetAttribute("Kind", kind)
	if partId ~= nil then
		model:SetAttribute("PartId", partId)
	end

	-- The area players touch. Static on the server; only the core moves (on clients).
	local hitboxTransparency = if kind == "Part" then PART_BUBBLE_TRANSPARENCY else 1
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.one * HITBOX_SIZE
	hitbox.CFrame = CFrame.new(spot.Position + Vector3.new(0, HITBOX_SIZE / 2, 0))
	-- Parts float in a shimmering bubble; coins have no visible bubble.
	hitbox.Material = if kind == "Part" then Enum.Material.ForceField else Enum.Material.Neon
	hitbox.Color = glowColor
	hitbox.Transparency = hitboxTransparency
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CastShadow = false
	hitbox.Parent = model

	local core: BasePart
	local coinArt = coinTemplate()
	if definition ~= nil then
		-- A colored block; each client hides it and draws the real part model in its place
		-- (PickupController), so the replicated pickup stays tiny.
		core = Instance.new("Part")
		core.Size = Vector3.one * (HITBOX_SIZE * 0.4)
		core.Material = Enum.Material.SmoothPlastic
		core.Color = definition.colorTheme
		core.CFrame = hitbox.CFrame
	elseif coinArt ~= nil then
		core = coinArt:Clone()
		core.Size = coinArt.Size * (COIN_DIAMETER / math.max(coinArt.Size.X, coinArt.Size.Y))
		core.CFrame = hitbox.CFrame
	else
		-- No coin art in ReplicatedStorage.Art: a plain gold disc standing on its edge.
		core = Instance.new("Part")
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(0.5, COIN_DIAMETER, COIN_DIAMETER)
		core.Material = Enum.Material.Neon
		core.Color = COIN_COLOR
		core.CFrame = hitbox.CFrame * CFrame.Angles(0, math.rad(90), 0)
	end
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.CastShadow = false
	core.Parent = model

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(glowColor)
	sparkles.LightEmission = 1
	sparkles.Rate = if kind == "Part" then 4 else 2
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.Parent = hitbox

	-- Rare and better parts glow softly, so they catch the eye from across an island.
	if definition ~= nil and Rarities[definition.rarity].order >= GLOW_FROM_ORDER then
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = hitbox
	end

	model.PrimaryPart = hitbox
	model.Parent = folder
	CollectionService:AddTag(model, PICKUP_TAG)

	return {
		kind = kind,
		partId = partId,
		model = model,
		hitbox = hitbox,
		core = core,
		hitboxTransparency = hitboxTransparency,
		sparkles = sparkles,
		active = true,
	}
end

local function setActive(pickup: Pickup, active: boolean): ()
	pickup.active = active
	pickup.hitbox.Transparency = if active then pickup.hitboxTransparency else 1
	pickup.core.Transparency = if active then 0 else 1
	pickup.hitbox.CanTouch = active
	pickup.sparkles.Enabled = active
	pickup.model:SetAttribute("Active", active)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function playerFromHit(hit: BasePart): (Player?, BasePart?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
	if player == nil then
		return nil, nil
	end
	local root = rootOf(player)
	if root == nil then
		return nil, nil
	end
	return player, root
end

local function grant(pickup: Pickup, player: Player): boolean
	local partId = pickup.partId
	if partId ~= nil then
		return PlayerDataService.addPart(player, partId, 1)
	end
	-- Friends in the same server find a little more (the friend loot bonus).
	local value = Bundles.coinPickupValue + SocialService.coinBonus(player)
	return PlayerDataService.addCoins(player, value, "CoinPickup")
end

local function onTouched(pickup: Pickup, hit: BasePart): ()
	if not pickup.active then
		return
	end
	local player, root = playerFromHit(hit)
	if player == nil or root == nil then
		return
	end
	if (root.Position - pickup.hitbox.Position).Magnitude > MAX_COLLECT_DISTANCE then
		return
	end

	-- Hide first so a second touch in the same frame can't grant it twice.
	setActive(pickup, false)
	if not grant(pickup, player) then
		-- Save not loaded yet (or the id is bad): leave the pickup for them or someone else.
		setActive(pickup, true)
		return
	end

	local respawn = if pickup.kind == "Part"
		then PART_RESPAWN_SECONDS
		else Bundles.coinRespawnSeconds
	task.delay(respawn, setActive, pickup, true)
end

local function spawnFromTag(folder: Folder, tag: string, kind: Kind): ()
	for _, spot in CollectionService:GetTagged(tag) do
		local partId = spot:GetAttribute("PartId")
		if not spot:IsA("BasePart") then
			warn(`[Mashup Monsters] {spot:GetFullName()} is tagged {tag} but is not a part`)
		elseif kind == "Part" and (type(partId) ~= "string" or Parts.get(partId) == nil) then
			warn(`[Mashup Monsters] {spot:GetFullName()} has unknown PartId "{tostring(partId)}"`)
		else
			local pickup =
				buildPickup(spot, kind, if kind == "Part" then partId :: string else nil, folder)
			pickup.hitbox.Touched:Connect(function(hit: BasePart)
				onTouched(pickup, hit)
			end)
			setActive(pickup, true)
			table.insert(pickups, pickup)
		end
	end
end

local PickupService = {}

function PickupService.start(): ()
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace

	spawnFromTag(folder, PART_SPOT_TAG, "Part")
	spawnFromTag(folder, COIN_SPOT_TAG, "Coin")
	if #pickups == 0 then
		warn(`[Mashup Monsters] no pickup spots found (tag parts "{PART_SPOT_TAG}" in Studio)`)
	end
end

return PickupService
