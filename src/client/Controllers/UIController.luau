--!strict
-- UIController: builds the HUD and screens and decides which one is open (only one at a time).
-- UI only displays server state; it never decides outcomes.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ChallengeController = require(script.Parent.ChallengeController)
local CreatureController = require(script.Parent.CreatureController)
local Daily = require(ReplicatedStorage.Shared.Daily)
local DataController = require(script.Parent.DataController)
local IslandController = require(script.Parent.IslandController)
local PingController = require(script.Parent.PingController)
local TutorialController = require(script.Parent.TutorialController)
local BookScreen = require(script.Parent.Parent.UI.BookScreen)
local BundleScreen = require(script.Parent.Parent.UI.BundleScreen)
local Hud = require(script.Parent.Parent.UI.Hud)
local InventoryScreen = require(script.Parent.Parent.UI.InventoryScreen)
local Panel = require(script.Parent.Parent.UI.Panel)
local PingMenu = require(script.Parent.Parent.UI.PingMenu)
local RevealOverlay = require(script.Parent.Parent.UI.RevealOverlay)
local StitchScreen = require(script.Parent.Parent.UI.StitchScreen)
local Theme = require(script.Parent.Parent.UI.Theme)

local STITCH_PROMPT_TAG = "StitchPrompt"
local BUNDLE_PROMPT_TAG = "BundlePrompt"
-- Walking this far from a machine closes its screen (the server would refuse anyway).
local STATION_LEAVE_DISTANCE = 22

local UIController = {}

function UIController.start(): ()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "MashupHud"
	-- Survives respawns, so screens don't flash shut when the character resets.
	screen.ResetOnSpawn = false
	-- Keeps every button clear of the notch and Roblox's own top bar buttons.
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local hud = Hud.create(screen)
	local inventory = InventoryScreen.create(screen)
	local book = BookScreen.create(screen)
	local stitch = StitchScreen.create(screen, hud.showMessage)
	local reveal = RevealOverlay.create(screen)
	local bundle = BundleScreen.create(screen, reveal, hud.showMessage)
	local panels: { Panel.Panel } = { inventory.panel, book.panel, stitch.panel, bundle.panel }

	local function openOnly(target: Panel.Panel): ()
		for _, panel in panels do
			if panel ~= target then
				panel.close()
			end
		end
		target.open()
	end

	local function toggle(target: Panel.Panel): ()
		if target.isOpen() then
			target.close()
		else
			openOnly(target)
		end
	end

	hud.bagButton.Activated:Connect(function()
		toggle(inventory.panel)
	end)
	hud.bookButton.Activated:Connect(function()
		toggle(book.panel)
	end)
	hud.rideButton.Activated:Connect(CreatureController.toggleRide)

	-- Machines open their screen from a prompt; walking away closes it.
	local machinePart: BasePart? = nil
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local parent = prompt.Parent
		local target = if CollectionService:HasTag(prompt, STITCH_PROMPT_TAG)
			then stitch.panel
			elseif CollectionService:HasTag(prompt, BUNDLE_PROMPT_TAG) then bundle.panel
			else nil
		if target == nil then
			return
		end
		machinePart = if parent ~= nil and parent:IsA("BasePart") then parent else nil
		-- Tutorial: the stitch screen opens with the starter parts already in their slots.
		if target == stitch.panel and TutorialController.getStep() == "Stitch" then
			stitch.preselect(TutorialController.starterLoadout())
		end
		openOnly(target)
	end)
	RunService.Heartbeat:Connect(function()
		local machine = machinePart
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if machine == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		if (root.Position - machine.Position).Magnitude > STATION_LEAVE_DISTANCE then
			stitch.panel.close()
			bundle.panel.close()
		end
	end)

	-- No shop prompts before the first creature (spec 4.6): the bundle machine's prompt stays
	-- hidden until then. Prompts are per-client, so this only affects this player.
	local bundleUnlocked = false
	local function syncBundlePrompts(): ()
		for _, prompt in CollectionService:GetTagged(BUNDLE_PROMPT_TAG) do
			if prompt:IsA("ProximityPrompt") then
				prompt.Enabled = bundleUnlocked
			end
		end
	end
	CollectionService:GetInstanceAddedSignal(BUNDLE_PROMPT_TAG):Connect(syncBundlePrompts)

	-- Tutorial hints on the HUD and the stitch lever.
	local stopRidePulse: (() -> ())? = nil
	local function syncTutorialHints(step: TutorialController.Step?): ()
		stitch.setLeverHint(step == "Stitch")
		local pulseRide = step == "Ride"
		if pulseRide and stopRidePulse == nil then
			stopRidePulse = Theme.pulse(hud.rideButton)
		elseif not pulseRide and stopRidePulse ~= nil then
			stopRidePulse()
			stopRidePulse = nil
		end
	end
	TutorialController.onStepChanged(syncTutorialHints)
	syncTutorialHints(TutorialController.getStep())

	IslandController.onIslandEntered(function(displayName)
		hud.showMessage(displayName, Theme.colors.lime)
	end)
	ChallengeController.onStatusChanged(hud.setStatus)

	local pingMenu = PingMenu.create(hud.pingButton, PingController.ping, function(emoteId)
		if not PingController.emote(emoteId) then
			hud.showMessage("Hop off your creature to do that!", Color3.fromRGB(60, 150, 255))
		end
	end)
	hud.pingButton.Activated:Connect(pingMenu.toggle)
	-- Keyboard G / controller L1: open the ping row.
	ContextActionService:BindAction("TogglePings", function(_, state)
		if state == Enum.UserInputState.Begin then
			pingMenu.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
	Remotes.event("Notice").OnClientEvent:Connect(function(text: unknown)
		if type(text) == "string" then
			hud.showMessage(text, Color3.fromRGB(255, 200, 60))
		end
	end)

	-- Keyboard B / controller Y: bag. R / controller X: ride. Touch uses the on-screen buttons.
	ContextActionService:BindAction("ToggleInventory", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle(inventory.panel)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("ToggleRide", function(_, state)
		if state == Enum.UserInputState.Begin and CreatureController.hasCreature() then
			CreatureController.toggleRide()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	-- Controller B closes whatever is open, the usual "back" button.
	ContextActionService:BindAction("ClosePanel", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		for _, panel in panels do
			if panel.isOpen() then
				panel.close()
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)

	-- One reminder per session when today's free bundle is waiting (not during the tutorial).
	local dailyReminded = false
	DataController.onChanged(function(snapshot)
		if
			not dailyReminded
			and snapshot.tutorialDone
			and snapshot.dailyBundleDay < Daily.today()
		then
			dailyReminded = true
			task.delay(
				3,
				hud.showMessage,
				"Your free daily bundle is ready at the machine!",
				Theme.colors.lime
			)
		end
		inventory.render(snapshot)
		book.render(snapshot)
		stitch.render(snapshot)
		bundle.render(snapshot)
		hud.setCoins(snapshot.coins)
		bundleUnlocked = #snapshot.creatures > 0 or snapshot.tutorialDone
		syncBundlePrompts()
	end)

	local function syncRide(): ()
		hud.setRideState(CreatureController.hasCreature(), CreatureController.isRiding())
	end
	CreatureController.onStateChanged(syncRide)
	CreatureController.onMessage(function(message)
		hud.showMessage(message, Color3.fromRGB(60, 150, 255))
	end)
	syncRide()

	Remotes.event("PartCollected").OnClientEvent:Connect(function(partId: string)
		local definition = Parts.get(partId)
		if definition ~= nil then
			hud.showPartToast(definition)
		end
	end)
end

return UIController
