--!strict
-- Draws the One World map (Config/WorldMap) into a frame: ocean, the island, the regions, the
-- river and the chasm, Stitch Square, the portals, and region names. Everything is placed in
-- "map scale": 0..1 across the square the map covers, so the same drawing works for the corner
-- mini map (zoomed in and moved under you) and the big map (whole world).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local WorldMap = require(ReplicatedStorage.Shared.Config.WorldMap)
local Theme = require(script.Parent.Theme)

-- An old explorer's map: muted sea, parchment land, soft region colors.
local OCEAN = Color3.fromRGB(64, 98, 122)
local SAND = Color3.fromRGB(214, 196, 150)
local RIVER = Color3.fromRGB(92, 140, 168)
local CHASM = Color3.fromRGB(38, 34, 34)
local SQUARE = Color3.fromRGB(170, 162, 150)
local PORTAL = Color3.fromRGB(120, 86, 190)

export type MapView = {
	canvas: Frame,
	-- (x, z) in studs to map scale (0..1, north up).
	toMap: (x: number, z: number) -> Vector2,
	portals: { [string]: TextButton },
	labels: { TextLabel },
}

local MapView = {}

function MapView.toMap(x: number, z: number): Vector2
	local half = WorldMap.halfSize
	return Vector2.new((x + half) / (2 * half), (half - z) / (2 * half))
end

local function shape(
	parent: GuiObject,
	name: string,
	center: Vector2,
	size: Vector2,
	color: Color3,
	round: UDim,
	zIndex: number
): Frame
	local half = WorldMap.halfSize
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	local point = MapView.toMap(center.X, center.Y)
	frame.Position = UDim2.fromScale(point.X, point.Y)
	frame.Size = UDim2.fromScale(size.X / (2 * half), size.Y / (2 * half))
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = round
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- `parent` gets a square canvas filling it. `portalSize` is the portal marker size in map scale.
function MapView.create(parent: GuiObject, portalSize: number): MapView
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = OCEAN
	canvas.BorderSizePixel = 0
	canvas.Parent = parent

	local coast = WorldMap.coastRadius * 2
	shape(canvas, "Island", Vector2.zero, Vector2.new(coast, coast), SAND, UDim.new(0.5, 0), 1)
	for _, region in WorldMap.regions do
		shape(
			canvas,
			region.island,
			region.area.center,
			region.area.size,
			region.color,
			UDim.new(0.12, 0),
			2
		)
	end
	shape(canvas, "River", WorldMap.river.center, WorldMap.river.size, RIVER, UDim.new(0.5, 0), 3)
	shape(canvas, "Chasm", WorldMap.chasm.center, WorldMap.chasm.size, CHASM, UDim.new(0.5, 0), 3)
	shape(
		canvas,
		"StitchSquare",
		WorldMap.square,
		Vector2.new(110, 110),
		SQUARE,
		UDim.new(0.5, 0),
		4
	)

	local labels: { TextLabel } = {}
	for _, region in WorldMap.regions do
		local island = Islands.get(region.island)
		local label = Instance.new("TextLabel")
		label.Name = "Label_" .. region.island
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		local point = MapView.toMap(region.label.X, region.label.Y)
		label.Position = UDim2.fromScale(point.X, point.Y)
		label.Size = UDim2.fromScale(0.3, 0.06)
		label.Text = if island ~= nil then island.displayName else region.island
		Theme.text(label, 22)
		label.ZIndex = 6
		label.Parent = canvas
		table.insert(labels, label)
	end

	local portals: { [string]: TextButton } = {}
	for _, portal in WorldMap.portals do
		local button = Instance.new("TextButton")
		button.Name = "Portal_" .. portal.island
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		local point = MapView.toMap(portal.position.X, portal.position.Y)
		button.Position = UDim2.fromScale(point.X, point.Y)
		button.Size = UDim2.fromScale(portalSize, portalSize)
		button.SizeConstraint = Enum.SizeConstraint.RelativeXX
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = PORTAL
		button.ZIndex = 7
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
		Theme.outline(button, 3, Theme.colors.lime)
		button.Parent = canvas
		portals[portal.island] = button
	end

	return {
		canvas = canvas,
		toMap = MapView.toMap,
		portals = portals,
		labels = labels,
	}
end

-- A "you are here" arrow: a dot with a nose that turns to face where you look.
function MapView.arrow(parent: GuiObject, zIndex: number): Frame
	local arrow = Instance.new("Frame")
	arrow.Name = "You"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.ZIndex = zIndex
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.6, 0.6)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.ZIndex = zIndex + 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	Theme.outline(dot, 2, Theme.colors.outline)
	dot.Parent = arrow
	local nose = Instance.new("Frame")
	nose.Name = "Nose"
	nose.AnchorPoint = Vector2.new(0.5, 1)
	nose.Position = UDim2.fromScale(0.5, 0.3)
	nose.Size = UDim2.fromScale(0.26, 0.4)
	nose.BackgroundColor3 = Theme.colors.lime
	nose.ZIndex = zIndex
	Theme.outline(nose, 2, Theme.colors.outline)
	nose.Parent = arrow
	arrow.Parent = parent
	return arrow
end

return MapView
