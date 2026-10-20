--!strict
-- One part shown as a card: color block (stand-in for a picture), name, rarity, and an
-- optional count badge. Used by the inventory, the creature book and the stitch picker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)

local LOCKED_COLOR = Color3.fromRGB(60, 40, 90)

export type Options = {
	count: number?,
	-- Not discovered yet: a dark "?" card that keeps the part a surprise.
	locked: boolean?,
	-- Makes the card a TextButton (for pickers) instead of a Frame.
	clickable: boolean?,
	-- Replaces the bottom line (rarity, or slot when locked), e.g. "Secret" for book secrets.
	label: string?,
}

local PartCard = {}

-- Card height / width that fits the layout below.
PartCard.ASPECT = 1.15

function PartCard.create(definition: Types.PartDefinition, options: Options?): GuiObject
	local opts: Options = options or {}
	local locked = opts.locked == true
	local rarityColor = if locked then Theme.colors.outline else Rarities[definition.rarity].color

	local card: GuiObject
	if opts.clickable then
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		Theme.pressable(button)
		card = button
	else
		card = Instance.new("Frame")
	end
	card.Name = definition.id
	card.BackgroundColor3 = Theme.colors.card
	Theme.corner(card)
	Theme.outline(card, 4, rarityColor)

	local swatch = Instance.new("TextLabel")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.fromScale(0.5, 0.1)
	swatch.Size = UDim2.fromScale(0.5, 0.5)
	swatch.SizeConstraint = Enum.SizeConstraint.RelativeXX
	swatch.Text = if locked then "?" else ""
	Theme.text(swatch, 40)
	swatch.BackgroundTransparency = 0
	swatch.BackgroundColor3 = if locked then LOCKED_COLOR else definition.colorTheme
	Theme.corner(swatch, UDim.new(0.2, 0))
	Theme.outline(swatch, 3)
	swatch.Parent = card

	local name = Instance.new("TextLabel")
	name.Name = "PartName"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.8)
	name.Size = UDim2.fromScale(0.92, 0.2)
	name.Text = if locked then "???" else definition.displayName
	Theme.text(name, 22)
	name.Parent = card

	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.AnchorPoint = Vector2.new(0.5, 1)
	rarity.Position = UDim2.fromScale(0.5, 0.95)
	rarity.Size = UDim2.fromScale(0.8, 0.14)
	rarity.Text = opts.label or (if locked then definition.slot else definition.rarity)
	Theme.text(rarity, 16)
	rarity.TextColor3 = if locked then Theme.colors.textDim else rarityColor
	rarity.Parent = card

	local count = opts.count
	if count ~= nil and count > 1 then
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

-- A scrolling grid of cards that reflows instead of shrinking: more columns on wide screens,
-- at least 3 on a phone, and on short landscape phones enough columns that a whole card fits
-- the visible height (otherwise every card shows cut in half).
function PartCard.grid(parent: GuiObject, minCardWidth: number): ScrollingFrame
	local gap = 10
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = Theme.colors.lime
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Selectable = false
	grid.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local function resize(): ()
		local width = grid.AbsoluteSize.X - 20 - grid.ScrollBarThickness
		local height = grid.AbsoluteSize.Y - 12
		if width <= 0 or height <= 0 then
			return
		end
		local maxCellWidth = math.max(minCardWidth * 0.75, height / PartCard.ASPECT)
		local columns = math.clamp(math.floor(width / (minCardWidth + gap)), 3, 6)
		columns =
			math.clamp(math.max(columns, math.ceil((width + gap) / (maxCellWidth + gap))), 3, 8)
		local cellWidth = math.floor((width - gap * (columns - 1)) / columns)
		layout.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * PartCard.ASPECT))
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	return grid
end

-- Removes the cards from a grid made by PartCard.grid (keeps its layout objects).
function PartCard.clear(grid: ScrollingFrame): ()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return PartCard
