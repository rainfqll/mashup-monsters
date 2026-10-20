--!strict
-- Always-on HUD: Parts and Book buttons (top-left), the Ride button (right side), and a
-- pop-up for short messages. Layout keeps clear of Roblox's own controls: the lower-left
-- belongs to the thumbstick, the lower-right to the jump button, the top to the Roblox menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)

local TOAST_HOLD_SECONDS = 1.8
local TOAST_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOAST_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type Hud = {
	bagButton: TextButton,
	bookButton: TextButton,
	rideButton: TextButton,
	showPartToast: (definition: Types.PartDefinition) -> (),
	showMessage: (text: string, color: Color3?) -> (),
	setRideState: (hasCreature: boolean, riding: boolean) -> (),
	setCoins: (coins: number) -> (),
}

-- Sized from screen height so it stays thumb-sized on phones and modest on monitors.
local function sideButton(name: string, text: string, color: Color3): (TextButton, UIScale)
	local button = Theme.button(name, text, 26)
	button.Size = UDim2.fromScale(0.15, 0.15)
	button.SizeConstraint = Enum.SizeConstraint.RelativeYY
	button.BackgroundColor3 = color
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner ~= nil then
		corner.CornerRadius = UDim.new(0.25, 0)
	end
	local stroke = button:FindFirstChild("Border") :: UIStroke?
	if stroke ~= nil then
		stroke.Thickness = 4
	end
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(Theme.MIN_TOUCH + 8, Theme.MIN_TOUCH + 8)
	limit.MaxSize = Vector2.new(96, 96)
	limit.Parent = button
	local scale = button:FindFirstChildOfClass("UIScale") :: UIScale
	return button, scale
end

local Hud = {}

function Hud.create(parent: ScreenGui): Hud
	local leftColumn = Instance.new("Frame")
	leftColumn.Name = "LeftButtons"
	leftColumn.Position = UDim2.fromOffset(8, 8)
	leftColumn.Size = UDim2.fromScale(0.2, 0.6)
	leftColumn.BackgroundTransparency = 1
	leftColumn.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = leftColumn

	local bag, bagScale = sideButton("BagButton", "Parts", Theme.colors.lime)
	bag.LayoutOrder = 1
	bag.Parent = leftColumn

	local book = sideButton("BookButton", "Book", Theme.colors.purple)
	book.LayoutOrder = 2
	book.Parent = leftColumn

	-- Right side, above the jump button's area.
	local ride = sideButton("RideButton", "Ride", Theme.colors.lime)
	ride.AnchorPoint = Vector2.new(1, 0.5)
	ride.Position = UDim2.new(1, -8, 0.42, 0)
	ride.Visible = false
	ride.Parent = parent

	-- Coins, top-right: the one corner Roblox's own controls leave free on every device.
	local coinPill = Instance.new("TextLabel")
	coinPill.Name = "Coins"
	coinPill.AnchorPoint = Vector2.new(1, 0)
	coinPill.Position = UDim2.new(1, -8, 0, 8)
	coinPill.Size = UDim2.fromScale(0.3, 0.09)
	coinPill.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coinPill.Text = "0"
	Theme.text(coinPill, 28)
	coinPill.BackgroundTransparency = 0
	coinPill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	Theme.corner(coinPill, UDim.new(0.5, 0))
	Theme.outline(coinPill, 4)
	local coinLimit = Instance.new("UISizeConstraint")
	coinLimit.MinSize = Vector2.new(96, 36)
	coinLimit.MaxSize = Vector2.new(170, 56)
	coinLimit.Parent = coinPill
	local coinScale = Instance.new("UIScale")
	coinScale.Parent = coinPill
	coinPill.Parent = parent
	local shownCoins: number? = nil

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.08)
	toast.Size = UDim2.fromScale(0.5, 0.11)
	Theme.text(toast, 30)
	toast.BackgroundTransparency = 0
	toast.BackgroundColor3 = Theme.colors.purpleDeep
	toast.Visible = false
	Theme.corner(toast, UDim.new(0.5, 0))
	local toastStroke = Theme.outline(toast, 5)
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(520, 70)
	toastLimit.MinSize = Vector2.new(240, 44)
	toastLimit.Parent = toast
	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingLeft = UDim.new(0, 16)
	toastPadding.PaddingRight = UDim.new(0, 16)
	toastPadding.Parent = toast
	local toastScale = Instance.new("UIScale")
	toastScale.Parent = toast
	toast.Parent = parent

	-- Each new message restarts the toast; the token stops an older timer hiding the newer one.
	local toastToken = 0

	local function showMessage(text: string, color: Color3?): ()
		toastToken += 1
		local token = toastToken

		toast.Text = text
		toastStroke.Color = color or Theme.colors.lime
		toast.Visible = true
		toastScale.Scale = 0.4
		TweenService:Create(toastScale, TOAST_IN, { Scale = 1 }):Play()

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

	local function showPartToast(definition: Types.PartDefinition): ()
		showMessage(`+ {definition.displayName}!`, Rarities[definition.rarity].color)
		Theme.pop(bagScale)
	end

	local function setRideState(hasCreature: boolean, riding: boolean): ()
		ride.Visible = hasCreature
		ride.Text = if riding then "Hop off" else "Ride"
		ride.BackgroundColor3 = if riding then Theme.colors.purple else Theme.colors.lime
	end

	local function setCoins(coins: number): ()
		coinPill.Text = `{coins} coins`
		-- Pop only on gains, so spending doesn't look like a reward.
		if shownCoins ~= nil and coins > shownCoins then
			Theme.pop(coinScale)
		end
		shownCoins = coins
	end

	return {
		bagButton = bag,
		bookButton = book,
		rideButton = ride,
		showPartToast = showPartToast,
		showMessage = showMessage,
		setRideState = setRideState,
		setCoins = setCoins,
	}
end

return Hud
