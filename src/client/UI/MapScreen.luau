--!strict
-- The big map. Opened from the mini map it just shows the world and where you are. Opened at a
-- portal (with the Portal Pass) it is the travel menu: every portal you can use glows green,
-- the one you stand at says "You are here", and places you haven't reached yet say which
-- ability gets you there. The server checks every trip (PortalService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldMap = require(ReplicatedStorage.Shared.Config.WorldMap)
local MapView = require(script.Parent.MapView)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)

local HINT_HEIGHT = 34
local GO_COLOR = Theme.colors.lime
local HERE_COLOR = Theme.colors.purple
local LOCKED_COLOR = Color3.fromRGB(110, 105, 125)

export type MapScreen = {
	panel: Panel.Panel,
	openView: () -> (),
	openTravel: (fromIsland: string, snapshot: Types.PlayerSnapshot?) -> (),
}

local MapScreen = {}

function MapScreen.create(parent: ScreenGui, onTravel: (destination: string) -> ()): MapScreen
	local player = Players.LocalPlayer
	local gap = Panel.GAP
	local travelFrom: string? = nil
	-- Portals you may travel to right now (travel mode only).
	local canGo: { [string]: boolean } = {}

	local panel = Panel.create(parent, "Map", "Map")
	-- Bigger than other screens: the map is worth the room.
	panel.frame.Size = UDim2.fromScale(0.94, 0.94)
	local limit = panel.frame:FindFirstChildOfClass("UISizeConstraint")
	if limit ~= nil then
		limit.MaxSize = Vector2.new(900, 760)
	end
	local mapArea = Instance.new("Frame")
	mapArea.Name = "MapArea"
	mapArea.AnchorPoint = Vector2.new(0.5, 0)
	mapArea.Position = UDim2.fromScale(0.5, 0)
	mapArea.Size = UDim2.new(1, 0, 1, -(HINT_HEIGHT + gap))
	mapArea.SizeConstraint = Enum.SizeConstraint.RelativeYY
	mapArea.BackgroundTransparency = 1
	mapArea.Parent = panel.body
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = mapArea
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Clip"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	Theme.corner(clip, UDim.new(0, 14))
	clip.Parent = mapArea
	local border = Instance.new("Frame")
	border.Name = "Border"
	border.Size = UDim2.fromScale(1, 1)
	border.BackgroundTransparency = 1
	Theme.corner(border, UDim.new(0, 14))
	Theme.outline(border, 4)
	border.Parent = mapArea

	local view = MapView.create(clip, 0.05)
	local arrow = MapView.arrow(view.canvas, 20)
	arrow.Size = UDim2.fromScale(0.045, 0.045)
	arrow.SizeConstraint = Enum.SizeConstraint.RelativeXX

	-- A caption under each portal ("Go!", "You are here", "Needs Swim").
	local captions: { [string]: TextLabel } = {}
	local above: { [string]: boolean } = {}
	for _, portal in WorldMap.portals do
		above[portal.island] = portal.captionAbove == true
	end
	for island, button in view.portals do
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption_" .. island
		caption.AnchorPoint = Vector2.new(0.5, if above[island] then 1 else 0)
		caption.Position = button.Position
			+ UDim2.fromScale(0, if above[island] then -0.035 else 0.035)
		caption.Size = UDim2.fromScale(0.34, 0.05)
		Theme.text(caption, 18)
		caption.ZIndex = 8
		caption.Visible = false
		caption.Parent = view.canvas
		captions[island] = caption
		button.Activated:Connect(function()
			if travelFrom ~= nil and canGo[island] then
				onTravel(island)
				panel.close()
			end
		end)
	end

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.fromScale(0, 1)
	hint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
	Theme.text(hint, 22)
	hint.Parent = panel.body

	local function showPortals(snapshot: Types.PlayerSnapshot?): ()
		table.clear(canGo)
		for island, button in view.portals do
			local caption = captions[island]
			local info = Islands.get(island)
			local unlocked = island == Islands.HOME
				or (snapshot ~= nil and snapshot.unlockedIslands[island] == true)
			local name = if info ~= nil then info.displayName else island
			if travelFrom == nil then
				button.BackgroundColor3 = HERE_COLOR
				caption.Visible = false
			elseif island == travelFrom then
				button.BackgroundColor3 = HERE_COLOR
				caption.Text = "You are here"
				caption.Visible = true
			elseif unlocked then
				canGo[island] = true
				button.BackgroundColor3 = GO_COLOR
				caption.Text = `Go to {name}!`
				caption.Visible = true
			else
				button.BackgroundColor3 = LOCKED_COLOR
				local needs = if info ~= nil and info.requires ~= nil
					then Islands.abilityName(info.requires)
					else "?"
				caption.Text = `{name}: needs {needs}`
				caption.Visible = true
			end
		end
	end

	local arrowConnection: RBXScriptConnection? = nil
	panel.onOpened(function()
		arrowConnection = RunService.RenderStepped:Connect(function()
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if root == nil or not root:IsA("BasePart") then
				return
			end
			local point = view.toMap(root.Position.X, root.Position.Z)
			arrow.Position = UDim2.fromScale(point.X, point.Y)
			local look = root.CFrame.LookVector
			arrow.Rotation = math.deg(math.atan2(look.X, look.Z))
		end)
	end)
	panel.onClosed(function()
		travelFrom = nil
		if arrowConnection ~= nil then
			arrowConnection:Disconnect()
			arrowConnection = nil
		end
	end)

	return {
		panel = panel,
		openView = function()
			travelFrom = nil
			for _, label in view.labels do
				label.Visible = true
			end
			panel.title.Text = "Map"
			hint.Text = "Explore on foot! Portals take Portal Pass owners to places they've found."
			showPortals(nil)
			panel.open()
		end,
		openTravel = function(fromIsland: string, snapshot: Types.PlayerSnapshot?)
			travelFrom = fromIsland
			-- The portal captions name each place, so the region names would only overlap them.
			for _, label in view.labels do
				label.Visible = false
			end
			panel.title.Text = "Where to?"
			hint.Text = "Tap a green portal to travel there."
			showPortals(snapshot)
			panel.open()
		end,
	}
end

return MapScreen
