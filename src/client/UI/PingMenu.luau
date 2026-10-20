--!strict
-- The row that pops out next to the Ping button: three pings (Here!, Help!, Look!) and three
-- emotes. Picking one closes the row, so it is always one tap to open and one tap to act.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local Theme = require(script.Parent.Theme)

local BUTTON_SIZE = 58
local GAP = 8

export type PingMenu = {
	toggle: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local PingMenu = {}

function PingMenu.create(
	anchor: GuiObject,
	onPing: (kind: Social.PingKind) -> (),
	onEmote: (emoteId: string) -> ()
): PingMenu
	local count = #Social.pingOrder + #Social.emotes
	local row = Instance.new("Frame")
	row.Name = "PingMenu"
	row.AnchorPoint = Vector2.new(0, 0.5)
	row.Position = UDim2.new(1, GAP + 4, 0.5, 0)
	row.Size = UDim2.fromOffset(count * (BUTTON_SIZE + GAP), BUTTON_SIZE)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.ZIndex = 5
	row.Parent = anchor
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local function close(): ()
		row.Visible = false
	end

	local function add(order: number, label: string, color: Color3, action: () -> ()): ()
		local button = Theme.button(label, label, 20)
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
		button.BackgroundColor3 = color
		button.ZIndex = 5
		button.Parent = row
		button.Activated:Connect(function()
			close()
			action()
		end)
	end

	for index, kind in Social.pingOrder do
		local info = Social.pings[kind]
		add(index, info.label, info.color, function()
			onPing(kind)
		end)
	end
	for index, emote in Social.emotes do
		add(#Social.pingOrder + index, emote.label, Theme.colors.purple, function()
			onEmote(emote.id)
		end)
	end

	return {
		toggle = function()
			row.Visible = not row.Visible
		end,
		close = close,
		isOpen = function()
			return row.Visible
		end,
	}
end

return PingMenu
