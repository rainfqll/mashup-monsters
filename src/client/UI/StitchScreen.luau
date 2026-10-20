--!strict
-- Stitch Station screen. Two tabs:
--   Stitch:      four slot buttons, a spinning preview, and the big lever.
--   My Monsters: your saved creatures, with "take out" / "put away" and "unstitch".
-- The screen only shows the server's snapshot and sends requests; the server re-checks
-- ownership and distance, so nothing here can create parts or creatures by itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CreaturePreview = require(script.Parent.CreaturePreview)
local Panel = require(script.Parent.Panel)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

type Tab = "Stitch" | "My Monsters"

local LEVER_HEIGHT = 56
local PICKER_HEADER = 44
-- A second tap within this many seconds confirms "Unstitch".
local CONFIRM_SECONDS = 3

local ABILITY_LABELS: { [string]: string } = {
	Swim = "Swim",
	SuperJump = "Super Jump",
	Speed = "Speed",
	Glide = "Glide",
	Light = "Light",
	Dig = "Dig",
	Reveal = "Reveal",
	Climb = "Climb",
	Carry = "Carry",
	Shield = "Shield",
	Glow = "Glow",
}

export type StitchScreen = {
	panel: Panel.Panel,
	render: (snapshot: Types.PlayerSnapshot) -> (),
	-- Tutorial: fill the slots with these parts (only the ones you own) before opening.
	preselect: (loadout: Types.Loadout) -> (),
	-- Tutorial: make the lever throb while it is ready to pull.
	setLeverHint: (on: boolean) -> (),
}

local function abilityText(summary: Types.CreatureSummary): string
	local names = {}
	for ability in summary.abilities do
		table.insert(names, ABILITY_LABELS[ability] or ability)
	end
	table.sort(names)
	return if #names > 0 then table.concat(names, " + ") else "No special moves"
end

local StitchScreen = {}

