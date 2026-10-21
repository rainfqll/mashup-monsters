--!strict
-- What the maps draw (the corner mini map and the big map). A simple picture of the One World
-- in world coordinates (studs; on the map +x is right and +z, north, is up). Kept as data instead of
-- reading Studio parts, because far-away parts are not streamed in and the map must show
-- everything. Keep it in sync with tools/generate_world.luau and the portals in Studio.

export type Rect = { center: Vector2, size: Vector2 }

export type RegionArea = {
	island: string,
	color: Color3,
	area: Rect,
	-- Where the region's name is written.
	label: Vector2,
}

export type Portal = {
	-- The region this portal stands in (an island id); also where travelling to it takes you.
	island: string,
	position: Vector2,
	-- Write the map caption above the portal instead of below (when another portal is close).
	captionAbove: boolean?,
}

local REGIONS: { RegionArea } = {
	{
		island = "MeadowIsle",
		color = Color3.fromRGB(110, 185, 75),
		area = { center = Vector2.new(-125, 0), size = Vector2.new(750, 420) },
		label = Vector2.new(0, -45),
	},
	{
		island = "LilyLagoon",
		color = Color3.fromRGB(70, 160, 110),
		area = { center = Vector2.new(-116, 395), size = Vector2.new(728, 250) },
		label = Vector2.new(-60, 400),
	},
	{
		island = "CliffsidePeaks",
		color = Color3.fromRGB(140, 140, 155),
		area = { center = Vector2.new(387, 145), size = Vector2.new(266, 710) },
		label = Vector2.new(390, 120),
	},
	{
		island = "WindyCanyons",
		color = Color3.fromRGB(220, 150, 90),
		area = { center = Vector2.new(0, -404), size = Vector2.new(960, 232) },
		label = Vector2.new(0, -430),
	},
}

local PORTALS: { Portal } = {
	{ island = "MeadowIsle", position = Vector2.new(-38, 0) },
	{ island = "LilyLagoon", position = Vector2.new(60, 300) },
	{ island = "CliffsidePeaks", position = Vector2.new(276, -26), captionAbove = true },
	{ island = "WindyCanyons", position = Vector2.new(40, -324) },
}

for _, region in REGIONS do
	table.freeze(region.area)
	table.freeze(region)
end
for _, portal in PORTALS do
	table.freeze(portal)
end

return table.freeze({
	-- The square the big map shows (studs from the middle to each edge).
	halfSize = 600,
	-- Roughly where the beaches are.
	coastRadius = 545,
	regions = table.freeze(REGIONS),
	-- Water and the chasm drawn over the regions: { center, size } rectangles.
	river = table.freeze({ center = Vector2.new(-146, 240), size = Vector2.new(798, 52) }),
	chasm = table.freeze({ center = Vector2.new(0, -248), size = Vector2.new(1090, 72) }),
	square = Vector2.new(0, 0),
	portals = table.freeze(PORTALS),
})
