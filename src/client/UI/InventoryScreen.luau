--!strict
-- Inventory screen: a grid of part cards with slot filter tabs. It only displays the
-- snapshot the server sent; nothing here changes what the player owns.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)

type Filter = "All" | Types.Slot

local FILTERS: { Filter } = { "All", "Head", "Body", "Legs", "Back" }
local SLOT_ORDER: { [Types.Slot]: number } = { Head = 1, Body = 2, Legs = 3, Back = 4 }

local HEADER_HEIGHT = 56
local TAB_HEIGHT = 48
local GAP = 10
local MIN_CARD_WIDTH = 120
-- Card height / width.
local CARD_ASPECT = 1.15

local OPEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

export type InventoryScreen = {
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	render: (snapshot: Types.PlayerSnapshot) -> (),
}

local function makeButton(name: string, text: string, maxText: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.AutoButtonColor = false
	Theme.text(button, maxText)
	button.BackgroundTransparency = 0
	button.BackgroundColor3 = Theme.colors.purple
	Theme.corner(button)
	Theme.outline(button, 3)
	Theme.pressable(button)
	return button
end

local function makeCard(definition: Types.PartDefinition, count: number): Frame
	local rarityColor = Rarities[definition.rarity].color

	local card = Instance.new("Frame")
	card.Name = definition.id
	card.BackgroundColor3 = Theme.colors.card
	Theme.corner(card)
	Theme.outline(card, 4, rarityColor)

	-- Color block standing in for the part's picture until real icons exist.
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.fromScale(0.5, 0.1)
	swatch.Size = UDim2.fromScale(0.5, 0.5)
	swatch.SizeConstraint = Enum.SizeConstraint.RelativeXX
	swatch.BackgroundColor3 = definition.colorTheme
	Theme.corner(swatch, UDim.new(0.2, 0))
	Theme.outline(swatch, 3)
	swatch.Parent = card

	local name = Instance.new("TextLabel")
	name.Name = "PartName"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.8)
	name.Size = UDim2.fromScale(0.92, 0.2)
	name.Text = definition.displayName
	Theme.text(name, 22)
	name.Parent = card

	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.AnchorPoint = Vector2.new(0.5, 1)
	rarity.Position = UDim2.fromScale(0.5, 0.95)
	rarity.Size = UDim2.fromScale(0.8, 0.14)
	rarity.Text = definition.rarity
	Theme.text(rarity, 16)
	rarity.TextColor3 = rarityColor
	rarity.Parent = card

	if count > 1 then
		local badge = Instance.new("TextLabel")
		badge.Name = "Count"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -6, 0, 6)
		badge.Size = UDim2.fromScale(0.34, 0.16)
		badge.Text = `x{count}`
		Theme.text(badge, 20)
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = Theme.colors.limeDark
		Theme.corner(badge, UDim.new(0.5, 0))
		Theme.outline(badge, 2)
		badge.Parent = card
	end

	return card
end

local InventoryScreen = {}

