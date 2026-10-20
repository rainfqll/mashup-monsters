--!strict
-- UIController: builds and shows screens (inventory now; stitch station and book later).
-- UI only displays server state; it never decides outcomes.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataController = require(script.Parent.DataController)
local Hud = require(script.Parent.Parent.UI.Hud)
local InventoryScreen = require(script.Parent.Parent.UI.InventoryScreen)

local UIController = {}

function UIController.start(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "MashupHud"
	-- Survives respawns, so the inventory doesn't flash shut when the character resets.
	screen.ResetOnSpawn = false
	-- Keeps every button clear of the notch and Roblox's own top bar buttons.
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local hud = Hud.create(screen)
	local inventory = InventoryScreen.create(screen)

	local function toggleInventory(): ()
		if inventory.isOpen() then
			inventory.close()
		else
			inventory.open()
		end
	end

	hud.bagButton.Activated:Connect(toggleInventory)

	-- Keyboard B and controller Y open/close the bag (the on-screen button covers touch).
	ContextActionService:BindAction("ToggleInventory", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleInventory()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
	-- Controller B closes, the usual "back" button.
	ContextActionService:BindAction("CloseInventory", function(_, state)
		if state == Enum.UserInputState.Begin and inventory.isOpen() then
			inventory.close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)

	DataController.onChanged(inventory.render)

	Remotes.event("PartCollected").OnClientEvent:Connect(function(partId: string)
		local definition = Parts.get(partId)
		if definition ~= nil then
			hud.showPartToast(definition)
		end
	end)
end

return UIController
