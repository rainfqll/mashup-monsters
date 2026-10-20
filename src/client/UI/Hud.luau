--!strict
-- Always-on HUD: the bag button that opens the inventory, and the "got a part" pop-up.
-- The bag sits top-left: the lower-left belongs to the thumbstick, lower-right to jump.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)

local TOAST_HOLD_SECONDS = 1.6
local TOAST_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOAST_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type Hud = {
	bagButton: TextButton,
	showPartToast: (definition: Types.PartDefinition) -> (),
}

local Hud = {}

function Hud.create(parent: ScreenGui): Hud
	local bag = Instance.new("TextButton")
	bag.Name = "BagButton"
	bag.Position = UDim2.fromOffset(8, 8)
	-- Sized from screen height so it stays thumb-sized on phones and modest on monitors.
	bag.Size = UDim2.fromScale(0.15, 0.15)
	bag.SizeConstraint = Enum.SizeConstraint.RelativeYY
	bag.Text = "Parts"
	bag.AutoButtonColor = false
	Theme.text(bag, 26)
	bag.BackgroundTransparency = 0
	bag.BackgroundColor3 = Theme.colors.lime
	Theme.corner(bag, UDim.new(0.25, 0))
	Theme.outline(bag, 4)
	local bagLimit = Instance.new("UISizeConstraint")
	bagLimit.MinSize = Vector2.new(Theme.MIN_TOUCH + 8, Theme.MIN_TOUCH + 8)
	bagLimit.MaxSize = Vector2.new(96, 96)
	bagLimit.Parent = bag
	local bagScale = Theme.pressable(bag)
	bag.Parent = parent

	local toast = Instance.new("TextLabel")
	toast.Name = "PartToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.08)
	toast.Size = UDim2.fromScale(0.42, 0.11)
	Theme.text(toast, 34)
	toast.BackgroundTransparency = 0
	toast.BackgroundColor3 = Theme.colors.purpleDeep
	toast.Visible = false
	Theme.corner(toast, UDim.new(0.5, 0))
	local toastStroke = Theme.outline(toast, 5)
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(420, 70)
	toastLimit.MinSize = Vector2.new(220, 44)
	toastLimit.Parent = toast
	local toastScale = Instance.new("UIScale")
	toastScale.Parent = toast
	toast.Parent = parent

	-- Each new pickup restarts the toast; the token stops an older timer hiding the newer one.
	local toastToken = 0

	local function showPartToast(definition: Types.PartDefinition): ()
		toastToken += 1
		local token = toastToken

		toast.Text = `+ {definition.displayName}!`
		toastStroke.Color = Rarities[definition.rarity].color
		toast.Visible = true
		toastScale.Scale = 0.4
		TweenService:Create(toastScale, TOAST_IN, { Scale = 1 }):Play()
		Theme.pop(bagScale)

		task.delay(TOAST_HOLD_SECONDS, function()
			if token ~= toastToken then
				return
			end
			local out = TweenService:Create(toastScale, TOAST_OUT, { Scale = 0 })
			out.Completed:Once(function()
				if token == toastToken then
					toast.Visible = false
				end
			end)
			out:Play()
		end)
	end

	return {
		bagButton = bag,
		showPartToast = showPartToast,
	}
end

return Hud
