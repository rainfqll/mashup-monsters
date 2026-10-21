--!strict
-- The "Make your first Mashup!" pop-up (spec 4.8). New players build their first monster by
-- flipping each slot between the three starter part sets, with a live 3D preview and a line
-- saying what it can do and where that leads. The server checks the choice and stitches it
-- (CreateStarter). No close button: you need a monster to play, and it only shows until then.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Starters = require(ReplicatedStorage.Shared.Config.Starters)
local Types = require(ReplicatedStorage.Shared.Types)
local CreaturePreview = require(script.Parent.CreaturePreview)
local Panel = require(script.Parent.Panel)
local PartIcon = require(script.Parent.PartIcon)
local Theme = require(script.Parent.Theme)

local BOTTOM_HEIGHT = 52
local ARROW_WIDTH = 48
-- The 3D preview is rebuilt this long after the last tap, so flicking through parts stays smooth.
local PREVIEW_DELAY = 0.15
local SLOT_NAMES: { [Types.Slot]: string } = {
	Head = "Head",
	Body = "Body",
	Legs = "Arms + Legs",
	Back = "Back",
}

export type StarterScreen = {
	panel: Panel.Panel,
	-- Called once the server has made the monster (after the celebration).
	onCreated: (listener: () -> ()) -> (),
}

-- `icons` holds one ready-made 3D picture per option; flipping only changes which one shows.
type Row = { card: TextButton, iconHolder: Frame, name: TextLabel, icons: { [string]: GuiObject } }

local StarterScreen = {}

