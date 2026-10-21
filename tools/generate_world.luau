--!nocheck
-- Builds the One World terrain (World Upgrade W3a): one connected land with Stitch Square in the
-- middle of the home meadows, the Lily Lagoon wetlands north across a river (Swim), the Cliffside
-- Peaks mountains east behind a cliff with jump steps (Super Jump), and the Windy Canyons desert
-- south across a bottomless chasm (Glide). Ocean and beaches all around.
--
-- Run in Studio Edit mode (Studio MCP execute_luau, or the command bar). It rewrites ALL terrain
-- in the world square. Set FIRST_ROW/LAST_ROW to build part of it per call (rows of chunks
-- along z), so no single call freezes Studio for long; CLEAR_FIRST wipes terrain first.
-- The shapes are plain functions of (x, z): tune a constant, run again.
--
-- Gameplay heights the rest of the world relies on (keep in sync with Config/Islands zones,
-- the content placed on top, and IslandService):
--   (the rendered terrain surface sits about 1.8 studs above these numbers; rises between
--   them are what matter)
--   home meadows y=20 (Stitch Square flat at 20), river water 17, sea 10,
--   jump steps 32/44/56/68 then the Peaks plateau at 80 (12-stud rises: Super Jump only),
--   Canyons floor 40, mesa tops 92, chasm z = -212..-284 (no ground at all).

local FIRST_ROW = 1
local LAST_ROW = 10
local CLEAR_FIRST = false

local Terrain = workspace.Terrain
local VOXEL = 4
local HALF = 640
local CHUNK = 128
local Y_MIN, Y_MAX = -28, 188
local SEED = 1337

local SEA = 10
local HOME_Y = 20
local RIVER_WATER = 17
local RIVER_HALF = 26
local PLATEAU_Y = 80
local CANYON_Y = 40
local MESA_Y = 92
local PLAZA_RADIUS = 48
-- The Wind Rings course needs open air: no mesas within this circle.
local RING_VALLEY = { x = 0, z = -430, r = 95 }
-- A grassy hill on the home side of the chasm to start glides from.
local BLUFF = { x = 30, z = -183, r = 48, height = 32 }

local M = Enum.Material

local function noise(x, z, scale, salt)
	return math.noise(x / scale, z / scale, SEED + salt)
end

local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function coastRadius(x, z)
	local angle = math.atan2(z, x)
	return 555 + 50 * math.noise(math.cos(angle) * 1.6, math.sin(angle) * 1.6, SEED + 9)
end
local function riverZ(x)
	return 240 + 16 * noise(x, 0, 150, 1)
end
local function chasmNorth(x)
	return -212 + 8 * noise(x, 0, 110, 2)
end
local function chasmSouth(x)
	return -284 + 8 * noise(x, 0, 110, 3)
end
local function cliffX(z)
	-- Straight where the jump steps are, so the steps meet the plateau edge exactly.
	local wiggle = 14 * noise(0, z, 120, 4)
	return 252 + wiggle * smoothstep((math.abs(z) - 20) / 40)
end

