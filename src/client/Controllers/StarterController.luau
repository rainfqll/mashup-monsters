--!strict
-- StarterController: draws the three starter monsters standing on the stand's pedestals (parts
-- tagged "StarterPedestal" with a "Starter" attribute), each with a sign saying what it can do,
-- and hides the "Choose" prompts once you have a monster. The stand stays as a landmark for
-- everyone; only new players can pick (the server checks that too, StarterService).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureAssembler = require(ReplicatedStorage.Shared.CreatureAssembler)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Starters = require(ReplicatedStorage.Shared.Config.Starters)
local Types = require(ReplicatedStorage.Shared.Types)
local DataController = require(script.Parent.DataController)
local Theme = require(script.Parent.Parent.UI.Theme)

local PEDESTAL_TAG = "StarterPedestal"
local PROMPT_TAG = "StarterPrompt"
local BOB_HEIGHT = 0.3
local BOB_SPEED = 1.6

type Display = { model: Model, base: CFrame, phase: number }

-- pedestal -> its monster, so a pedestal streaming in twice never gets two
local displays: { [Instance]: Display } = {}
-- Pedestals whose monster is being built (building can wait for the part models).
local building: { [Instance]: true } = {}
local canChoose = false

local function makeSign(model: Model, starter: Starters.StarterDefinition, halfHeight: number): ()
	local island = Islands.get(starter.island)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StarterSign"
	-- Sized in studs, so the three signs never overlap from far away.
	billboard.Size = UDim2.fromScale(7, 2.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, halfHeight + 2.2, 0)
	billboard.MaxDistance = 120
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.fromScale(1, 0.55)
	name.Text = starter.displayName
	Theme.text(name, 34)
	name.TextColor3 = starter.color
	name.Parent = billboard
	local ability = Instance.new("TextLabel")
	ability.Name = "Ability"
	ability.Position = UDim2.fromScale(0, 0.55)
	ability.Size = UDim2.fromScale(1, 0.45)
	ability.Text = `{Islands.abilityName(starter.ability)}  ·  {if island ~= nil
		then island.displayName
		else ""}`
	Theme.text(ability, 22)
	ability.Parent = billboard
	billboard.Adornee = model.PrimaryPart
	billboard.Parent = model
end

local function showOn(pedestal: Instance): ()
	if displays[pedestal] ~= nil or building[pedestal] or not pedestal:IsA("BasePart") then
		return
	end
	local starter = Starters.get(pedestal:GetAttribute("Starter"))
	if starter == nil then
		return
	end
	building[pedestal] = true
	local model = CreatureAssembler.build(starter.loadout)
	building[pedestal] = nil
	if pedestal.Parent == nil then
		-- Streamed out while we waited.
		model:Destroy()
		return
	end
	model.Name = `Starter_{starter.id}`
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local halfHeight = model:GetAttribute("HalfHeight")
	local lift = (if type(halfHeight) == "number" then halfHeight else 3) + pedestal.Size.Y / 2
	local base = pedestal.CFrame * CFrame.new(0, lift, 0)
	model:PivotTo(base)
	makeSign(model, starter, if type(halfHeight) == "number" then halfHeight else 3)
	model.Parent = workspace
	displays[pedestal] = { model = model, base = base, phase = math.random() * math.pi * 2 }
end

local function syncPrompts(): ()
	for _, prompt in CollectionService:GetTagged(PROMPT_TAG) do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = canChoose
		end
	end
end

local function onSnapshot(snapshot: Types.PlayerSnapshot): ()
	canChoose = snapshot.starterChosen == ""
		and not snapshot.tutorialDone
		and #snapshot.creatures == 0
	syncPrompts()
end

local StarterController = {}

function StarterController.start(): ()
	-- Building waits for the part models to arrive, so it never holds up the other controllers.
	for _, pedestal in CollectionService:GetTagged(PEDESTAL_TAG) do
		task.spawn(showOn, pedestal)
	end
	CollectionService:GetInstanceAddedSignal(PEDESTAL_TAG):Connect(function(pedestal)
		task.spawn(showOn, pedestal)
	end)
	-- A pedestal streaming out takes its monster with it; it is rebuilt when it streams back.
	CollectionService:GetInstanceRemovedSignal(PEDESTAL_TAG):Connect(function(pedestal)
		local display = displays[pedestal]
		if display ~= nil then
			display.model:Destroy()
			displays[pedestal] = nil
		end
	end)
	CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(syncPrompts)
	DataController.onChanged(onSnapshot)

	-- A gentle idle bob, so the stand looks alive. W3 replaces this with real animation.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, display in displays do
			local bob = math.sin((now + display.phase) * BOB_SPEED) * BOB_HEIGHT
			display.model:PivotTo(display.base * CFrame.new(0, bob, 0))
		end
	end)
end

return StarterController