function StarterScreen.create(parent: ScreenGui): StarterScreen
	local gap = Panel.GAP
	local createdListeners: { () -> () } = {}
	local busy = false

	local panel = Panel.create(parent, "Starter", "Make your first Mashup!")
	panel.closeButton.Visible = false
	panel.title.Size = UDim2.new(1, 0, 0, Panel.HEADER_HEIGHT)
	-- Bigger than other screens: it is the whole first minute of the game.
	panel.frame.Size = UDim2.fromScale(0.94, 0.94)
	local limit = panel.frame:FindFirstChildOfClass("UISizeConstraint")
	if limit ~= nil then
		limit.MaxSize = Vector2.new(900, 620)
	end

	-- Current pick per slot: an index into Starters.options[slot]. Starts as a random mix.
	local picks: { [Types.Slot]: number } = {}
	for _, slot in Creatures.SLOTS do
		picks[slot] = math.random(1, #Starters.options[slot])
	end

	local function currentLoadout(): Types.Loadout
		local loadout: Types.Loadout = {}
		for _, slot in Creatures.SLOTS do
			(loadout :: any)[slot] = Starters.options[slot][picks[slot]]
		end
		return loadout
	end

	-- Left: one row per slot. Right: the preview. Bottom: what it can do, Shuffle and Create.
	local rowsArea = Instance.new("Frame")
	rowsArea.Name = "Rows"
	rowsArea.Size = UDim2.new(0.56, -gap / 2, 1, -(BOTTOM_HEIGHT + gap))
	rowsArea.BackgroundTransparency = 1
	rowsArea.Parent = panel.body
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, gap / 2)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = rowsArea

	local previewArea = Instance.new("Frame")
	previewArea.Name = "PreviewArea"
	previewArea.AnchorPoint = Vector2.new(1, 0)
	previewArea.Position = UDim2.fromScale(1, 0)
	previewArea.Size = UDim2.new(0.44, -gap / 2, 1, -(BOTTOM_HEIGHT + gap))
	previewArea.BackgroundColor3 = Theme.colors.card
	Theme.corner(previewArea)
	Theme.outline(previewArea, 3)
	previewArea.Parent = panel.body
	local creatureName = Instance.new("TextLabel")
	creatureName.Name = "CreatureName"
	creatureName.Position = UDim2.fromScale(0.05, 0.02)
	creatureName.Size = UDim2.fromScale(0.9, 0.15)
	Theme.text(creatureName, 30)
	creatureName.TextColor3 = Theme.colors.lime
	creatureName.Parent = previewArea
	local previewHolder = Instance.new("Frame")
	previewHolder.Name = "Preview"
	previewHolder.Position = UDim2.fromScale(0, 0.17)
	previewHolder.Size = UDim2.fromScale(1, 0.83)
	previewHolder.BackgroundTransparency = 1
	previewHolder.Parent = previewArea
	local preview = CreaturePreview.create(previewHolder)
	preview.frame.Size = UDim2.fromScale(1, 1)

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0, BOTTOM_HEIGHT)
	bottom.BackgroundTransparency = 1
	bottom.Parent = panel.body
	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.Size = UDim2.new(0.5, -gap, 1, 0)
	info.TextXAlignment = Enum.TextXAlignment.Left
	Theme.text(info, 22)
	info.TextWrapped = true
	info.Parent = bottom
	local shuffleButton = Theme.button("Shuffle", "Shuffle", 24)
	shuffleButton.Position = UDim2.fromScale(0.5, 0)
	shuffleButton.Size = UDim2.new(0.17, -gap, 1, 0)
	shuffleButton.Parent = bottom
	local createButton = Theme.button("Create", "Bring it to life!", 28)
	createButton.AnchorPoint = Vector2.new(1, 0)
	createButton.Position = UDim2.fromScale(1, 0)
	createButton.Size = UDim2.fromScale(0.33, 1)
	createButton.Parent = bottom

	local rows: { [Types.Slot]: Row } = {}

	-- The preview is the slow part (it builds a whole creature), so it waits until the taps
	-- stop and skips work when nothing changed.
	local previewToken = 0
	local previewedKey = ""
	local function schedulePreview(loadout: Types.Loadout): ()
		previewToken += 1
		local token = previewToken
		task.delay(PREVIEW_DELAY, function()
			local key = `{loadout.Head}/{loadout.Body}/{loadout.Legs}/{loadout.Back}`
			if token == previewToken and key ~= previewedKey then
				previewedKey = key
				preview.show(loadout)
			end
		end)
	end

	local function refresh(): ()
		local loadout = currentLoadout()
		for _, slot in Creatures.SLOTS do
			local row = rows[slot]
			local partId = Starters.options[slot][picks[slot]]
			local definition = Parts.get(partId) :: Types.PartDefinition
			row.name.Text = definition.displayName
			if row.icons[partId] == nil then
				local icon = PartIcon.create(partId)
				if icon ~= nil then
					icon.Size = UDim2.fromScale(1, 1)
					icon.Parent = row.iconHolder
					row.icons[partId] = icon
				end
			end
			for id, icon in row.icons do
				icon.Visible = id == partId
			end
		end
		schedulePreview(loadout)

		local summary = Creatures.summarize(loadout)
		creatureName.Text = summary.name
		local can: { string } = {}
		local opens: { string } = {}
		for _, island in Islands.list do
			local ability = island.requires
			if ability ~= nil and summary.abilities[ability] then
				table.insert(can, Islands.abilityName(ability))
				table.insert(opens, island.displayName)
			end
		end
		-- A monster with no travel ability couldn't leave town, so it can't be the first one.
		local ready = #can > 0
		info.Text = if ready
			then `Can: {table.concat(can, " + ")}\nGoes to: {table.concat(opens, ", ")}`
			else "Can't travel yet! Pick Ember Wings, a Tide Tail or Thunder Legs."
		info.TextColor3 = if ready then Theme.colors.text else Theme.colors.gold
		createButton.BackgroundColor3 = if ready then Theme.colors.limeDark else Theme.colors.card
		createButton.AutoButtonColor = false
		createButton.Active = ready
	end

	local function step(slot: Types.Slot, direction: number): ()
		if busy then
			return
		end
		local count = #Starters.options[slot]
		picks[slot] = (picks[slot] - 1 + direction) % count + 1
		refresh()
	end

	for index, slot in Creatures.SLOTS do
		local row = Instance.new("Frame")
		row.Name = slot
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0.25, -gap * 3 / 8)
		row.BackgroundTransparency = 1
		row.Parent = rowsArea

		local label = Instance.new("TextLabel")
		label.Name = "Slot"
		label.Size = UDim2.fromScale(0.22, 1)
		label.Text = SLOT_NAMES[slot]
		label.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(label, 22)
		label.Parent = row

		local left = Theme.button("Previous", "<", 30)
		left.Position = UDim2.fromScale(0.22, 0)
		left.Size = UDim2.new(0, ARROW_WIDTH, 1, 0)
		left.Parent = row
		local right = Theme.button("Next", ">", 30)
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.fromScale(1, 0)
		right.Size = UDim2.new(0, ARROW_WIDTH, 1, 0)
		right.Parent = row

		-- Tapping the part itself also flips to the next one.
		local card = Instance.new("TextButton")
		card.Name = "Card"
		card.Text = ""
		card.AutoButtonColor = false
		card.Position = UDim2.new(0.22, ARROW_WIDTH + gap / 2, 0, 0)
		card.Size = UDim2.new(0.78, -(2 * ARROW_WIDTH + gap), 1, 0)
		card.BackgroundColor3 = Theme.colors.card
		Theme.corner(card)
		Theme.outline(card, 3)
		Theme.pressable(card)
		card.Parent = row
		local iconHolder = Instance.new("Frame")
		iconHolder.Name = "Icon"
		iconHolder.Size = UDim2.fromScale(1, 1)
		iconHolder.SizeConstraint = Enum.SizeConstraint.RelativeYY
		iconHolder.BackgroundColor3 = Theme.colors.purpleDeep
		Theme.corner(iconHolder)
		iconHolder.Parent = card
		local name = Instance.new("TextLabel")
		name.Name = "PartName"
		name.AnchorPoint = Vector2.new(1, 0)
		name.Position = UDim2.fromScale(0.97, 0)
		name.Size = UDim2.fromScale(0.6, 1)
		Theme.text(name, 24)
		name.Parent = card

		left.Activated:Connect(function()
			step(slot, -1)
		end)
		right.Activated:Connect(function()
			step(slot, 1)
		end)
		card.Activated:Connect(function()
			step(slot, 1)
		end)
		rows[slot] = { card = card, iconHolder = iconHolder, name = name, icons = {} }
	end

	shuffleButton.Activated:Connect(function()
		if busy then
			return
		end
		for _, slot in Creatures.SLOTS do
			picks[slot] = math.random(1, #Starters.options[slot])
		end
		refresh()
	end)

	-- "It's alive!": a white flash and a big word, then the panel closes and the monster is out.
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 20
	flash.Visible = false
	flash.Parent = panel.frame
	local alive = Instance.new("TextLabel")
	alive.Name = "Alive"
	alive.AnchorPoint = Vector2.new(0.5, 0.5)
	alive.Position = UDim2.fromScale(0.5, 0.5)
	alive.Size = UDim2.fromScale(0.9, 0.3)
	alive.Text = "IT'S ALIVE!"
	Theme.text(alive, 90)
	alive.TextColor3 = Theme.colors.lime
	alive.ZIndex = 21
	alive.Visible = false
	local aliveScale = Instance.new("UIScale")
	aliveScale.Parent = alive
	alive.Parent = panel.frame

	local function celebrate(): ()
		flash.Visible = true
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		alive.Visible = true
		aliveScale.Scale = 0.2
		TweenService
			:Create(
				aliveScale,
				TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{
					Scale = 1,
				}
			)
			:Play()
		task.wait(1.3)
		flash.Visible = false
		alive.Visible = false
	end

	createButton.Activated:Connect(function()
		if busy or not createButton.Active then
			return
		end
		busy = true
		createButton.Text = "..."
		local ok, message = Remotes.func("CreateStarter"):InvokeServer(currentLoadout())
		createButton.Text = "Bring it to life!"
		if ok == true then
			celebrate()
			panel.close()
			for _, listener in createdListeners do
				task.spawn(listener)
			end
		elseif type(message) == "string" then
			info.Text = message
		end
		busy = false
	end)

	-- Built on open, not at startup: the preview waits for the part models to arrive.
	panel.onOpened(function()
		preview.setSpinning(true)
		task.spawn(refresh)
	end)
	panel.onClosed(function()
		preview.setSpinning(false)
	end)

	return {
		panel = panel,
		onCreated = function(listener)
			table.insert(createdListeners, listener)
		end,
	}
end

return StarterScreen
