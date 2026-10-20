--!strict
-- PartService: owns part pickups in the world and decides who gets them.
--
-- Pickup spots are built in Studio: any BasePart tagged "PickupSpot" with a string attribute
-- "PartId". This service puts one glowing pickup on each spot at startup.
-- Collecting uses the server's own Touched event, so there is no "I collected X" remote for
-- an exploiter to call; the server still checks the toucher is alive and actually nearby.
-- Pickups are hidden and reused instead of destroyed, so respawning creates no new instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SPOT_TAG = "PickupSpot"
-- Client code looks for this tag to animate pickups.
local PICKUP_TAG = "PartPickup"

local RESPAWN_SECONDS = 30
-- Touched can report contacts slightly late or from a lagging character; anything farther
-- than this from the pickup's center is treated as not really touching.
local MAX_COLLECT_DISTANCE = 12
local HITBOX_SIZE = 4
local HITBOX_TRANSPARENCY = 0.45

type Pickup = {
	partId: string,
	model: Model,
	hitbox: BasePart,
	core: BasePart,
	sparkles: ParticleEmitter,
	active: boolean,
}

local pickups: { Pickup } = {}

local function buildPickup(spot: BasePart, partId: string, folder: Folder): Pickup
	local definition = assert(Parts.get(partId))
	local rarityColor = Rarities[definition.rarity].color

	local model = Instance.new("Model")
	model.Name = `Pickup_{partId}`
	model:SetAttribute("PartId", partId)

	-- The glowing bubble players touch. Static on the server; only the core moves (on clients).
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.one * HITBOX_SIZE
	hitbox.CFrame = CFrame.new(spot.Position + Vector3.new(0, HITBOX_SIZE / 2, 0))
	hitbox.Material = Enum.Material.Neon
	hitbox.Color = rarityColor
	hitbox.Transparency = HITBOX_TRANSPARENCY
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CastShadow = false
	hitbox.Parent = model

	-- A chunky block in the part's own color, standing in for the real part model.
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.one * (HITBOX_SIZE * 0.4)
	core.CFrame = hitbox.CFrame
	core.Material = Enum.Material.SmoothPlastic
	core.Color = definition.colorTheme
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.CastShadow = false
	core.Parent = model

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(rarityColor)
	sparkles.LightEmission = 1
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.Parent = hitbox

	model.PrimaryPart = hitbox
	model.Parent = folder
	CollectionService:AddTag(model, PICKUP_TAG)

	return {
		partId = partId,
		model = model,
		hitbox = hitbox,
		core = core,
		sparkles = sparkles,
		active = true,
	}
end

local function setActive(pickup: Pickup, active: boolean): ()
	pickup.active = active
	pickup.hitbox.Transparency = if active then HITBOX_TRANSPARENCY else 1
	pickup.core.Transparency = if active then 0 else 1
	pickup.hitbox.CanTouch = active
	pickup.sparkles.Enabled = active
	pickup.model:SetAttribute("Active", active)
end

local function playerFromHit(hit: BasePart): (Player?, BasePart?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return player, root
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
	if not PlayerDataService.addPart(player, pickup.partId, 1) then
		-- Save not loaded yet (or the id is bad): leave the pickup for them or someone else.
		setActive(pickup, true)
		return
	end

	task.delay(RESPAWN_SECONDS, setActive, pickup, true)
end

local function spawnAll(): ()
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace

	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		local partId = spot:GetAttribute("PartId")
		if not spot:IsA("BasePart") then
			warn(`[Mashup Monsters] {spot:GetFullName()} is tagged {SPOT_TAG} but is not a part`)
		elseif type(partId) ~= "string" or Parts.get(partId) == nil then
			warn(`[Mashup Monsters] {spot:GetFullName()} has unknown PartId "{tostring(partId)}"`)
		else
			local pickup = buildPickup(spot, partId, folder)
			pickup.hitbox.Touched:Connect(function(hit: BasePart)
				onTouched(pickup, hit)
			end)
			setActive(pickup, true)
			table.insert(pickups, pickup)
		end
	end

	if #pickups == 0 then
		warn(`[Mashup Monsters] no pickup spots found (tag parts "{SPOT_TAG}" in Studio)`)
	end
end

local PartService = {}

function PartService.start(): ()
	spawnAll()
end

return PartService
