--!strict
-- UIController: builds the HUD and screens and decides which one is open (only one at a time).
-- UI only displays server state; it never decides outcomes.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Trading = require(ReplicatedStorage.Shared.Config.Trading)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ChallengeController = require(script.Parent.ChallengeController)
local CreatureController = require(script.Parent.CreatureController)
local Daily = require(ReplicatedStorage.Shared.Daily)
local DataController = require(script.Parent.DataController)
local EggController = require(script.Parent.EggController)
local IslandController = require(script.Parent.IslandController)
local PingController = require(script.Parent.PingController)
local PortalController = require(script.Parent.PortalController)
local TradeController = require(script.Parent.TradeController)
local TutorialController = require(script.Parent.TutorialController)
local BookScreen = require(script.Parent.Parent.UI.BookScreen)
local BundleScreen = require(script.Parent.Parent.UI.BundleScreen)
local Hud = require(script.Parent.Parent.UI.Hud)
local InventoryScreen = require(script.Parent.Parent.UI.InventoryScreen)
local MapScreen = require(script.Parent.Parent.UI.MapScreen)
local Panel = require(script.Parent.Parent.UI.Panel)
local PassScreen = require(script.Parent.Parent.UI.PassScreen)
local PingMenu = require(script.Parent.Parent.UI.PingMenu)
local RevealOverlay = require(script.Parent.Parent.UI.RevealOverlay)
local StarterScreen = require(script.Parent.Parent.UI.StarterScreen)
local StitchScreen = require(script.Parent.Parent.UI.StitchScreen)
local TradeInvite = require(script.Parent.Parent.UI.TradeInvite)
local TradeScreen = require(script.Parent.Parent.UI.TradeScreen)
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
	local trade = TradeScreen.create(screen)
	local tradeInvite = TradeInvite.create(screen)
	local starter = StarterScreen.create(screen)
	local map = MapScreen.create(screen, PortalController.travel)
	local pass = PassScreen.create(screen, PortalController.buyPortalPass)
	local panels: { Panel.Panel } = {
		inventory.panel,
		book.panel,
		stitch.panel,
		bundle.panel,
		trade.panel,
		map.panel,
		pass.panel,
	}

	local function openOnly(target: Panel.Panel): ()
		-- Nothing else opens over the first-monster pop-up.
		if starter.panel.isOpen() then
			return
		end
		for _, panel in panels do
			if panel ~= target then
				panel.close()
			end
		end
		target.open()
	end

	local function toggle(target: Panel.Panel): ()
		if starter.panel.isOpen() then
			return
		end
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

	-- Maps and portals. The big map opens from the mini map; at a portal it becomes the travel
	-- menu if you own the Portal Pass, otherwise the pass pop-up explains it.
	local function closeAllExcept(keep: Panel.Panel?): ()
		for _, panel in panels do
			if panel ~= keep then
				panel.close()
			end
		end
	end
	hud.mapButton.Activated:Connect(function()
		if starter.panel.isOpen() then
			return
		end
		if map.panel.isOpen() then
			map.panel.close()
		else
			closeAllExcept(map.panel)
			map.openView()
		end
	end)
	PortalController.onPortalOpened(function(fromIsland)
		if starter.panel.isOpen() then
			return
		end
		if PortalController.hasPortalPass() then
			closeAllExcept(map.panel)
			map.openTravel(fromIsland, DataController.get())
		else
			closeAllExcept(pass.panel)
			pass.panel.open()
		end
	end)

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

	-- Tutorial hint on the HUD: the Ride button pulses until you hop on.
	local stopRidePulse: (() -> ())? = nil
	local function syncTutorialHints(step: TutorialController.Step?): ()
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

	-- An egg hatched: the same hatching show as bundles. If the part opens an island you haven't
	-- reached, say so: that is the reason to go back to the lab and stitch.
	EggController.onHatched(function(partId, isNew)
		local definition = Parts.get(partId)
		if definition == nil then
			return
		end
		reveal.play(definition, isNew, function()
			local snapshot = DataController.get()
			for _, island in Islands.list do
				local ability = island.requires
				if
					ability ~= nil
					and table.find(definition.abilities, ability)
					and not (snapshot ~= nil and snapshot.unlockedIslands[island.id])
				then
					hud.showMessage(
						`{Islands.abilityName(ability)}! Stitch it on at the lab to reach {island.displayName}.`,
						Theme.colors.lime
					)
					return
				end
			end
			hud.showMessage("Stitch it onto a monster at the lab!", Theme.colors.lime)
		end)
	end)

	IslandController.onIslandEntered(function(displayName)
		hud.showMessage(displayName, Theme.colors.lime)
	end)
	ChallengeController.onStatusChanged(hud.setStatus)

	TradeController.onInvite(function(fromUserId, fromName)
		tradeInvite.show(fromName, Trading.inviteSeconds, function(accept)
			TradeController.respond(fromUserId, accept)
		end)
	end)
	TradeController.onStateChanged(function(view)
		if view ~= nil and not trade.panel.isOpen() then
			for _, panel in panels do
				if panel ~= trade.panel then
					panel.close()
				end
			end
		end
		trade.show(view)
	end)

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
		-- A brand-new player builds their first monster before anything else.
		local needsStarter = not snapshot.starterMade
			and not snapshot.tutorialDone
			and #snapshot.creatures == 0
		if needsStarter and not starter.panel.isOpen() then
			for _, panel in panels do
				panel.close()
			end
			starter.panel.open()
		elseif not needsStarter and starter.panel.isOpen() then
			starter.panel.close()
		end
		inventory.render(snapshot)
		book.render(snapshot)
		stitch.render(snapshot)
		bundle.render(snapshot)
		trade.render(snapshot)
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
