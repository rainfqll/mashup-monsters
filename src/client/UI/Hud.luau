--!strict
-- Always-on HUD: Parts and Book buttons (top-left), the mini map and coins (top-right), the
-- Ride button (right side), and a pop-up for short messages. Layout keeps clear of Roblox's own controls: the lower-left
-- belongs to the thumbstick, the lower-right to the jump button, the top to the Roblox menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local MiniMap = require(script.Parent.MiniMap)
local Theme = require(script.Parent.Theme)

local TOAST_HOLD_SECONDS = 1.8
local TOAST_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOAST_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type Hud = {
	bagButton: TextButton,
	bookButton: TextButton,
	pingButton: TextButton,
	rideButton: TextButton,
	-- The mini map: tapping it opens the big map.
	mapButton: TextButton,
	showPartToast: (definition: Types.PartDefinition) -> (),
	showMessage: (text: string, color: Color3?) -> (),
	setRideState: (hasCreature: boolean, riding: boolean) -> (),
	setCoins: (coins: number) -> (),
	-- A line under the toast for ongoing things (ring course progress); nil hides it.
	setStatus: (text: string?) -> (),
}

-- Sized from screen height so it stays thumb-sized on phones and modest on monitors.
local function sideButton(name: string, text: string, color: Color3): (TextButton, UIScale)
	local button = Theme.button(name, text, 26)
	button.Size = UDim2.fromScale(0.15, 0.15)
	button.SizeConstraint = Enum.SizeConstraint.RelativeYY
	button.BackgroundColor3 = color
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner ~= nil then
		corner.CornerRadius = UDim.new(0, 10)
	end
	local stroke = button:FindFirstChild("Border") :: UIStroke?
	if stroke ~= nil then
		stroke.Color = Theme.colors.gold
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
	-- Ordinary buttons are slate; only the main action keeps the green.
	book.LayoutOrder = 2
	book.Parent = leftColumn

	-- Pings and emotes: talking without chat.
	local ping = sideButton("PingButton", "Ping", Theme.colors.purple)
	ping.LayoutOrder = 3
	ping.Parent = leftColumn

	-- Right side, above the jump button's area.
	local ride = sideButton("RideButton", "Ride", Theme.colors.lime)
	ride.AnchorPoint = Vector2.new(1, 0.5)
	ride.Position = UDim2.new(1, -8, 0.42, 0)
	ride.Visible = false
	ride.Parent = parent

	-- Top-right, the one corner Roblox's own controls leave free on every device: the mini map
	-- in the corner and the coins just left of it.
	local miniMap = MiniMap.create(parent)
	local coinPill = Instance.new("TextLabel")
	coinPill.Name = "Coins"
	coinPill.AnchorPoint = Vector2.new(1, 0)
	local function placeCoins(): ()
		coinPill.Position = UDim2.new(1, -(16 + miniMap.frame.AbsoluteSize.X), 0, 8)
	end
	miniMap.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCoins)
	placeCoins()
	coinPill.Size = UDim2.fromScale(0.3, 0.09)
	coinPill.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coinPill.Text = "0"
	Theme.text(coinPill, 28)
	coinPill.TextColor3 = Theme.colors.coin
	coinPill.BackgroundTransparency = 0.1
	coinPill.BackgroundColor3 = Theme.colors.purpleDeep
	Theme.corner(coinPill, UDim.new(0, 8))
	Theme.outline(coinPill, 4, Theme.colors.gold)
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
	-- Below the coins, so the two never overlap on narrow phones.
	toast.Position = UDim2.fromScale(0.5, 0.17)
	toast.Size = UDim2.fromScale(0.5, 0.11)
	Theme.text(toast, 30)
	toast.BackgroundTransparency = 0.08
	toast.BackgroundColor3 = Theme.colors.purpleDeep
	toast.Visible = false
	Theme.corner(toast, UDim.new(0, 8))
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

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.fromScale(0.5, 0.3)
	status.Size = UDim2.fromScale(0.3, 0.08)
	Theme.text(status, 28)
	status.TextColor3 = Theme.colors.lime
	status.Visible = false
	local statusLimit = Instance.new("UISizeConstraint")
	statusLimit.MaxSize = Vector2.new(320, 50)
	statusLimit.MinSize = Vector2.new(160, 32)
	statusLimit.Parent = status
	status.Parent = parent

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

	local function setStatus(text: string?): ()
		status.Visible = text ~= nil
		status.Text = text or ""
	end

	return {
		bagButton = bag,
		bookButton = book,
		pingButton = ping,
		rideButton = ride,
		mapButton = miniMap.button,
		showPartToast = showPartToast,
		showMessage = showMessage,
		setRideState = setRideState,
		setCoins = setCoins,
		setStatus = setStatus,
	}
end

return Hud