function InventoryScreen.create(parent: ScreenGui): InventoryScreen
	local filter: Filter = "All"
	local lastSnapshot: Types.PlayerSnapshot = { coins = 0, inventory = {} }
	local isOpen = false

	local panel = Instance.new("Frame")
	panel.Name = "Inventory"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.8, 0.86)
	panel.BackgroundColor3 = Theme.colors.purpleDeep
	panel.Visible = false
	-- Keeps controller focus inside the panel while it is open.
	panel.SelectionGroup = true
	Theme.corner(panel, UDim.new(0, 20))
	Theme.outline(panel, 5)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(760, 560)
	sizeLimit.Parent = panel
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, GAP)
	padding.PaddingBottom = UDim.new(0, GAP)
	padding.PaddingLeft = UDim.new(0, GAP)
	padding.PaddingRight = UDim.new(0, GAP)
	padding.Parent = panel

	-- Header: title, coins, close
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.45, 0, 0, HEADER_HEIGHT)
	title.Text = "My Parts"
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.text(title, 36)
	title.Parent = panel

	local coins = Instance.new("TextLabel")
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0)
	coins.Position = UDim2.new(1, -(HEADER_HEIGHT + GAP), 0, 4)
	coins.Size = UDim2.new(0.3, 0, 0, HEADER_HEIGHT - 8)
	Theme.text(coins, 26)
	coins.BackgroundTransparency = 0
	coins.BackgroundColor3 = Theme.colors.limeDark
	Theme.corner(coins, UDim.new(0.5, 0))
	Theme.outline(coins, 3)
	coins.Parent = panel

	local closeButton = makeButton("Close", "X", 32)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT)
	closeButton.BackgroundColor3 = Color3.fromRGB(230, 80, 110)
	closeButton.Parent = panel

	-- Slot filter tabs
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(0, HEADER_HEIGHT + GAP)
	tabs.Size = UDim2.new(1, 0, 0, TAB_HEIGHT)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, GAP)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local tabButtons: { [Filter]: TextButton } = {}
	local tabWidth = 1 / #FILTERS
	local tabGapShare = GAP * (#FILTERS - 1) / #FILTERS
	for index, name in FILTERS do
		local tab = makeButton(name, name, 24)
		tab.LayoutOrder = index
		tab.Size = UDim2.new(tabWidth, -tabGapShare, 1, 0)
		tab.Parent = tabs
		tabButtons[name] = tab
	end

	-- Card grid
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_HEIGHT + GAP * 2)
	grid.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_HEIGHT + GAP * 2))
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = Theme.colors.lime
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Selectable = false
	grid.Parent = panel
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 6)
	gridPadding.PaddingLeft = UDim.new(0, 6)
	gridPadding.PaddingRight = UDim.new(0, 14)
	gridPadding.PaddingBottom = UDim.new(0, 6)
	gridPadding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.AnchorPoint = Vector2.new(0.5, 0.5)
	empty.Position = UDim2.fromScale(0.5, 0.6)
	empty.Size = UDim2.fromScale(0.8, 0.2)
	empty.Text = "Touch glowing bubbles to find parts!"
	Theme.text(empty, 28)
	empty.TextColor3 = Theme.colors.textDim
	empty.Visible = false
	empty.Parent = panel

	-- Reflow instead of shrinking: more columns on wide screens, at least 3 on a phone.
	-- On short landscape phones, also add columns until a whole card fits the visible height,
	-- otherwise every card shows cut in half.
	local function resizeCells(): ()
		local width = grid.AbsoluteSize.X - 20 - grid.ScrollBarThickness
		local height = grid.AbsoluteSize.Y - 12
		if width <= 0 or height <= 0 then
			return
		end
		local maxCellWidth = math.max(MIN_CARD_WIDTH * 0.75, height / CARD_ASPECT)
		local columns = math.clamp(math.floor(width / (MIN_CARD_WIDTH + GAP)), 3, 6)
		columns =
			math.clamp(math.max(columns, math.ceil((width + GAP) / (maxCellWidth + GAP))), 3, 8)
		local cellWidth = math.floor((width - GAP * (columns - 1)) / columns)
		gridLayout.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * CARD_ASPECT))
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCells)

	local function render(snapshot: Types.PlayerSnapshot): ()
		lastSnapshot = snapshot
		coins.Text = `Coins: {snapshot.coins}`

		for name, tab in tabButtons do
			tab.BackgroundColor3 = if name == filter
				then Theme.colors.limeDark
				else Theme.colors.purple
		end

		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local owned: { Types.PartDefinition } = {}
		for _, definition in Parts.list do
			local count = snapshot.inventory[definition.id]
			if count ~= nil and count > 0 and (filter == "All" or definition.slot == filter) then
				table.insert(owned, definition)
			end
		end
		table.sort(owned, function(a, b)
			if a.slot ~= b.slot then
				return SLOT_ORDER[a.slot] < SLOT_ORDER[b.slot]
			end
			local ra, rb = Rarities[a.rarity].order, Rarities[b.rarity].order
			if ra ~= rb then
				return ra > rb
			end
			return a.displayName < b.displayName
		end)

		for index, definition in owned do
			local card = makeCard(definition, snapshot.inventory[definition.id])
			card.LayoutOrder = index
			card.Parent = grid
		end

		empty.Text = if filter == "All"
			then "Touch glowing bubbles to find parts!"
			else `No {filter} parts yet. Keep exploring!`
		empty.Visible = #owned == 0
	end

	for name, tab in tabButtons do
		tab.Activated:Connect(function()
			filter = name
			grid.CanvasPosition = Vector2.zero
			render(lastSnapshot)
		end)
	end

	local function open(): ()
		if isOpen then
			return
		end
		isOpen = true
		panel.Visible = true
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, OPEN_INFO, { Scale = 1 }):Play()
		resizeCells()
		-- Always start at the top, where the Head parts are.
		grid.CanvasPosition = Vector2.zero
		render(lastSnapshot)
		-- Only move controller focus if the player is already using one.
		if string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil then
			GuiService.SelectedObject = tabButtons[filter]
		end
	end

	local function close(): ()
		if not isOpen then
			return
		end
		isOpen = false
		panel.Visible = false
		if GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
	end

	closeButton.Activated:Connect(close)
	panel.Parent = parent

	return {
		open = open,
		close = close,
		isOpen = function()
			return isOpen
		end,
		render = function(snapshot: Types.PlayerSnapshot)
			lastSnapshot = snapshot
			if isOpen then
				render(snapshot)
			end
		end,
	}
end

return InventoryScreen
