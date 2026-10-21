--!strict
-- TutorialController: the guided first minutes (spec 4.6 and 4.8), shown with a pin and a
-- glowing line, not text:
--   MakeStarter (the first-monster pop-up is open; no pin) -> Ride (hop on) -> GoToIsland (the
--   next island your creature can reach, until you have reached a new island once).
-- The current step is worked out from the server's snapshot and your creature, so a player who
-- leaves mid-tutorial resumes at the right step and nothing here can skip progress.
--
-- Guide targets are Studio parts: for each island, a part tagged "GuideTarget" with a string
-- attribute "Island" at the start of the way there.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Types = require(ReplicatedStorage.Shared.Types)
local CreatureController = require(script.Parent.CreatureController)
local DataController = require(script.Parent.DataController)

export type Step = "MakeStarter" | "Ride" | "GoToIsland"

local GUIDE_TARGET_TAG = "GuideTarget"
local MARKER_HEIGHT = 7
local GUIDE_COLOR = Color3.fromRGB(230, 190, 90)

local player = Players.LocalPlayer

local step: Step? = nil
local stepListeners: { (Step?) -> () } = {}
local snapshot: Types.PlayerSnapshot? = nil

local markerPart: Part
local markerGui: BillboardGui
local beam: Beam
local beamStart: Attachment? = nil

----------------------------------------------------------------- step logic

-- The first island (in progression order) you haven't reached yet that your creature can get
-- to, or nil.
local function nextIsland(data: Types.PlayerSnapshot): Types.IslandDefinition?
	for _, island in Islands.list do
		local ability = island.requires
		if
			ability ~= nil
			and not data.unlockedIslands[island.id]
			and CreatureController.creatureHas(ability)
		then
			return island
		end
	end
	return nil
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
		return if #data.creatures == 0 then "MakeStarter" else nil
	end
	if not data.funnel.FirstNewIsland and nextIsland(data) ~= nil then
		return "GoToIsland"
	end
	return nil
end

local function islandTarget(islandId: string): Vector3?
	for _, target in CollectionService:GetTagged(GUIDE_TARGET_TAG) do
		if target:IsA("BasePart") and target:GetAttribute("Island") == islandId then
			return target.Position
		end
	end
	return nil
end

local function targetPosition(current: Step?): Vector3?
	if current == "Ride" then
		local model = CreatureController.getCreature()
		local hitbox = if model ~= nil then model.PrimaryPart else nil
		return if hitbox ~= nil and not CreatureController.isRiding() then hitbox.Position else nil
	elseif current == "GoToIsland" then
		local data = snapshot
		local island = if data ~= nil then nextIsland(data) else nil
		return if island ~= nil then islandTarget(island.id) else nil
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
	headStroke.Thickness = 3
	headStroke.Color = Color3.fromRGB(20, 20, 26)
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
	tipStroke.Thickness = 3
	tipStroke.Color = Color3.fromRGB(20, 20, 26)
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

	-- Steps change rarely; a slow re-check covers creatures and targets streaming in.
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
