--!nocheck
-- Plants the nature props of the One World (World Upgrade W3c): trees, bushes, mushrooms and
-- cacti per region, on dry, gentle ground, away from the plaza, paths, and gameplay spots.
-- Run in Studio Edit mode after tools/generate_world.luau. Re-running replaces Workspace.Nature.
--
-- Prop templates are Models in ServerStorage.ArtSource.Props (an AI-generated MeshPart inside,
-- upright, with the model's pivot at the middle of its base). Each placed copy shares the template's mesh and texture, so hundreds of
-- them cost little memory. Big props (trees, cacti) get an invisible trunk collider, so you
-- bump into the trunk instead of the leaves.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local SEED = 77
local templates = ServerStorage.ArtSource.Props

-- region: where to look (x/z ranges, allowed ground heights) and what to plant how often.
local REGIONS = {
	{
		name = "HomeMeadows",
		x = { -540, 240 },
		z = { -200, 205 },
		y = { 18, 60 },
		props = { { "OakTree", 70 }, { "FlowerBush", 90 } },
	},
	{
		name = "LilyLagoon",
		x = { -520, 240 },
		z = { 285, 560 },
		y = { 12, 30 },
		props = { { "WillowTree", 45 }, { "GlowMushroom", 35 }, { "FlowerBush", 30 } },
	},
	{
		name = "CliffsidePeaks",
		x = { 262, 540 },
		z = { -200, 560 },
		y = { 78, 165 },
		props = { { "PineTree", 90 } },
	},
	{
		name = "WindyCanyons",
		x = { -520, 520 },
		z = { -600, -300 },
		y = { 38, 50 },
		props = { { "Cactus", 55 } },
	},
}

-- Props that get a trunk collider: { radius, height } in studs at scale 1.
local COLLIDERS = {
	OakTree = { 1.6, 10 },
	WillowTree = { 1.6, 10 },
	PineTree = { 1.2, 10 },
	Cactus = { 1.4, 7 },
}

-- Places nothing may grow: circles { x, z, radius }.
local keepOut = {
	{ 0, 0, 78 }, -- Stitch Square and its ring of cottages
	{ 30, -183, 40 }, -- Wind Bluff top
	{ 0, -430, 60 }, -- Wind Rings course
	{ 230, 0, 30 }, -- jump steps
}
-- Paths (same segments as tools/generate_world.luau), kept clear 8 studs either side.
local PATHS = { { 0, 0, 0, 205 }, { 0, 0, 200, 0 }, { 0, 0, 22, -150 } }
for _, tag in { "EggSpot", "CoinSpot", "GiantFossil", "GuideTarget", "ChallengeChest" } do
	for _, part in CollectionService:GetTagged(tag) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			table.insert(keepOut, { part.Position.X, part.Position.Z, 10 })
		end
	end
end

local function segmentDistance(x, z, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((x - (ax + dx * t)) ^ 2 + (z - (az + dz * t)) ^ 2)
end

local function blocked(x, z)
	for _, c in keepOut do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < c[3] ^ 2 then
			return true
		end
	end
	for _, p in PATHS do
		if segmentDistance(x, z, p[1], p[2], p[3], p[4]) < 8 then
			return true
		end
	end
	return false
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = false

local old = workspace:FindFirstChild("Nature")
if old then
	old:Destroy()
end
local nature = Instance.new("Folder")
nature.Name = "Nature"

local rng = Random.new(SEED)
local report = {}
for _, region in REGIONS do
	local folder = Instance.new("Folder")
	folder.Name = region.name
	for _, entry in region.props do
		local template = templates:FindFirstChild(entry[1])
		local placed = 0
		if template then
			for _ = 1, entry[2] * 12 do
				if placed >= entry[2] then
					break
				end
				local x = rng:NextNumber(region.x[1], region.x[2])
				local z = rng:NextNumber(region.z[1], region.z[2])
				if not blocked(x, z) then
					local hit = workspace:Raycast(Vector3.new(x, 260, z), Vector3.new(0, -400, 0), params)
					if
						hit
						and hit.Material ~= Enum.Material.Water
						and hit.Normal.Y > 0.88
						and hit.Position.Y >= region.y[1]
						and hit.Position.Y <= region.y[2]
					then
						local scale = rng:NextNumber(0.8, 1.35)
						local copy = template:Clone()
						copy:ScaleTo(scale)
						-- Sunk a little so it never floats on a slope.
						local base = hit.Position - Vector3.new(0, 0.4 * scale, 0)
						copy:PivotTo(CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
						local collider = COLLIDERS[entry[1]]
						if collider then
							local trunk = Instance.new("Part")
							trunk.Name = "Trunk"
							trunk.Shape = Enum.PartType.Cylinder
							trunk.Size = Vector3.new(collider[2] * scale, collider[1] * 2 * scale, collider[1] * 2 * scale)
							trunk.CFrame = CFrame.new(base + Vector3.new(0, collider[2] * scale / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
							trunk.Transparency = 1
							trunk.Anchored = true
							trunk.CanQuery = false
							trunk.Parent = copy
						end
						copy.Parent = folder
						placed += 1
					end
				end
			end
		end
		table.insert(report, `{region.name}: {placed} {entry[1]}`)
	end
	folder.Parent = nature
	task.wait()
end
nature.Parent = workspace
return table.concat(report, "\n")
