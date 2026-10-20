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
local CreatureController = require(script.Parent.CreatureController)
local DataController = require(script.Parent.DataController)
local BookScreen = require(script.Parent.Parent.UI.BookScreen)
local Hud = require(script.Parent.Parent.UI.Hud)
local InventoryScreen = require(script.Parent.Parent.UI.InventoryScreen)
local Panel = require(script.Parent.Parent.UI.Panel)
local StitchScreen = require(script.Parent.Parent.UI.StitchScreen)

local STITCH_PROMPT_TAG = "StitchPrompt"
-- Walking this far from the station closes its screen (the server would refuse a stitch anyway).
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
	local panels: { Panel.Panel } = { inventory.panel, book.panel, stitch.panel }

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

	-- Opening the stitch screen from the station's prompt; leaving the station closes it.
	local stationPart: BasePart? = nil
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, STITCH_PROMPT_TAG) then
			local parent = prompt.Parent
			stationPart = if parent ~= nil and parent:IsA("BasePart") then parent else nil
			openOnly(stitch.panel)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local station = stationPart
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if stitch.panel.isOpen() and station ~= nil and root ~= nil and root:IsA("BasePart") then
			if (root.Position - station.Position).Magnitude > STATION_LEAVE_DISTANCE then
				stitch.panel.close()
			end
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

	DataController.onChanged(function(snapshot)
		inventory.render(snapshot)
		book.render(snapshot)
		stitch.render(snapshot)
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
