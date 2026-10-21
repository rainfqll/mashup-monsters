--!strict
-- The standard pop-up panel every screen uses: dark slate box with a thin gold edge, a serif
-- title, a big close button, a quick fade-in, and controller focus kept inside while it is open. Screens put their
-- content in `body` (the area under the header).

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Panel = {}

Panel.HEADER_HEIGHT = 56
Panel.GAP = 10

local OPEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Panel = {
	frame: Frame,
	body: Frame,
	title: TextLabel,
	closeButton: TextButton,
	-- `focus` gets controller selection when the player is using a gamepad.
	open: (focus: GuiObject?) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onOpened: (listener: () -> ()) -> (),
	onClosed: (listener: () -> ()) -> (),
}

export type TabRow = {
	buttons: { [string]: TextButton },
	select: (name: string) -> (),
}

local function usingGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
end

function Panel.create(parent: ScreenGui, name: string, titleText: string): Panel
	local gap = Panel.GAP
	local headerHeight = Panel.HEADER_HEIGHT
	local isOpen = false
	local openedListeners: { () -> () } = {}
	local closedListeners: { () -> () } = {}

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.8, 0.86)
	frame.BackgroundColor3 = Theme.colors.purpleDeep
	frame.BackgroundTransparency = 0.04
	frame.Visible = false
	-- Keeps controller focus inside the panel while it is open.
	frame.SelectionGroup = true
	Theme.corner(frame, UDim.new(0, 10))
	Theme.outline(frame, 4, Theme.colors.gold)
	Theme.shade(frame)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(760, 560)
	sizeLimit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, gap)
	padding.PaddingBottom = UDim.new(0, gap)
	padding.PaddingLeft = UDim.new(0, gap)
	padding.PaddingRight = UDim.new(0, gap)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.45, 0, 0, headerHeight)
	title.Text = titleText
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.title(title, 34)
	title.Parent = frame

	local closeButton = Theme.button("Close", "X", 32)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(headerHeight, headerHeight)
	closeButton.BackgroundColor3 = Theme.colors.danger
	closeButton.Parent = frame

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, headerHeight + gap)
	body.Size = UDim2.new(1, 0, 1, -(headerHeight + gap))
	body.BackgroundTransparency = 1
	body.Parent = frame

	local function open(focus: GuiObject?): ()
		if isOpen then
			return
		end
		isOpen = true
		frame.Visible = true
		scale.Scale = 0.96
		TweenService:Create(scale, OPEN_INFO, { Scale = 1 }):Play()
		for _, listener in openedListeners do
			listener()
		end
		-- Only move controller focus if the player is already using one.
		if usingGamepad() then
			GuiService.SelectedObject = focus or closeButton
		end
	end

	local function close(): ()
		if not isOpen then
			return
		end
		isOpen = false
		frame.Visible = false
		if GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(frame) then
			GuiService.SelectedObject = nil
		end
		for _, listener in closedListeners do
			listener()
		end
	end

	closeButton.Activated:Connect(close)
	frame.Parent = parent

	return {
		frame = frame,
		body = body,
		title = title,
		closeButton = closeButton,
		open = open,
		close = close,
		isOpen = function()
			return isOpen
		end,
		onOpened = function(listener)
			table.insert(openedListeners, listener)
		end,
		onClosed = function(listener)
			table.insert(closedListeners, listener)
		end,
	}
end

-- A row of equal-width tab buttons. The selected one turns green; `select` only recolors,
-- so screens connect each button's Activated themselves.
function Panel.tabRow(parent: GuiObject, names: { string }, height: number, maxText: number): TabRow
	local gap = Panel.GAP
	local row = Instance.new("Frame")
	row.Name = "Tabs"
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local buttons: { [string]: TextButton } = {}
	local gapShare = gap * (#names - 1) / #names
	for index, name in names do
		local tab = Theme.button(name, name, maxText)
		tab.LayoutOrder = index
		tab.Size = UDim2.new(1 / #names, -gapShare, 1, 0)
		tab.Parent = row
		buttons[name] = tab
	end

	return {
		buttons = buttons,
		select = function(selected: string)
			for name, tab in buttons do
				tab.BackgroundColor3 = if name == selected
					then Theme.colors.limeDark
					else Theme.colors.purple
			end
		end,
	}
end

return Panel
