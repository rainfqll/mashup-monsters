--!strict
-- Bundle machine screen: price, the real drop chances (from Config/Bundles, the same table the
-- server rolls with), and an Open button. The server rolls and saves the part; this screen then
-- plays the hatching reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bundles = require(ReplicatedStorage.Shared.Config.Bundles)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Panel = require(script.Parent.Panel)
local RevealOverlay = require(script.Parent.RevealOverlay)
local Theme = require(script.Parent.Theme)

local OPEN_HEIGHT = 56

export type BundleScreen = {
	panel: Panel.Panel,
	render: (snapshot: Types.PlayerSnapshot) -> (),
}

local BundleScreen = {}

function BundleScreen.create(
	parent: ScreenGui,
	reveal: RevealOverlay.RevealOverlay,
	showMessage: (string, Color3?) -> ()
): BundleScreen
	local gap = Panel.GAP
	local lastSnapshot: Types.PlayerSnapshot? = nil
	local opening = false

	local panel = Panel.create(parent, "Bundles", "Mystery Bundle")

	-- Left: the egg you are buying.
	local eggArea = Instance.new("Frame")
	eggArea.Name = "EggArea"
	eggArea.Size = UDim2.new(0.4, -gap / 2, 1, 0)
	eggArea.BackgroundColor3 = Theme.colors.card
	Theme.corner(eggArea)
	Theme.outline(eggArea, 3)
	eggArea.Parent = panel.body

	-- Part of the Day: the same for everyone today, and more likely inside its rarity.
	local featured = Instance.new("TextLabel")
	featured.Name = "PartOfTheDay"
	featured.Position = UDim2.fromScale(0.04, 0.03)
	featured.Size = UDim2.fromScale(0.92, 0.16)
	Theme.text(featured, 20)
	featured.TextColor3 = Theme.colors.lime
	featured.Parent = eggArea

	local egg = Instance.new("Frame")
	egg.Name = "Egg"
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.fromScale(0.5, 0.48)
	egg.Size = UDim2.fromScale(0.4, 0.5)
	egg.BackgroundColor3 = Color3.fromRGB(255, 245, 225)
	Theme.corner(egg, UDim.new(0.5, 0))
	Theme.outline(egg, 4)
	local eggAspect = Instance.new("UIAspectRatioConstraint")
	eggAspect.AspectRatio = 0.78
	eggAspect.Parent = egg
	egg.Parent = eggArea

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.AnchorPoint = Vector2.new(0.5, 1)
	price.Position = UDim2.new(0.5, 0, 1, -6)
	price.Size = UDim2.new(1, -12, 0.2, 0)
	price.Text = `{Bundles.price} coins`
	Theme.text(price, 30)
	price.TextColor3 = Theme.colors.coin
	price.Parent = eggArea

	-- Right: chances and the Open button.
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0.6, -gap / 2, 1, 0)
	right.BackgroundTransparency = 1
	right.Parent = panel.body

	-- Heading on top, chances in a 2x2 grid below: on short phone screens a single column
	-- of five rows made the text too small to read.
	local oddsHeight = UDim2.new(1, 0, 1, -(OPEN_HEIGHT + gap))
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, 0, oddsHeight.Y.Scale * 0.3, oddsHeight.Y.Offset * 0.3)
	heading.Text = "Chances"
	heading.TextXAlignment = Enum.TextXAlignment.Left
	Theme.text(heading, 30)
	heading.Parent = right

	local odds = Instance.new("Frame")
	odds.Name = "Odds"
	odds.Position = UDim2.new(0, 0, heading.Size.Y.Scale, heading.Size.Y.Offset)
	odds.Size = UDim2.new(1, 0, oddsHeight.Y.Scale * 0.7, oddsHeight.Y.Offset * 0.7)
	odds.BackgroundTransparency = 1
	odds.Parent = right
	local oddsGrid = Instance.new("UIGridLayout")
	oddsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	oddsGrid.CellPadding = UDim2.fromOffset(gap, 4)
	oddsGrid.CellSize = UDim2.new(0.5, -gap / 2, 0.5, -2)
	oddsGrid.Parent = odds

	local total = 0
	for _, entry in Bundles.odds do
		total += entry.weight
	end
	for index, entry in Bundles.odds do
		local row = Instance.new("TextLabel")
		row.Name = entry.rarity
		row.LayoutOrder = index
		row.Text = `{entry.rarity}  {math.floor(entry.weight / total * 100 + 0.5)}%`
		row.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(row, 30)
		row.TextColor3 = Rarities[entry.rarity].color
		row.Parent = odds
	end

	local openButton = Theme.button("Open", "Open!", 32)
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.fromScale(0, 1)
	openButton.Size = UDim2.new(1, 0, 0, OPEN_HEIGHT)
	openButton.Parent = right

	local function dailyReady(): boolean
		return lastSnapshot ~= nil and lastSnapshot.dailyBundleDay < Daily.today()
	end

	local function render(): ()
		local coins = if lastSnapshot ~= nil then lastSnapshot.coins else 0
		local free = dailyReady()
		local canAfford = free or coins >= Bundles.price
		local ready = canAfford and not opening
		local today = Parts.get(Daily.partOfTheDay(Daily.today()))
		featured.Text = if today ~= nil then `Lucky part: {today.displayName}!` else ""
		price.Text = if free then "FREE today!" else `{Bundles.price} coins`
		openButton.Text = if opening
			then "..."
			elseif free then "Open your FREE bundle!"
			elseif canAfford then `Open! ({Bundles.price} coins)`
			else `Need {Bundles.price - coins} more coins`
		openButton.BackgroundColor3 = if ready then Theme.colors.lime else Theme.colors.card
		openButton.Active = ready
	end

	openButton.Activated:Connect(function()
		if not openButton.Active then
			return
		end
		opening = true
		render()
		local before = lastSnapshot
		local kind = if dailyReady() then "daily" else nil
		task.spawn(function()
			local ok, partId, message = pcall(function()
				return Remotes.func("OpenBundle"):InvokeServer(kind)
			end)
			opening = false
			local definition = if ok and type(partId) == "string" then Parts.get(partId) else nil
			if definition == nil then
				local reason = if ok and type(message) == "string"
					then message
					else "Something went wrong. Try again!"
				showMessage(reason, Theme.colors.danger)
				render()
				return
			end
			-- "NEW!" if the book didn't have it before this bundle.
			local isNew = before == nil or before.discovered[definition.id] ~= true
			panel.close()
			reveal.play(definition, isNew, function()
				panel.open(openButton)
			end)
		end)
	end)

	panel.onOpened(render)

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

return BundleScreen
