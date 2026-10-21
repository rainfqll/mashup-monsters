--!strict
-- EggController: draws the monster eggs this player can still find (parts tagged "EggSpot",
-- see Config/Eggs) and asks the server when the character touches one (CollectEgg). Eggs are
-- personal, so each player sees their own; one found lately stays hidden until it is back.
-- The hatching show itself is the UI's job: listeners get the part that came out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local DataController = require(script.Parent.DataController)

local SPOT_TAG = "EggSpot"
local EGG_HEIGHT = 2.6
local HITBOX_SIZE = 5
-- If the server hasn't answered by then, or said no, the egg shows again.
local RETRY_SECONDS = 3
local BOB_HEIGHT = 0.35
local SPIN_SPEED = 0.8
-- Re-check every few seconds, so an egg that comes back appears without a new snapshot.
local REFRESH_SECONDS = 5

type Egg = { model: Model, hitbox: BasePart, base: CFrame, phase: number }
type HatchListener = (partId: string, isNew: boolean, tierName: string) -> ()

local player = Players.LocalPlayer
local eggs: { [BasePart]: Egg } = {}
local pendingUntil: { [string]: number } = {}
local listeners: { HatchListener } = {}
local folder: Folder? = nil

local function eggFolder(): Folder
	local current = folder
	if current == nil then
		current = Instance.new("Folder")
		current.Name = "MyEggs"
		current.Parent = workspace
		folder = current
	end
	return current
end

local function buildEggModel(tier: Eggs.TierDefinition): Model
	local art = ReplicatedStorage:FindFirstChild("Art")
	local template = if art ~= nil then art:FindFirstChild("Egg") else nil
	local model: Model
	if template ~= nil and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local shell = Instance.new("Part")
		shell.Name = "Top"
		shell.Shape = Enum.PartType.Ball
		shell.Size = Vector3.new(3, 3.8, 3)
		shell.Color = tier.color
		shell.Parent = model
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * EGG_HEIGHT / size.Y)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") then
			descendant.Color = tier.color
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	return model
end

-- Shiny and treasure eggs sparkle and glow, so they catch the eye from across an island.
local function addShine(hitbox: BasePart, tierName: string, color: Color3): ()
	if tierName == "Plain" then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if tierName == "Treasure" then 18 else 12
	light.Brightness = 2
	light.Parent = hitbox
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Rate = if tierName == "Treasure" then 10 else 6
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Parent = hitbox
end

local function isHidden(spot: BasePart, snapshot: Types.PlayerSnapshot?): boolean
	if (pendingUntil[spot.Name] or 0) > os.clock() then
		return true
	end
	local foundAt = if snapshot ~= nil then snapshot.eggSpots[spot.Name] else nil
	return foundAt ~= nil and foundAt + Eggs.respawnHours * 3600 > os.time()
end

local function collect(spot: BasePart): ()
	local snapshot = DataController.get()
	if snapshot == nil or isHidden(spot, snapshot) then
		return
	end
	pendingUntil[spot.Name] = os.clock() + RETRY_SECONDS
	local egg = eggs[spot]
	if egg ~= nil then
		egg.model.Parent = nil
	end
	local tierName = spot:GetAttribute("Tier")
	local partId = Remotes.func("CollectEgg"):InvokeServer(spot.Name)
	if type(partId) ~= "string" then
		return
	end
	-- Found: stays hidden through the snapshot, which records the find.
	pendingUntil[spot.Name] = os.clock() + REFRESH_SECONDS
	local isNew = snapshot.discovered[partId] == nil
	for _, listener in listeners do
		task.spawn(
			listener,
			partId,
			isNew,
			if type(tierName) == "string" then tierName else "Plain"
		)
	end
end

local function track(spot: Instance): ()
	if not spot:IsA("BasePart") or eggs[spot] ~= nil then
		return
	end
	local tierName = spot:GetAttribute("Tier")
	local tier = if type(tierName) == "string" then Eggs.tiers[tierName] else nil
	if tier == nil then
		return
	end
	local base = CFrame.new(spot.Position + Vector3.new(0, EGG_HEIGHT / 2 + 0.6, 0))
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.one * HITBOX_SIZE
	hitbox.CFrame = base
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	addShine(hitbox, tierName :: string, tier.color)

	local model = buildEggModel(tier)
	model.Name = spot.Name
	model:PivotTo(base)
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	hitbox.Touched:Connect(function(hit)
		local character = player.Character
		if character ~= nil and hit:IsDescendantOf(character) then
			collect(spot)
		end
	end)
	eggs[spot] =
		{ model = model, hitbox = hitbox, base = base, phase = math.random() * math.pi * 2 }
end

local function untrack(spot: Instance): ()
	local egg = eggs[spot :: BasePart]
	if egg ~= nil then
		egg.model:Destroy()
		eggs[spot :: BasePart] = nil
	end
end

local function refresh(): ()
	local snapshot = DataController.get()
	for spot, egg in eggs do
		local hidden = snapshot == nil or isHidden(spot, snapshot)
		egg.model.Parent = if hidden then nil else eggFolder()
	end
end

local EggController = {}

-- Called with each part an egg hatched (after the server saved it).
function EggController.onHatched(listener: HatchListener): ()
	table.insert(listeners, listener)
end

function EggController.start(): ()
	for _, spot in CollectionService:GetTagged(SPOT_TAG) do
		track(spot)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(function(spot)
		track(spot)
		refresh()
	end)
	-- A spot streaming out takes its egg with it; it is rebuilt when it streams back.
	CollectionService:GetInstanceRemovedSignal(SPOT_TAG):Connect(untrack)
	DataController.onChanged(refresh)
	refresh()

	local nextRefresh = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextRefresh then
			nextRefresh = now + REFRESH_SECONDS
			refresh()
		end
		for _, egg in eggs do
			if egg.model.Parent ~= nil then
				local t = now + egg.phase
				egg.model:PivotTo(
					egg.base
						* CFrame.new(0, math.sin(t * 2) * BOB_HEIGHT, 0)
						* CFrame.Angles(0, t * SPIN_SPEED, math.sin(t * 1.3) * 0.12)
				)
			end
		end
	end)
end

return EggController
