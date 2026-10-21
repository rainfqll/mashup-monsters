--!strict
-- Inventory screen: a grid of part cards with slot filter tabs. It only displays the
-- snapshot the server sent; nothing here changes what the player owns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Panel = require(script.Parent.Panel)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

type Filter = "All" | Types.Slot

local FILTERS: { Filter } = { "All", "Head", "Body", "Legs", "Back" }
local SLOT_ORDER: { [Types.Slot]: number } = { Head = 1, Body = 2, Legs = 3, Back = 4 }

local TAB_HEIGHT = 48
local MIN_CARD_WIDTH = 120

export type InventoryScreen = {
	panel: Panel.Panel,
	render: (snapshot: Types.PlayerSnapshot) -> (),
}

local InventoryScreen = {}

function InventoryScreen.create(parent: ScreenGui): InventoryScreen
	local gap = Panel.GAP
	local filter: Filter = "All"
	local lastSnapshot: Types.PlayerSnapshot? = nil

	local panel = Panel.create(parent, "Inventory", "My Parts")

	local coins = Instance.new("TextLabel")
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0)
	coins.Position = UDim2.new(1, -(Panel.HEADER_HEIGHT + gap), 0, 4)
	coins.Size = UDim2.new(0.3, 0, 0, Panel.HEADER_HEIGHT - 8)
	Theme.text(coins, 26)
	coins.BackgroundTransparency = 0
	coins.BackgroundColor3 = Theme.colors.limeDark
	Theme.corner(coins, UDim.new(0, 6))
	Theme.outline(coins, 3)
	coins.Parent = panel.frame

	local tabs = Panel.tabRow(panel.body, FILTERS :: { string }, TAB_HEIGHT, 24)

	local grid = PartCard.grid(panel.body, MIN_CARD_WIDTH)
	grid.Position = UDim2.fromOffset(0, TAB_HEIGHT + gap)
	grid.Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + gap))

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.AnchorPoint = Vector2.new(0.5, 0.5)
	empty.Position = UDim2.fromScale(0.5, 0.55)
	empty.Size = UDim2.fromScale(0.8, 0.2)
	Theme.text(empty, 28)
	empty.TextColor3 = Theme.colors.textDim
	empty.Visible = false
	empty.Parent = panel.body

	local function render(): ()
		local snapshot = lastSnapshot
		if snapshot == nil then
			return
		end
		coins.Text = `Coins: {snapshot.coins}`
		tabs.select(filter)
		PartCard.clear(grid)

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
			local card = PartCard.create(definition, { count = snapshot.inventory[definition.id] })
			card.LayoutOrder = index
			card.Parent = grid
		end

		empty.Text = if filter == "All"
			then "Touch glowing bubbles to find parts!"
			else `No {filter} parts yet. Keep exploring!`
		empty.Visible = #owned == 0
	end

	for name, tab in tabs.buttons do
		tab.Activated:Connect(function()
			filter = name :: Filter
			grid.CanvasPosition = Vector2.zero
			render()
		end)
	end

	panel.onOpened(function()
		-- Always start at the top, where the Head parts are.
		grid.CanvasPosition = Vector2.zero
		render()
	end)

	return {
		panel = panel,
		render = function(snapshot: Types.PlayerSnapshot)
			lastSnapshot = snapshot
			if panel.isOpen() then
				render()
			end
		end,
	}
end

return InventoryScreen
