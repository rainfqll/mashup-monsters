--!strict
-- TutorialController: the guided first session (spec 4.6), shown with arrows, not text.
--   CollectParts -> Stitch -> Ride, then a soft "go to Lily Lagoon" hint for swimmers.
-- The current step is worked out from the server's snapshot (which starter parts are taken,
-- whether a creature exists, which milestones are done), so a player who leaves mid-tutorial
-- resumes at the right step and nothing here can skip progress.
--
-- It also draws the personal starter pickups: tagged "StarterSpot" parts in the world, visible
-- only to players still in the tutorial. Touching one asks the server (CollectStarterPart).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureController = require(script.Parent.CreatureController)
local DataController = require(script.Parent.DataController)

export type Step = "CollectParts" | "Stitch" | "Ride" | "GoToLagoon"

local STARTER_TAG = "StarterSpot"
local STATION_TAG = "StitchStation"
local GUIDE_TARGET_TAG = "GuideTarget"
local LAGOON_TARGET_NAME = "LagoonRiver"
-- PickupController animates models with this tag.
local PICKUP_TAG = "PartPickup"
-- If the server hasn't confirmed a touched starter part by then, show it again.
local PENDING_SECONDS = 3
local MARKER_HEIGHT = 7
local GUIDE_COLOR = Color3.fromRGB(150, 230, 50)

local player = Players.LocalPlayer

local step: Step? = nil
local stepListeners: { (Step?) -> () } = {}
local snapshot: Types.PlayerSnapshot? = nil

-- spot name -> local pickup model; pending = touched, waiting for the server
local starterModels: { [string]: Model } = {}
local pendingSince: { [string]: number } = {}

local markerPart: Part
local markerGui: BillboardGui
local beam: Beam
local beamStart: Attachment? = nil

----------------------------------------------------------------- starter pickups

local function buildStarterPickup(spot: BasePart, definition: Types.PartDefinition): Model
	local model = Instance.new("Model")
	model.Name = `Starter_{spot.Name}`
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.one * 4
	hitbox.CFrame = CFrame.new(spot.Position + Vector3.new(0, 2, 0))
	hitbox.Material = Enum.Material.Neon
	hitbox.Color = Rarities[definition.rarity].color
	hitbox.Transparency = 0.45
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CastShadow = false
	hitbox.Parent = model
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.one * 1.6
	core.CFrame = hitbox.CFrame
	core.Color = definition.colorTheme
	core.Material = Enum.Material.SmoothPlastic
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Parent = model
	model.PrimaryPart = hitbox

	hitbox.Touched:Connect(function(hit)
		local character = player.Character
		if
			character == nil
			or not hit:IsDescendantOf(character)
			or pendingSince[spot.Name] ~= nil
		then
			return
		end
		pendingSince[spot.Name] = os.clock()
		model.Parent = nil
		Remotes.event("CollectStarterPart"):FireServer(spot.Name)
	end)

	CollectionService:AddTag(model, PICKUP_TAG)
	return model
end

local function starterSpots(): { BasePart }
	local spots = {}
	for _, spot in CollectionService:GetTagged(STARTER_TAG) do
		if spot:IsA("BasePart") then
			table.insert(spots, spot)
		end
	end
	return spots
end

-- Show exactly the starter pickups this player may still collect.
local function syncStarterPickups(): ()
	local data = snapshot
	local showAny = data ~= nil and not data.tutorialDone
	for _, spot in starterSpots() do
		local name = spot.Name
		local partId = spot:GetAttribute("PartId")
		local definition = if type(partId) == "string" then Parts.get(partId) else nil
		local collected = data ~= nil and data.starterCollected[name] == true
		local waiting = pendingSince[name] ~= nil
			and os.clock() - pendingSince[name] < PENDING_SECONDS
		local shouldShow = showAny and not collected and not waiting and definition ~= nil

		local model = starterModels[name]
		if shouldShow then
			if model == nil then
				model = buildStarterPickup(spot, definition :: Types.PartDefinition)
				starterModels[name] = model
			end
			pendingSince[name] = nil
			model.Parent = workspace
		elseif model ~= nil and (collected or not showAny) then
			model:Destroy()
			starterModels[name] = nil
		end
	end
end

----------------------------------------------------------------- step logic

local function countCollected(data: Types.PlayerSnapshot): (number, number)
	local collected, total = 0, 0
	for _, spot in starterSpots() do
		total += 1
		if data.starterCollected[spot.Name] then
			collected += 1
		end
	end
	return collected, total
end

local function computeStep(): Step?
	local data = snapshot
	if data == nil then
		return nil
	end
	if not data.tutorialDone then
		if CreatureController.hasCreature() then
			return "Ride"
		end
		local collected, total = countCollected(data)
		if #data.creatures == 0 and collected < total then
			return "CollectParts"
		end
		return "Stitch"
	end
	-- Afterwards, only nudge toward the next island if the creature can actually swim there.
	if not data.funnel.FirstNewIsland and CreatureController.creatureHas("Swim") then
		return "GoToLagoon"
	end
	return nil
end

local function firstTagged(tag: string, name: string?): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and (name == nil or instance.Name == name) then
			return instance
		end
	end
	return nil
end