-- Distance from (x, z) to the segment a-b, for the dirt paths.
local function segmentDistance(x, z, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
	local px, pz = ax + dx * t, az + dz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
end
local PATHS = {
	{ 0, 0, 0, 205 }, -- north to the river dock (Lily Lagoon)
	{ 0, 0, 200, 0 }, -- east to the jump steps (Cliffside Peaks)
	{ 0, 0, 22, -150 }, -- south to the Wind Bluff (Windy Canyons)
}

-- One column of the world: ground height (nil = nothing, the chasm), its top material, and the
-- water level above it (nil = dry).
local function column(x, z)
	local r = math.sqrt(x * x + z * z)
	local coast = coastRadius(x, z)
	if r > coast then
		return SEA - 6 - math.min((r - coast) * 0.25, 14), M.Sand, SEA
	end
	local north, south = chasmNorth(x), chasmSouth(x)
	if z < north and z > south then
		return nil, nil, nil
	end
	local beach = smoothstep((r - (coast - 50)) / 50)
	local h, top, water
	local cliff = cliffX(z)

	if x > cliff and z > north then
		-- Cliffside Peaks: a flat plateau by the cliff, snowy mountains rising behind it,
		-- and a stream that runs to the cliff edge (the waterfall into the river).
		-- Flat next to the jump steps: the last rise must stay 12 studs (Super Jump reaches ~16).
		local nearSteps = smoothstep((math.sqrt((x - 252) ^ 2 + z * z) - 25) / 30)
		h = PLATEAU_Y + 2.5 * noise(x, z, 40, 5) * nearSteps
		local rise = math.max(0, x - 395) * 0.7 + 45 * math.max(0, noise(x, z, 70, 6))
		h += math.min(rise, 95)
		top = if h > 140 then M.Snow elseif rise > 12 then M.Rock else M.Grass
		local stream = math.abs(z - riverZ(x))
		if x < 420 and stream < 9 then
			h = math.min(h, PLATEAU_Y - 5)
			water = PLATEAU_Y - 2
			top = M.Slate
		end
	elseif z <= south then
		-- Windy Canyons: a sandy floor with flat-topped mesas, and an open valley for the rings.
		h = CANYON_Y + 2 * noise(x, z, 50, 10)
		top = M.Sand
		local valley = math.sqrt((x - RING_VALLEY.x) ^ 2 + (z - RING_VALLEY.z) ^ 2)
		local mesa = noise(x, z, 85, 11)
		if mesa > 0.2 and valley > RING_VALLEY.r and z < south - 20 then
			h = MESA_Y + 2 * noise(x, z, 20, 12)
			top = M.Sandstone
		end
	else
		local fromRiver = z - riverZ(x)
		if math.abs(fromRiver) <= RIVER_HALF then
			-- The river (Swim): deep, wide, running from the waterfall to the sea.
			h = 5 + 2 * noise(x, z, 30, 13)
			top = M.Sand
			water = RIVER_WATER
		elseif fromRiver > RIVER_HALF then
			-- Lily Lagoon wetlands: low and soggy, dotted with ponds.
			h = 19 + 2 * noise(x, z, 60, 7)
			top = M.LeafyGrass
			local pond = noise(x, z, 90, 8)
			if pond < -0.18 then
				h = 12
				water = RIVER_WATER
				top = M.Mud
			elseif pond < -0.1 then
				top = M.Mud
			end
			-- Banks slope down into the river.
			h = math.min(h, RIVER_WATER - 1 + (fromRiver - RIVER_HALF) * 0.5)
		else
			-- Home meadows: gentle hills; Stitch Square is flat paving.
			h = HOME_Y + 5 * math.max(0, noise(x, z, 80, 14)) + 1.5 * noise(x, z, 25, 15)
			top = M.Grass
			local flat = smoothstep((r - PLAZA_RADIUS) / 40)
			h = HOME_Y + (h - HOME_Y) * flat
			if r < PLAZA_RADIUS then
				top = M.Cobblestone
			end
			local bluff = math.sqrt((x - BLUFF.x) ^ 2 + (z - BLUFF.z) ^ 2)
			h += BLUFF.height * smoothstep(1 - bluff / BLUFF.r)
			-- Banks slope down into the river.
			h = math.min(h, RIVER_WATER - 1 + (-fromRiver - RIVER_HALF) * 0.5)
			-- The jump steps to Cliffside Peaks: four rock pillars, 12 studs apart in height.
			if math.abs(z) < 10 and x > cliff - 40 and x < cliff then
				local step = math.floor((x - (cliff - 40)) / 10)
				h = 32 + 12 * step
				top = M.Rock
			end
			for _, path in PATHS do
				if r > PLAZA_RADIUS - 4 and segmentDistance(x, z, path[1], path[2], path[3], path[4]) < 4 then
					top = M.Ground
				end
			end
		end
	end

	if beach > 0 then
		h = h + (SEA - 1 - h) * beach ^ 1.5
		if beach > 0.35 then
			top = M.Sand
		end
		if water == nil and h < SEA then
			water = SEA
		end
	end
	return h, top, water
end

local SUBSOIL = {
	[M.Grass] = M.Ground,
	[M.LeafyGrass] = M.Mud,
	[M.Mud] = M.Ground,
	[M.Snow] = M.Rock,
	[M.Cobblestone] = M.Ground,
	[M.Ground] = M.Ground,
	[M.Slate] = M.Rock,
}

local function buildChunk(x0, z0)
	local nx = CHUNK / VOXEL
	local ny = (Y_MAX - Y_MIN) / VOXEL
	local materials, occupancy = table.create(nx), table.create(nx)
	for ix = 1, nx do
		local matsX, occX = table.create(ny), table.create(ny)
		for iy = 1, ny do
			matsX[iy] = table.create(nx, M.Air)
			occX[iy] = table.create(nx, 0)
		end
		materials[ix], occupancy[ix] = matsX, occX
	end
	for ix = 1, nx do
		local x = x0 + (ix - 0.5) * VOXEL
		for iz = 1, nx do
			local z = z0 + (iz - 0.5) * VOXEL
			local h, top, water = column(x, z)
			for iy = 1, ny do
				local bottom = Y_MIN + (iy - 1) * VOXEL
				if h ~= nil and bottom < h then
					local depth = h - (bottom + VOXEL / 2)
					materials[ix][iy][iz] = if depth < 4
						then top
						elseif depth < 14 then (SUBSOIL[top] or top)
						else M.Rock
					occupancy[ix][iy][iz] = math.clamp((h - bottom) / VOXEL, 0, 1)
				elseif water ~= nil and bottom < water then
					materials[ix][iy][iz] = M.Water
					occupancy[ix][iy][iz] = math.clamp((water - bottom) / VOXEL, 0, 1)
				end
			end
		end
	end
	local region = Region3.new(Vector3.new(x0, Y_MIN, z0), Vector3.new(x0 + CHUNK, Y_MAX, z0 + CHUNK))
	Terrain:WriteVoxels(region, VOXEL, materials, occupancy)
end

if CLEAR_FIRST then
	Terrain:Clear()
end
local rows = (2 * HALF) / CHUNK
local built = 0
for row = FIRST_ROW, math.min(LAST_ROW, rows) do
	local z0 = -HALF + (row - 1) * CHUNK
	for col = 1, rows do
		buildChunk(-HALF + (col - 1) * CHUNK, z0)
		built += 1
		task.wait()
	end
end
return `built {built} chunks (rows {FIRST_ROW}-{math.min(LAST_ROW, rows)})`
