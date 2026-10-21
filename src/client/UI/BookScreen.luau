--!strict
-- Creature book: every part in the game, with the ones you have never found shown as "?"
-- cards. Gives collectors a visible goal ("12 / 16") without spoiling what is left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combos = require(ReplicatedStorage.Shared.Config.Combos)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Panel = require(script.Parent.Panel)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

local SLOT_ORDER: { [Types.Slot]: number } = { Head = 1, Body = 2, Legs = 3, Back = 4 }
local MIN_CARD_WIDTH = 110

export type BookScreen = {
	panel: Panel.Panel,
	render: (snapshot: Types.PlayerSnapshot) -> (),
}

-- Book order is fixed (slot, then rarity) so a part's spot never moves when it is found.
local ENTRIES: { Types.PartDefinition } = {}
for _, definition in Parts.list do
	if not definition.free then
		table.insert(ENTRIES, definition)
	end
end
table.sort(ENTRIES, function(a, b)
	if a.slot ~= b.slot then
		return SLOT_ORDER[a.slot] < SLOT_ORDER[b.slot]
	end
	return Rarities[a.rarity].order < Rarities[b.rarity].order
end)

-- Secret Mashups go after the parts, shown as cards in their aura colour once stitched.
-- The card needs a PartDefinition, so each secret gets a display-only one.
local SECRET_CARDS: { Types.PartDefinition } = {}
for _, secret in Combos.secrets do
	table.insert(SECRET_CARDS, {
		id = `Secret_{secret.id}`,
		displayName = secret.displayName,
		slot = "Body",
		rarity = "Secret",
		abilities = {},
		stats = { speed = 0, jump = 0, swim = 0, glide = 0, carry = 0 },
		modelName = "",
		colorTheme = secret.auraColor,
	})
end

local BookScreen = {}

function BookScreen.create(parent: ScreenGui): BookScreen
	local gap = Panel.GAP
	local lastSnapshot: Types.PlayerSnapshot? = nil
	local panel = Panel.create(parent, "Book", "Creature Book")

	local progress = Instance.new("TextLabel")
	progress.Name = "Progress"
	progress.AnchorPoint = Vector2.new(1, 0)
	progress.Position = UDim2.new(1, -(Panel.HEADER_HEIGHT + gap), 0, 4)
	progress.Size = UDim2.new(0.45, 0, 0, Panel.HEADER_HEIGHT - 8)
	Theme.text(progress, 26)
	progress.BackgroundTransparency = 0
	progress.BackgroundColor3 = Theme.colors.limeDark
	Theme.corner(progress, UDim.new(0, 4))
	Theme.outline(progress, 3)
	progress.Parent = panel.frame

	local grid = PartCard.grid(panel.body, MIN_CARD_WIDTH)
	grid.Size = UDim2.fromScale(1, 1)

	local function render(): ()
		local snapshot = lastSnapshot
		if snapshot == nil then
			return
		end
		PartCard.clear(grid)
		local found = 0
		for index, definition in ENTRIES do
			local discovered = snapshot.discovered[definition.id] == true
			if discovered then
				found += 1
			end
			local card = PartCard.create(definition, { locked = not discovered })
			card.LayoutOrder = index
			card.Parent = grid
		end
		local secretsFound = 0
		for index, secret in Combos.secrets do
			local stitched = snapshot.secretsFound[secret.id] == true
			if stitched then
				secretsFound += 1
			end
			local card = PartCard.create(SECRET_CARDS[index], {
				locked = not stitched,
				label = if stitched then "Secret Mashup" else "Secret",
			})
			card.LayoutOrder = #ENTRIES + index
			card.Parent = grid
		end
		progress.Text = `Parts {found}/{#ENTRIES}  Secrets {secretsFound}/{#Combos.secrets}`
	end

	panel.onOpened(function()
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

return BookScreen