function StitchScreen.create(parent: ScreenGui, showMessage: (string, Color3?) -> ()): StitchScreen
	local gap = Panel.GAP
	local tab: Tab = "Stitch"
	local selection: Types.Loadout = {}
	local pickingSlot: Types.Slot? = nil
	local stitching = false
	local lastSnapshot: Types.PlayerSnapshot? = nil
	local confirmIndex: number? = nil
	local confirmToken = 0
	local leverHint = false
	local stopLeverPulse: (() -> ())? = nil

	local panel = Panel.create(parent, "Stitch", "Stitch Station")
	-- More room than other panels: the preview needs it on short phones.
	panel.frame.Size = UDim2.fromScale(0.92, 0.94)
	panel.title.Visible = false

	-- Tabs live in the header to save height on phones.
	local tabs = Panel.tabRow(panel.frame, { "Stitch", "My Monsters" }, Panel.HEADER_HEIGHT, 26)
	local tabRow = tabs.buttons.Stitch.Parent :: Frame
	tabRow.Size = UDim2.new(1, -(Panel.HEADER_HEIGHT + gap), 0, Panel.HEADER_HEIGHT)

	----------------------------------------------------------------- Stitch tab
	local stitchTab = Instance.new("Frame")
	stitchTab.Name = "StitchTab"
	stitchTab.Size = UDim2.fromScale(1, 1)
	stitchTab.BackgroundTransparency = 1
	stitchTab.Parent = panel.body

	local slotColumn = Instance.new("Frame")
	slotColumn.Name = "Slots"
	slotColumn.Size = UDim2.new(0.42, -gap / 2, 1, 0)
	slotColumn.BackgroundTransparency = 1
	slotColumn.Parent = stitchTab
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.Padding = UDim.new(0, gap)
	slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotLayout.Parent = slotColumn

	type SlotButton = { button: TextButton, swatch: Frame, label: TextLabel }
	local slotButtons: { [Types.Slot]: SlotButton } = {}
	local slotShare = gap * 3 / 4
	for index, slot in Creatures.SLOTS do
		local button = Theme.button(slot, "", 24)
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0.25, -slotShare)

		-- Square color block on the left, sized from the button's height.
		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.AnchorPoint = Vector2.new(0, 0.5)
		swatch.Position = UDim2.new(0, 8, 0.5, 0)
		swatch.Size = UDim2.fromScale(0.7, 0.7)
		swatch.SizeConstraint = Enum.SizeConstraint.RelativeYY
		Theme.corner(swatch, UDim.new(0.25, 0))
		Theme.outline(swatch, 2)
		swatch.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AnchorPoint = Vector2.new(1, 0.5)
		label.Position = UDim2.new(1, -8, 0.5, 0)
		label.Size = UDim2.fromScale(0.72, 0.8)
		label.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(label, 24)
		label.Parent = button

		button.Parent = slotColumn
		slotButtons[slot] = { button = button, swatch = swatch, label = label }
	end

	local previewColumn = Instance.new("Frame")
	previewColumn.Name = "PreviewColumn"
	previewColumn.AnchorPoint = Vector2.new(1, 0)
	previewColumn.Position = UDim2.fromScale(1, 0)
	previewColumn.Size = UDim2.new(0.58, -gap / 2, 1, 0)
	previewColumn.BackgroundColor3 = Theme.colors.card
	Theme.corner(previewColumn)
	Theme.outline(previewColumn, 3)
	previewColumn.Parent = stitchTab

	local preview = CreaturePreview.create(previewColumn)
	preview.frame.Size = UDim2.new(1, 0, 1, -(LEVER_HEIGHT + gap))

	local creatureName = Instance.new("TextLabel")
	creatureName.Name = "CreatureName"
	creatureName.Position = UDim2.fromOffset(8, 4)
	creatureName.Size = UDim2.new(1, -16, 0.16, 0)
	Theme.text(creatureName, 30)
	creatureName.Parent = previewColumn

	local abilitiesLabel = Instance.new("TextLabel")
	abilitiesLabel.Name = "Abilities"
	abilitiesLabel.AnchorPoint = Vector2.new(0, 1)
	abilitiesLabel.Position = UDim2.new(0, 8, 1, -(LEVER_HEIGHT + gap + 4))
	abilitiesLabel.Size = UDim2.new(1, -16, 0.13, 0)
	Theme.text(abilitiesLabel, 22)
	abilitiesLabel.TextColor3 = Theme.colors.lime
	abilitiesLabel.Parent = previewColumn

	local lever = Theme.button("Lever", "STITCH!", 34)
	lever.AnchorPoint = Vector2.new(0.5, 1)
	lever.Position = UDim2.new(0.5, 0, 1, -6)
	lever.Size = UDim2.new(1, -12, 0, LEVER_HEIGHT - 6)
	lever.BackgroundColor3 = Theme.colors.lime
	lever.Parent = previewColumn

	----------------------------------------------------------------- Part picker
	-- Covers the whole stitch tab while choosing, so cards are big enough to tap on a phone.
	local picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.Size = UDim2.fromScale(1, 1)
	picker.BackgroundColor3 = Theme.colors.purpleDeep
	picker.Visible = false
	picker.ZIndex = 5
	picker.Parent = stitchTab

	local pickerBack = Theme.button("Back", "< Back", 24)
	pickerBack.Size = UDim2.new(0.25, 0, 0, PICKER_HEADER)
	pickerBack.Parent = picker

	local pickerNone = Theme.button("None", "Empty slot", 24)
	pickerNone.AnchorPoint = Vector2.new(1, 0)
	pickerNone.Position = UDim2.fromScale(1, 0)
	pickerNone.Size = UDim2.new(0.3, 0, 0, PICKER_HEADER)
	pickerNone.Parent = picker

	local pickerTitle = Instance.new("TextLabel")
	pickerTitle.Name = "PickerTitle"
	pickerTitle.Position = UDim2.fromScale(0.27, 0)
	pickerTitle.Size = UDim2.new(0.4, 0, 0, PICKER_HEADER)
	Theme.text(pickerTitle, 28)
	pickerTitle.Parent = picker

	local pickerGrid = PartCard.grid(picker, 110)
	pickerGrid.Position = UDim2.fromOffset(0, PICKER_HEADER + gap)
	pickerGrid.Size = UDim2.new(1, 0, 1, -(PICKER_HEADER + gap))

	local pickerEmpty = Instance.new("TextLabel")
	pickerEmpty.Name = "PickerEmpty"
	pickerEmpty.AnchorPoint = Vector2.new(0.5, 0.5)
	pickerEmpty.Position = UDim2.fromScale(0.5, 0.55)
	pickerEmpty.Size = UDim2.fromScale(0.8, 0.2)
	Theme.text(pickerEmpty, 26)
	pickerEmpty.TextColor3 = Theme.colors.textDim
	pickerEmpty.Parent = picker

	----------------------------------------------------------------- My Monsters tab
	local monstersTab = Instance.new("Frame")
	monstersTab.Name = "MonstersTab"
	monstersTab.Size = UDim2.fromScale(1, 1)
	monstersTab.BackgroundTransparency = 1
	monstersTab.Visible = false
	monstersTab.Parent = panel.body
	local monstersLayout = Instance.new("UIListLayout")
	monstersLayout.FillDirection = Enum.FillDirection.Horizontal
	monstersLayout.Padding = UDim.new(0, gap)
	monstersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	monstersLayout.Parent = monstersTab

	type MonsterCard = {
		frame: Frame,
		preview: CreaturePreview.Preview,
		name: TextLabel,
		outButton: TextButton,
		unstitchButton: TextButton,
	}
	local monsterCards: { MonsterCard } = {}
	local cardShare = gap * (Creatures.MAX_SAVED - 1) / Creatures.MAX_SAVED
	for index = 1, Creatures.MAX_SAVED do
		local frame = Instance.new("Frame")
		frame.Name = `Monster{index}`
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1 / Creatures.MAX_SAVED, -cardShare, 1, 0)
		frame.BackgroundColor3 = Theme.colors.card
		Theme.corner(frame)
		Theme.outline(frame, 3)
		frame.Parent = monstersTab

		local cardPreview = CreaturePreview.create(frame)
		-- Buttons share one row so the preview keeps most of the height on short phones.
		cardPreview.frame.Size = UDim2.new(1, 0, 1, -(LEVER_HEIGHT + 4))

		local name = Instance.new("TextLabel")
		name.Name = "MonsterName"
		name.Position = UDim2.fromOffset(6, 4)
		name.Size = UDim2.new(1, -12, 0.14, 0)
		Theme.text(name, 24)
		name.Parent = frame

		local outButton = Theme.button("Out", "Take out", 22)
		outButton.AnchorPoint = Vector2.new(0, 1)
		outButton.Position = UDim2.new(0, 6, 1, -6)
		outButton.Size = UDim2.new(0.5, -9, 0, LEVER_HEIGHT - 8)
		outButton.Parent = frame

		local unstitchButton = Theme.button("Unstitch", "Unstitch", 22)
		unstitchButton.AnchorPoint = Vector2.new(1, 1)
		unstitchButton.Position = UDim2.new(1, -6, 1, -6)
		unstitchButton.Size = UDim2.new(0.5, -9, 0, LEVER_HEIGHT - 8)
		unstitchButton.BackgroundColor3 = Color3.fromRGB(150, 60, 110)
		unstitchButton.Parent = frame

		monsterCards[index] = {
			frame = frame,
			preview = cardPreview,
			name = name,
			outButton = outButton,
			unstitchButton = unstitchButton,
		}
	end

	----------------------------------------------------------------- Rendering
	local function ownedCount(partId: string): number
		local snapshot = lastSnapshot
		return if snapshot ~= nil then snapshot.inventory[partId] or 0 else 0
	end

	local function isEmpty(loadout: Types.Loadout): boolean
		return #Creatures.partIds(loadout) == 0
	end

	-- Parts can leave the bag (stitched elsewhere, or the save reloaded); forget those choices.
	local function dropUnownedChoices(): ()
		for _, slot in Creatures.SLOTS do
			local id = (selection :: any)[slot] :: string?
			if id ~= nil and ownedCount(id) < 1 then
				(selection :: any)[slot] = nil
			end
		end
	end

	local function renderStitchTab(): ()
		local snapshot = lastSnapshot
		for _, slot in Creatures.SLOTS do
			local entry = slotButtons[slot]
			local id = (selection :: any)[slot] :: string?
			local definition = if id ~= nil then Parts.get(id) else nil
			if definition ~= nil then
				entry.label.Text = definition.displayName
				entry.swatch.BackgroundColor3 = definition.colorTheme
				entry.swatch.BackgroundTransparency = 0
				local stroke = entry.button:FindFirstChild("Border") :: UIStroke?
				if stroke ~= nil then
					stroke.Color = Rarities[definition.rarity].color
				end
			else
				local blob = slot == "Body"
				entry.label.Text = if blob then "Stitchy Blob" else `{slot}: empty`
				entry.swatch.BackgroundColor3 = if blob
					then (Parts.get(Creatures.DEFAULT_BODY) :: Types.PartDefinition).colorTheme
					else Theme.colors.purpleDeep
				local stroke = entry.button:FindFirstChild("Border") :: UIStroke?
				if stroke ~= nil then
					stroke.Color = Theme.colors.outline
				end
			end
		end

		if isEmpty(selection) then
			preview.show(nil)
			creatureName.Text = "Tap a slot!"
			abilitiesLabel.Text = "Pick parts to build a monster"
		else
			preview.show(selection)
			local summary = Creatures.summarize(selection)
			creatureName.Text = summary.name
			abilitiesLabel.Text = abilityText(summary)
		end

		local full = snapshot ~= nil and #snapshot.creatures >= Creatures.MAX_SAVED
		local ready = not isEmpty(selection) and not full and not stitching
		lever.Text = if stitching then "..." elseif full then "Lab full" else "STITCH!"
		lever.BackgroundColor3 = if ready then Theme.colors.lime else Color3.fromRGB(110, 100, 130)
		lever.Active = ready

		local shouldPulse = leverHint and ready
		if shouldPulse and stopLeverPulse == nil then
			stopLeverPulse = Theme.pulse(lever)
		elseif not shouldPulse and stopLeverPulse ~= nil then
			stopLeverPulse()
			stopLeverPulse = nil
		end
	end

	local function renderPicker(): ()
		local slot = pickingSlot
		picker.Visible = slot ~= nil
		if slot == nil then
			return
		end
		pickerTitle.Text = `Pick a {slot}`
		PartCard.clear(pickerGrid)
		local count = 0
		for _, definition in Parts.list do
			local owned = ownedCount(definition.id)
			if definition.slot == slot and not definition.free and owned > 0 then
				count += 1
				local card =
					PartCard.create(definition, { count = owned, clickable = true }) :: TextButton
				card.LayoutOrder = -Rarities[definition.rarity].order
				card.Activated:Connect(function()
					(selection :: any)[slot] = definition.id
					pickingSlot = nil
					renderPicker()
					renderStitchTab()
				end)
				card.Parent = pickerGrid
			end
		end
		pickerEmpty.Visible = count == 0
		pickerEmpty.Text = `No {slot} parts in your bag. Go explore!`
		pickerNone.Text = if slot == "Body" then "Stitchy Blob" else "Empty slot"
	end

	local function renderMonstersTab(): ()
		local snapshot = lastSnapshot
		for index, card in monsterCards do
			local loadout = if snapshot ~= nil then snapshot.creatures[index] else nil
			local isOut = snapshot ~= nil and snapshot.activeCreature == index
			card.outButton.Visible = loadout ~= nil
			card.unstitchButton.Visible = loadout ~= nil
			card.preview.show(loadout)
			if loadout ~= nil then
				card.name.Text = Creatures.summarize(loadout).name
				card.outButton.Text = if isOut then "Put away" else "Take out"
				card.outButton.BackgroundColor3 = if isOut
					then Theme.colors.purple
					else Theme.colors.limeDark
				card.unstitchButton.Text = if confirmIndex == index then "Sure?" else "Unstitch"
			else
				card.name.Text = "Empty"
			end
			local stroke = card.frame:FindFirstChild("Border") :: UIStroke?
			if stroke ~= nil then
				stroke.Color = if isOut then Theme.colors.lime else Theme.colors.outline
			end
		end
	end

	local function setSpinning(): ()
		local open = panel.isOpen()
		preview.setSpinning(open and tab == "Stitch")
		for _, card in monsterCards do
			card.preview.setSpinning(open and tab == "My Monsters")
		end
	end

	local function renderAll(): ()
		tabs.select(tab)
		stitchTab.Visible = tab == "Stitch"
		monstersTab.Visible = tab == "My Monsters"
		dropUnownedChoices()
		renderStitchTab()
		renderPicker()
		renderMonstersTab()
		setSpinning()
	end

	----------------------------------------------------------------- Input
	for name, button in tabs.buttons do
		button.Activated:Connect(function()
			tab = name :: Tab
			pickingSlot = nil
			renderAll()
		end)
	end

	for slot, entry in slotButtons do
		entry.button.Activated:Connect(function()
			pickingSlot = slot
			pickerGrid.CanvasPosition = Vector2.zero
			renderPicker()
		end)
	end

	pickerBack.Activated:Connect(function()
		pickingSlot = nil
		renderPicker()
	end)

	pickerNone.Activated:Connect(function()
		local slot = pickingSlot
		if slot ~= nil then
			(selection :: any)[slot] = nil
		end
		pickingSlot = nil
		renderPicker()
		renderStitchTab()
	end)

	lever.Activated:Connect(function()
		if not lever.Active then
			return
		end
		stitching = true
		renderStitchTab()
		local request = table.clone(selection)
		task.spawn(function()
			local ok, result, message = pcall(function()
				return Remotes.func("Stitch"):InvokeServer(request)
			end)
			stitching = false
			if ok and result == true then
				local name = Creatures.summarize(request).name
				selection = {}
				panel.close()
				showMessage(`{name} is alive!`, Theme.colors.lime)
			else
				local reason = if ok and type(message) == "string"
					then message
					else "Something went wrong. Try again!"
				showMessage(reason, Color3.fromRGB(230, 80, 110))
				renderStitchTab()
			end
		end)
	end)

	for index, card in monsterCards do
		card.outButton.Activated:Connect(function()
			local snapshot = lastSnapshot
			if snapshot == nil or snapshot.creatures[index] == nil then
				return
			end
			local target = if snapshot.activeCreature == index then 0 else index
			Remotes.event("SetActiveCreature"):FireServer(target)
		end)
		card.unstitchButton.Activated:Connect(function()
			-- Two taps, so a quick mis-tap doesn't take a creature apart.
			if confirmIndex ~= index then
				confirmIndex = index
				confirmToken += 1
				local token = confirmToken
				renderMonstersTab()
				task.delay(CONFIRM_SECONDS, function()
					if confirmToken == token then
						confirmIndex = nil
						renderMonstersTab()
					end
				end)
				return
			end
			confirmIndex = nil
			Remotes.event("Unstitch"):FireServer(index)
		end)
	end

	panel.onOpened(function()
		tab = "Stitch"
		pickingSlot = nil
		renderAll()
	end)
	panel.onClosed(function()
		pickingSlot = nil
		confirmIndex = nil
		setSpinning()
	end)

	return {
		panel = panel,
		render = function(snapshot: Types.PlayerSnapshot)
			lastSnapshot = snapshot
			if panel.isOpen() then
				renderAll()
			end
		end,
		preselect = function(loadout: Types.Loadout)
			for _, slot in Creatures.SLOTS do
				local id = (loadout :: any)[slot] :: string?
				if id ~= nil and ownedCount(id) > 0 then
					(selection :: any)[slot] = id
				end
			end
			if panel.isOpen() then
				renderAll()
			end
		end,
		setLeverHint = function(on: boolean)
			leverHint = on
			renderStitchTab()
		end,
	}
end

return StitchScreen