local function targetPosition(current: Step?): Vector3?
	if current == "CollectParts" then
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local from = if root ~= nil and root:IsA("BasePart") then root.Position else Vector3.zero
		local best: Vector3? = nil
		for _, model in starterModels do
			if model.Parent ~= nil and model.PrimaryPart ~= nil then
				local position = (model.PrimaryPart :: BasePart).Position
				if
					best == nil
					or (position - from).Magnitude < ((best :: Vector3) - from).Magnitude
				then
					best = position
				end
			end
		end
		return best
	elseif current == "Stitch" then
		local station = firstTagged(STATION_TAG)
		return if station ~= nil then station.Position else nil
	elseif current == "Ride" then
		local model = CreatureController.getCreature()
		local hitbox = if model ~= nil then model.PrimaryPart else nil
		return if hitbox ~= nil and not CreatureController.isRiding() then hitbox.Position else nil
	elseif current == "GoToLagoon" then
		local target = firstTagged(GUIDE_TARGET_TAG, LAGOON_TARGET_NAME)
		return if target ~= nil then target.Position else nil
	end
	return nil
end

----------------------------------------------------------------- guide visuals

-- A bouncing map pin above the target plus a glowing line from you to it. Both are local
-- parts, so other players never see your tutorial.
local function buildGuide(): ()
	markerPart = Instance.new("Part")
	markerPart.Name = "TutorialMarker"
	markerPart.Size = Vector3.one * 0.2
	markerPart.Transparency = 1
	markerPart.Anchored = true
	markerPart.CanCollide = false
	markerPart.CanTouch = false
	markerPart.CanQuery = false
	markerPart.Parent = workspace

	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "Pin"
	markerGui.Size = UDim2.fromOffset(56, 76)
	markerGui.AlwaysOnTop = true
	markerGui.LightInfluence = 0
	markerGui.Enabled = false
	markerGui.Parent = markerPart

	local head = Instance.new("Frame")
	head.Size = UDim2.fromOffset(52, 52)
	head.Position = UDim2.fromOffset(2, 0)
	head.BackgroundColor3 = GUIDE_COLOR
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(0.5, 0)
	headCorner.Parent = head
	local headStroke = Instance.new("UIStroke")
	headStroke.Thickness = 4
	headStroke.Color = Color3.fromRGB(30, 15, 50)
	headStroke.Parent = head
	head.ZIndex = 2
	head.Parent = markerGui

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.4, 0.4)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot
	dot.ZIndex = 3
	dot.Parent = head

	-- The pin's point: a square turned 45 degrees, half hidden behind the circle.
	local tip = Instance.new("Frame")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromOffset(28, 52)
	tip.Size = UDim2.fromOffset(26, 26)
	tip.Rotation = 45
	tip.BackgroundColor3 = GUIDE_COLOR
	local tipStroke = Instance.new("UIStroke")
	tipStroke.Thickness = 4
	tipStroke.Color = Color3.fromRGB(30, 15, 50)
	tipStroke.Parent = tip
	tip.ZIndex = 1
	tip.Parent = markerGui

	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = markerPart
	beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam.Attachment1 = endAttachment
	beam.Parent = markerPart
end

local function attachBeamToCharacter(character: Model): ()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialBeamStart"
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	beamStart = attachment
	beam.Attachment0 = attachment
end

local function updateGuide(): ()
	local target = targetPosition(step)
	local visible = target ~= nil
	markerGui.Enabled = visible
	-- The line only helps when the target is out of reach; next to it, the pin is enough.
	beam.Enabled = visible and beamStart ~= nil and step ~= "Ride"
	if target ~= nil then
		local bob = math.sin(os.clock() * 3) * 0.6
		markerPart.Position = target + Vector3.new(0, MARKER_HEIGHT + bob, 0)
	end
end

----------------------------------------------------------------- public

local function refresh(): ()
	syncStarterPickups()
	local newStep = computeStep()
	if newStep ~= step then
		step = newStep
		for _, listener in stepListeners do
			task.spawn(listener, newStep)
		end
	end
end

local TutorialController = {}

function TutorialController.getStep(): Step?
	return step
end

-- Called with the new step (or nil when there is nothing to guide).
function TutorialController.onStepChanged(listener: (Step?) -> ()): ()
	table.insert(stepListeners, listener)
end

-- The starter parts' loadout, so the stitch screen can pre-fill it during the tutorial.
function TutorialController.starterLoadout(): Types.Loadout
	local loadout: Types.Loadout = {}
	for _, spot in starterSpots() do
		local partId = spot:GetAttribute("PartId")
		local definition = if type(partId) == "string" then Parts.get(partId) else nil
		if definition ~= nil then
			(loadout :: any)[definition.slot] = definition.id
		end
	end
	return loadout
end

function TutorialController.start(): ()
	buildGuide()
	if player.Character ~= nil then
		task.spawn(attachBeamToCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		beamStart = nil
		attachBeamToCharacter(character)
	end)

	DataController.onChanged(function(newSnapshot)
		snapshot = newSnapshot
		refresh()
	end)
	CreatureController.onStateChanged(refresh)

	-- Steps change rarely, but pending pickups and the nearest target need a slow re-check.
	local nextRefresh = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextRefresh then
			nextRefresh = now + 0.5
			refresh()
		end
		updateGuide()
	end)
end

return TutorialController
