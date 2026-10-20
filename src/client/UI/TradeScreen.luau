--!strict
-- Trade screen: what you give (top left), what your friend gives (top right), your bag (bottom)
-- to tap parts into the trade, and a Ready button. Shows exactly what the server says the
-- trade is (TradeView); every tap is a request the server checks (TradeService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Trading = require(ReplicatedStorage.Shared.Config.Trading)
local Types = require(ReplicatedStorage.Shared.Types)
local Panel = require(script.Parent.Panel)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

local READY_HEIGHT = 52
local MIN_CARD_WIDTH = 92

export type TradeScreen = {
	panel: Panel.Panel,
	show: (view: Types.TradeView?) -> (),
	render: (snapshot: Types.PlayerSnapshot) -> (),
}

local TradeScreen = {}

function TradeScreen.create(parent: ScreenGui): TradeScreen
	local gap = Panel.GAP
	local view: Types.TradeView? = nil
	local snapshot: Types.PlayerSnapshot? = nil
	-- True while the server is the one closing the panel, so closing doesn't send a cancel.
	local closingFromServer = false

	local panel = Panel.create(parent, "Trade", "Trade")

	local function offerBox(name: string, position: UDim2): (TextLabel, Frame)
		local box = Instance.new("Frame")
		box.Name = name
		box.Position = position
		box.Size = UDim2.new(0.5, -gap / 2, 0.42, 0)
		box.BackgroundColor3 = Theme.colors.card
		Theme.corner(box)
		Theme.outline(box, 3)
		box.Parent = panel.body
		local header = Instance.new("TextLabel")
		header.Name = "Header"
		header.Position = UDim2.fromOffset(8, 2)
		header.Size = UDim2.new(1, -16, 0.26, 0)
		header.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(header, 24)
		header.Parent = box
		local slots = Instance.new("Frame")
		slots.Name = "Slots"
		slots.Position = UDim2.new(0, 8, 0.28, 0)
		slots.Size = UDim2.new(1, -16, 0.7, -6)
		slots.BackgroundTransparency = 1
		slots.Parent = box
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.25, -6, 1, 0)
		grid.CellPadding = UDim2.fromOffset(6, 0)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = slots
		return header, slots
	end

	local myHeader, mySlots = offerBox("Mine", UDim2.fromScale(0, 0))
	local theirHeader, theirSlots = offerBox("Theirs", UDim2.new(0.5, gap / 2, 0, 0))

	local bagArea = Instance.new("Frame")
	bagArea.Name = "Bag"
	bagArea.Position = UDim2.new(0, 0, 0.42, gap)
	bagArea.Size = UDim2.new(0.68, -gap / 2, 0.58, -gap)
	bagArea.BackgroundTransparency = 1
	bagArea.Parent = panel.body
	local bag = PartCard.grid(bagArea, MIN_CARD_WIDTH)
	bag.Size = UDim2.fromScale(1, 1)

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.new(1, 0, 0.42, gap)
	side.Size = UDim2.new(0.32, -gap / 2, 0.58, -gap)
	side.BackgroundTransparency = 1
	side.Parent = panel.body

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 1, -(READY_HEIGHT + gap))
	Theme.text(status, 24)
	status.TextWrapped = true
	status.Parent = side

	local readyButton = Theme.button("Ready", "Ready!", 28)
	readyButton.AnchorPoint = Vector2.new(0, 1)
	readyButton.Position = UDim2.fromScale(0, 1)
	readyButton.Size = UDim2.new(1, 0, 0, READY_HEIGHT)
	readyButton.Parent = side

	local function sendOffer(offer: { string }): ()
		Remotes.event("TradeSetOffer"):FireServer(offer)
	end

	local function fillSlots(slots: Frame, offer: { string }, removable: boolean): ()
		for _, child in slots:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for index = 1, Trading.maxItems do
			local partId = offer[index]
			local definition = if partId ~= nil then Parts.get(partId) else nil
			if definition ~= nil then
				local card = PartCard.create(definition, { clickable = removable })
				card.LayoutOrder = index
				card.Parent = slots
				if removable then
					(card :: TextButton).Activated:Connect(function()
						local current = if view ~= nil then table.clone(view.myOffer) else {}
						table.remove(current, index)
						sendOffer(current)
					end)
				end
			else
				local empty = Instance.new("Frame")
				empty.LayoutOrder = index
				empty.BackgroundColor3 = Theme.colors.purpleDeep
				empty.BackgroundTransparency = 0.4
				Theme.corner(empty)
				empty.Parent = slots
			end
		end
	end

	local function renderBag(): ()
		PartCard.clear(bag)
		local current = view
		local data = snapshot
		if current == nil or data == nil then
			return
		end
		local used: { [string]: number } = {}
		for _, partId in current.myOffer do
			used[partId] = (used[partId] or 0) + 1
		end
		local now = os.time()
		local entries = {}
		for partId, count in data.inventory do
			local definition = Parts.get(partId)
			local left = count - (used[partId] or 0)
			if definition ~= nil and left > 0 then
				table.insert(entries, { definition = definition, left = left })
			end
		end
		table.sort(entries, function(a, b)
			return Rarities[a.definition.rarity].order > Rarities[b.definition.rarity].order
		end)
		for index, entry in entries do
			local lockedUntil = data.tradeLockUntil[entry.definition.id]
			local locked = lockedUntil ~= nil and lockedUntil > now
			local card = PartCard.create(entry.definition, {
				count = entry.left,
				clickable = not locked,
				label = if locked then "Too new" else nil,
			})
			card.LayoutOrder = index
			card.Parent = bag
			if not locked then
				(card :: TextButton).Activated:Connect(function()
					local offer = table.clone(current.myOffer)
					if #offer < Trading.maxItems then
						table.insert(offer, entry.definition.id)
						sendOffer(offer)
					end
				end)
			end
		end
	end

	local function render(): ()
		local current = view
		if current == nil then
			return
		end
		panel.title.Text = `Trade with {current.partnerName}`
		myHeader.Text = if current.myReady then "You give  (Ready!)" else "You give"
		theirHeader.Text = if current.theirReady
			then `{current.partnerName} gives  (Ready!)`
			else `{current.partnerName} gives`
		fillSlots(mySlots, current.myOffer, true)
		fillSlots(theirSlots, current.theirOffer, false)
		renderBag()
		status.Text = if current.countdown ~= nil
			then `Trading in {current.countdown}...`
			elseif current.message ~= nil then current.message
			elseif
				current.myReady and not current.theirReady
			then `Waiting for {current.partnerName}...`
			else "Tap your parts to add them. Check both sides, then press Ready!"
		readyButton.Text = if current.myReady then "Not ready" else "Ready!"
		readyButton.BackgroundColor3 = if current.myReady
			then Theme.colors.purple
			else Theme.colors.lime
	end

	readyButton.Activated:Connect(function()
		if view ~= nil then
			Remotes.event("TradeReady"):FireServer(not view.myReady)
		end
	end)

	panel.onClosed(function()
		if view ~= nil and not closingFromServer then
			Remotes.event("TradeCancel"):FireServer()
		end
	end)

	return {
		panel = panel,
		show = function(newView: Types.TradeView?)
			view = newView
			if newView == nil then
				if panel.isOpen() then
					closingFromServer = true
					panel.close()
					closingFromServer = false
				end
				return
			end
			if not panel.isOpen() then
				panel.open(readyButton)
			end
			render()
		end,
		render = function(newSnapshot: Types.PlayerSnapshot)
			snapshot = newSnapshot
			if view ~= nil then
				renderBag()
			end
		end,
	}
end

return TradeScreen
