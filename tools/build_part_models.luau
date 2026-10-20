--!nocheck
-- Builds the placeholder (block-built) part models into ReplicatedStorage.PartModels.
-- Run in Studio Edit mode (Studio MCP execute_luau, or paste into the command bar).
-- Re-running replaces models with the same name and leaves any other models alone.
--
-- Not synced by Rojo: the models live in the place file. This script is their git backup.
-- Model contract (read by src/shared/CreatureAssembler.luau):
--   * every model faces -Z (forward) and has a part named "Root" as PrimaryPart
--   * attachments on Root, axis-aligned in world space:
--       Body: NeckAttach, HipAttach, BackAttach, TailAttach, SeatAttach
--       Head: NeckAttach       Legs: HipAttach
--       Back: BackAttach (sits on top) or TailAttach (sits at the rear), optional SeatAttach
--   * real art can replace a model later as long as it keeps the same name and attachments

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("PartModels")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "PartModels"
	folder.Parent = ReplicatedStorage
end

local C = Color3.fromRGB
local rad = math.rad
local UPRIGHT = CFrame.Angles(0, 0, rad(90)) -- cylinder axis X -> Y
local ALONG_Z = CFrame.Angles(0, rad(90), 0) -- cylinder axis X -> Z

local current: Model
local root: BasePart

local function begin(name)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	current = Instance.new("Model")
	current.Name = name
end

-- shape: "ball" | "cyl" | "egg" (stretchy sphere) | nil (block)
local function part(name, size, pos, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos) * (opts.rot or CFrame.identity)
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Transparency = opts.transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif opts.shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif opts.shape == "egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = current
	if name == "Root" then
		root = p
	end
	return p
end

-- An invisible anchor part for models with no single main piece (legs, wings, tails).
local function hiddenRoot()
	return part("Root", Vector3.new(0.4, 0.4, 0.4), Vector3.zero, C(255, 255, 255), { transparency = 1 })
end

local function attach(name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = root
	a.WorldCFrame = CFrame.new(pos)
end

local function finish()
	current.PrimaryPart = root
	current.Parent = folder
end

local function eyes(x, y, z, size, pupilSize)
	for _, side in { -1, 1 } do
		part("Eye", Vector3.one * size, Vector3.new(side * x, y, z), C(255, 255, 255), { shape = "ball" })
		part(
			"Pupil",
			Vector3.one * pupilSize,
			Vector3.new(side * x, y + size * 0.05, z - size * 0.35),
			C(25, 20, 35),
			{ shape = "ball" }
		)
	end
end

-- ===== Bodies =====

begin("StitchyBlob")
part("Root", Vector3.new(4.6, 4, 5), Vector3.zero, C(190, 165, 240), { shape = "egg" })
part("Stitch", Vector3.new(0.15, 0.12, 3.6), Vector3.new(0, 1.98, 0), C(60, 35, 90))
for _, z in { -1.2, -0.4, 0.4, 1.2 } do
	part("Stitch", Vector3.new(0.9, 0.12, 0.15), Vector3.new(0, 1.97, z), C(60, 35, 90))
end
attach("NeckAttach", Vector3.new(0, 0.9, -2.2))
attach("HipAttach", Vector3.new(0, -1.7, 0))
attach("BackAttach", Vector3.new(0, 1.9, 0.4))
attach("TailAttach", Vector3.new(0, 0.2, 2.4))
attach("SeatAttach", Vector3.new(0, 2.0, 0))
finish()

begin("PigBody")
part("Root", Vector3.new(4.2, 3.6, 5.6), Vector3.zero, C(255, 165, 195), { shape = "egg" })
part("Belly", Vector3.new(3.4, 2.4, 4.4), Vector3.new(0, -0.5, 0), C(255, 200, 215), { shape = "egg" })
attach("NeckAttach", Vector3.new(0, 0.7, -2.6))
attach("HipAttach", Vector3.new(0, -1.6, 0))
attach("BackAttach", Vector3.new(0, 1.7, 0.4))
attach("TailAttach", Vector3.new(0, 0.4, 2.8))
attach("SeatAttach", Vector3.new(0, 1.8, 0))
finish()

begin("SnailBody")
part("Root", Vector3.new(3.4, 2.6, 6), Vector3.zero, C(215, 190, 235), { shape = "egg" })
part("Shell", Vector3.one * 3.6, Vector3.new(0, 1.8, 0.8), C(190, 120, 80), { shape = "ball" })
part("Swirl", Vector3.one * 2.4, Vector3.new(0.9, 1.9, 0.8), C(220, 150, 100), { shape = "ball" })
part("SwirlCenter", Vector3.one * 1.2, Vector3.new(1.55, 2.0, 0.8), C(240, 180, 120), { shape = "ball" })
attach("NeckAttach", Vector3.new(0, 0.6, -2.9))
attach("HipAttach", Vector3.new(0, -1.2, 0))
attach("BackAttach", Vector3.new(0, 3.5, 0.8))
attach("TailAttach", Vector3.new(0, 0, 3.0))
attach("SeatAttach", Vector3.new(0, 3.6, 0.6))
finish()

begin("BearBody")
part("Root", Vector3.new(5, 4.4, 5.6), Vector3.zero, C(140, 90, 60), { shape = "egg" })
part("Belly", Vector3.new(3.6, 3.2, 4), Vector3.new(0, -0.4, -0.6), C(200, 160, 120), { shape = "egg" })
attach("NeckAttach", Vector3.new(0, 1.2, -2.6))
attach("HipAttach", Vector3.new(0, -2.0, 0))
attach("BackAttach", Vector3.new(0, 2.1, 0.4))
attach("TailAttach", Vector3.new(0, 0.2, 2.8))
attach("SeatAttach", Vector3.new(0, 2.2, 0))
finish()

begin("FrogBody")
part("Root", Vector3.new(4.8, 3.2, 5), Vector3.zero, C(90, 200, 90), { shape = "egg" })
part("Belly", Vector3.new(3.8, 2, 4), Vector3.new(0, -0.6, -0.3), C(200, 235, 140), { shape = "egg" })
for _, pos in { Vector3.new(-1, 1.3, 0.5), Vector3.new(1, 1.2, -0.3), Vector3.new(0.2, 1.45, 1.2) } do
	part("Spot", Vector3.one * 0.8, pos, C(60, 150, 70), { shape = "ball" })
end
attach("NeckAttach", Vector3.new(0, 0.6, -2.4))
attach("HipAttach", Vector3.new(0, -1.4, 0))
attach("BackAttach", Vector3.new(0, 1.6, 0.3))
attach("TailAttach", Vector3.new(0, 0, 2.4))
attach("SeatAttach", Vector3.new(0, 1.6, 0))
finish()

-- ===== Heads =====

begin("DuckHead")
part("Root", Vector3.one * 2.8, Vector3.zero, C(255, 220, 60), { shape = "ball" })
part("Beak", Vector3.new(1.4, 0.5, 1.4), Vector3.new(0, -0.2, -1.5), C(255, 150, 40), { shape = "egg" })
part("Tuft", Vector3.new(0.3, 0.8, 0.5), Vector3.new(0, 1.5, 0), C(255, 220, 60), { shape = "egg" })
eyes(0.6, 0.4, -1.1, 0.6, 0.32)
attach("NeckAttach", Vector3.new(0, -0.9, 0.9))
finish()

begin("MoleNose")
part("Root", Vector3.one * 2.6, Vector3.zero, C(110, 85, 75), { shape = "ball" })
part("Snout", Vector3.new(1, 0.9, 1.4), Vector3.new(0, -0.2, -1.3), C(130, 100, 90), { shape = "egg" })
part("Nose", Vector3.one * 0.9, Vector3.new(0, -0.1, -2.0), C(255, 140, 170), { shape = "ball" })
for _, side in { -1, 1 } do
	part("Eye", Vector3.one * 0.3, Vector3.new(side * 0.55, 0.45, -1.1), C(25, 20, 35), { shape = "ball" })
end
attach("NeckAttach", Vector3.new(0, -0.8, 0.8))
finish()

begin("OwlHead")
part("Root", Vector3.one * 3, Vector3.zero, C(180, 130, 70), { shape = "ball" })
part("Face", Vector3.new(2.4, 2, 0.5), Vector3.new(0, 0, -1.3), C(240, 220, 190), { shape = "egg" })
eyes(0.55, 0.15, -1.45, 0.9, 0.45)
part("Beak", Vector3.new(0.4, 0.6, 0.4), Vector3.new(0, -0.45, -1.7), C(255, 170, 50), { shape = "egg" })
for _, side in { -1, 1 } do
	part(
		"Tuft",
		Vector3.new(0.4, 1, 0.4),
		Vector3.new(side * 0.9, 1.5, 0),
		C(150, 100, 50),
		{ shape = "egg", rot = CFrame.Angles(0, 0, rad(-side * 20)) }
	)
end
attach("NeckAttach", Vector3.new(0, -1.0, 0.9))
finish()

begin("FireflyHead")
part("Root", Vector3.one * 2.4, Vector3.zero, C(240, 255, 110), { shape = "ball" })
for _, side in { -1, 1 } do
	part("Eye", Vector3.new(0.8, 0.9, 0.4), Vector3.new(side * 0.55, 0.25, -1.0), C(30, 30, 30), { shape = "egg" })
	part("Shine", Vector3.one * 0.25, Vector3.new(side * 0.45, 0.45, -1.2), C(255, 255, 255), { shape = "ball" })
	part(
		"Antenna",
		Vector3.new(1.4, 0.15, 0.15),
		Vector3.new(side * 0.45, 1.6, -0.2),
		C(60, 50, 40),
		{ shape = "cyl", rot = UPRIGHT * CFrame.Angles(rad(side * 15), 0, 0) }
	)
	part(
		"AntennaTip",
		Vector3.one * 0.5,
		Vector3.new(side * 0.6, 2.3, -0.2),
		C(255, 250, 150),
		{ shape = "ball", material = Enum.Material.Neon }
	)
end
attach("NeckAttach", Vector3.new(0, -0.8, 0.7))
finish()

-- ===== Legs =====

begin("DuckFeet")
hiddenRoot()
for _, side in { -1, 1 } do
	part("Leg", Vector3.new(1.4, 0.5, 0.5), Vector3.new(side * 1.1, -0.7, 0), C(255, 150, 40), { shape = "cyl", rot = UPRIGHT })
	part("Foot", Vector3.new(1.3, 0.35, 1.7), Vector3.new(side * 1.1, -1.4, -0.4), C(255, 150, 40), { shape = "egg" })
end
attach("HipAttach", Vector3.zero)
finish()

begin("FrogLegs")
hiddenRoot()
for _, side in { -1, 1 } do
	part("Thigh", Vector3.new(1.2, 1.4, 2), Vector3.new(side * 1.6, -0.5, 0.6), C(60, 180, 70), { shape = "egg" })
	part("Shin", Vector3.new(0.7, 1.4, 0.7), Vector3.new(side * 1.7, -1.3, 0), C(60, 180, 70), { shape = "egg" })
	part("Foot", Vector3.new(1.3, 0.3, 1.6), Vector3.new(side * 1.7, -2.0, -0.4), C(80, 200, 90), { shape = "egg" })
end
attach("HipAttach", Vector3.zero)
finish()

begin("CheetahLegs")
hiddenRoot()
for _, x in { -1.2, 1.2 } do
	for _, z in { -1.5, 1.5 } do
		part("Leg", Vector3.new(2.8, 0.6, 0.6), Vector3.new(x, -1.4, z), C(240, 180, 60), { shape = "cyl", rot = UPRIGHT })
		part("Paw", Vector3.one * 0.8, Vector3.new(x, -2.8, z - 0.1), C(240, 180, 60), { shape = "ball" })
		part("Spot", Vector3.one * 0.25, Vector3.new(x + 0.28, -1.0, z - 0.1), C(40, 30, 20), { shape = "ball" })
		part("Spot", Vector3.one * 0.25, Vector3.new(x - 0.25, -1.9, z + 0.15), C(40, 30, 20), { shape = "ball" })
	end
end
attach("HipAttach", Vector3.zero)
finish()

begin("ChickenLegs")
hiddenRoot()
for _, side in { -1, 1 } do
	part("Leg", Vector3.new(2.8, 0.35, 0.35), Vector3.new(side * 0.9, -1.4, 0), C(255, 170, 50), { shape = "cyl", rot = UPRIGHT })
	for _, angle in { -30, 0, 30 } do
		local yaw = CFrame.Angles(0, rad(angle), 0)
		local toe = CFrame.new(side * 0.9, -2.85, 0) * yaw * CFrame.new(0, 0, -0.45)
		part("Toe", Vector3.new(0.2, 0.15, 1.0), toe.Position, C(255, 170, 50), { rot = yaw })
	end
end
attach("HipAttach", Vector3.zero)
finish()

-- ===== Back =====

begin("PigTail")
hiddenRoot()
local curl = {
	Vector3.new(0, 0.1, 0.3),
	Vector3.new(0.25, 0.35, 0.6),
	Vector3.new(0, 0.6, 0.8),
	Vector3.new(-0.25, 0.4, 0.95),
	Vector3.new(0, 0.2, 1.0),
}
for _, pos in curl do
	part("Curl", Vector3.one * 0.45, pos, C(255, 140, 180), { shape = "ball" })
end
attach("TailAttach", Vector3.zero)
finish()

begin("TurtleShell")
part("Root", Vector3.new(0.6, 5.2, 5.2), Vector3.new(0, 0.3, 0), C(70, 150, 90), { shape = "cyl", rot = UPRIGHT })
part("Middle", Vector3.new(0.6, 4.2, 4.2), Vector3.new(0, 0.9, 0), C(80, 165, 100), { shape = "cyl", rot = UPRIGHT })
part("Dome", Vector3.new(3.6, 1.6, 3.6), Vector3.new(0, 1.2, 0), C(90, 175, 105), { shape = "egg" })
for _, pos in { Vector3.new(0, 1.95, 0), Vector3.new(1.1, 1.7, 0.6), Vector3.new(-1.1, 1.7, -0.6), Vector3.new(-1.0, 1.7, 0.8), Vector3.new(1.0, 1.7, -0.8) } do
	part("Plate", Vector3.new(0.15, 1, 1), pos, C(50, 120, 70), { shape = "cyl", rot = UPRIGHT })
end
attach("BackAttach", Vector3.zero)
attach("SeatAttach", Vector3.new(0, 2.0, 0))
finish()

begin("BatWings")
hiddenRoot()
for _, side in { -1, 1 } do
	local tilt = CFrame.Angles(0, 0, rad(side * 20))
	part("Membrane", Vector3.new(3.2, 0.2, 2.2), Vector3.new(side * 2.0, 0.6, 0.2), C(90, 70, 120), { rot = tilt })
	part("Bone", Vector3.new(3.4, 0.25, 0.25), Vector3.new(side * 2.0, 0.75, -0.85), C(60, 45, 80), { rot = tilt })
	part("Scallop", Vector3.new(1.2, 0.2, 1.0), Vector3.new(side * 3.3, 1.15, 0.9), C(90, 70, 120), { shape = "egg", rot = tilt })
end
attach("BackAttach", Vector3.zero)
finish()

begin("JellyfishTail")
hiddenRoot()
part(
	"Bell",
	Vector3.new(2, 1.2, 1.4),
	Vector3.new(0, 0.2, 0.6),
	C(150, 220, 255),
	{ shape = "egg", material = Enum.Material.Neon, transparency = 0.35 }
)
for i, x in { -0.7, -0.35, 0, 0.35, 0.7 } do
	local droop = CFrame.Angles(rad(-25 - (i % 2) * 10), 0, 0) * ALONG_Z
	part(
		"Tentacle",
		Vector3.new(3, 0.3, 0.3),
		Vector3.new(x, -0.5, 1.8),
		C(150, 220, 255),
		{ shape = "cyl", rot = droop, material = Enum.Material.Neon, transparency = 0.35 }
	)
end
attach("TailAttach", Vector3.zero)
finish()

-- ===== Phase 4: Cliffside Peaks and Windy Canyons =====

begin("GoatHorns")
part("Root", Vector3.one * 2.8, Vector3.zero, C(235, 230, 220), { shape = "ball" })
part("Snout", Vector3.new(1.4, 1.1, 1.4), Vector3.new(0, -0.45, -1.2), C(215, 200, 195), { shape = "egg" })
part("Nose", Vector3.new(0.6, 0.3, 0.3), Vector3.new(0, -0.25, -1.9), C(255, 150, 170), { shape = "egg" })
part("Beard", Vector3.new(0.5, 0.9, 0.5), Vector3.new(0, -1.45, -1.0), C(200, 195, 185), { shape = "egg" })
eyes(0.6, 0.45, -1.05, 0.55, 0.3)
for _, side in { -1, 1 } do
	part(
		"Horn",
		Vector3.new(1.6, 0.45, 0.45),
		Vector3.new(side * 0.7, 1.55, 0.35),
		C(150, 120, 90),
		{ shape = "cyl", rot = UPRIGHT * CFrame.Angles(rad(-35), 0, rad(side * 15)) }
	)
	part("HornTip", Vector3.one * 0.45, Vector3.new(side * 0.85, 2.1, 0.85), C(150, 120, 90), { shape = "ball" })
	part(
		"Ear",
		Vector3.new(0.9, 0.35, 0.5),
		Vector3.new(side * 1.5, 0.5, 0.1),
		C(235, 230, 220),
		{ shape = "egg", rot = CFrame.Angles(0, 0, rad(side * -20)) }
	)
end
attach("NeckAttach", Vector3.new(0, -0.9, 0.9))
finish()

begin("BatEars")
part("Root", Vector3.one * 2.6, Vector3.zero, C(110, 85, 140), { shape = "ball" })
part("Muzzle", Vector3.new(1.3, 0.9, 0.9), Vector3.new(0, -0.35, -1.05), C(150, 125, 175), { shape = "egg" })
eyes(0.55, 0.35, -1.0, 0.6, 0.32)
for _, side in { -1, 1 } do
	local tilt = CFrame.Angles(0, 0, rad(side * -25))
	part("Ear", Vector3.new(1.1, 2.2, 0.35), Vector3.new(side * 1.0, 1.8, 0.1), C(110, 85, 140), { shape = "egg", rot = tilt })
	part("EarInside", Vector3.new(0.6, 1.5, 0.2), Vector3.new(side * 1.0, 1.75, -0.08), C(255, 160, 190), { shape = "egg", rot = tilt })
	part("Fang", Vector3.new(0.18, 0.3, 0.18), Vector3.new(side * 0.25, -0.85, -1.35), C(255, 255, 255), { shape = "egg" })
end
attach("NeckAttach", Vector3.new(0, -0.8, 0.8))
finish()

begin("EagleHead")
part("Root", Vector3.one * 2.8, Vector3.zero, C(250, 250, 245), { shape = "ball" })
part("Beak", Vector3.new(0.9, 0.8, 1.5), Vector3.new(0, -0.15, -1.6), C(255, 195, 40), { shape = "egg" })
part("BeakTip", Vector3.new(0.45, 0.6, 0.45), Vector3.new(0, -0.5, -2.2), C(255, 195, 40), { shape = "egg" })
eyes(0.6, 0.4, -1.05, 0.6, 0.33)
for _, side in { -1, 1 } do
	part("Brow", Vector3.new(0.7, 0.2, 0.3), Vector3.new(side * 0.6, 0.85, -1.15), C(200, 160, 60), { rot = CFrame.Angles(0, 0, rad(side * 12)) })
end
part("Crest", Vector3.new(0.4, 0.9, 1.2), Vector3.new(0, 1.35, 0.5), C(250, 250, 245), { shape = "egg", rot = CFrame.Angles(rad(30), 0, 0) })
attach("NeckAttach", Vector3.new(0, -0.9, 0.9))
finish()

begin("ChickenBody")
part("Root", Vector3.new(4.2, 4, 5), Vector3.zero, C(250, 245, 235), { shape = "egg" })
for _, side in { -1, 1 } do
	part("Wing", Vector3.new(0.7, 2.2, 3), Vector3.new(side * 2.0, 0.1, 0.3), C(240, 230, 215), { shape = "egg" })
end
for i, angle in { -25, 0, 25 } do
	part(
		"TailFeather",
		Vector3.new(0.5, 1.8, 0.8),
		Vector3.new(angle / 40, 1.3 + (i == 2 and 0.3 or 0), 2.5),
		C(235, 225, 210),
		{ shape = "egg", rot = CFrame.Angles(rad(-30), 0, rad(angle)) }
	)
end
attach("NeckAttach", Vector3.new(0, 1.0, -2.3))
attach("HipAttach", Vector3.new(0, -1.8, 0))
attach("BackAttach", Vector3.new(0, 1.9, 0.2))
attach("TailAttach", Vector3.new(0, 0.6, 2.5))
attach("SeatAttach", Vector3.new(0, 2.0, 0))
finish()

begin("CheetahBody")
part("Root", Vector3.new(4, 3.2, 6.2), Vector3.zero, C(240, 180, 60), { shape = "egg" })
part("Belly", Vector3.new(3, 2, 4.8), Vector3.new(0, -0.6, 0), C(255, 230, 180), { shape = "egg" })
for _, pos in {
	Vector3.new(-1.2, 1.0, -1.5),
	Vector3.new(1.0, 1.2, -0.6),
	Vector3.new(-0.4, 1.5, 0.4),
	Vector3.new(1.3, 0.8, 1.4),
	Vector3.new(-1.4, 0.9, 1.2),
	Vector3.new(0.3, 1.45, 2.0),
} do
	part("Spot", Vector3.one * 0.45, pos, C(40, 30, 20), { shape = "ball" })
end
attach("NeckAttach", Vector3.new(0, 0.6, -2.9))
attach("HipAttach", Vector3.new(0, -1.4, 0))
attach("BackAttach", Vector3.new(0, 1.55, 0.4))
attach("TailAttach", Vector3.new(0, 0.4, 3.0))
attach("SeatAttach", Vector3.new(0, 1.6, 0))
finish()

begin("GoatLegs")
hiddenRoot()
for _, x in { -1.2, 1.2 } do
	for _, z in { -1.4, 1.4 } do
		part("Leg", Vector3.new(2.4, 0.7, 0.7), Vector3.new(x, -1.2, z), C(235, 230, 220), { shape = "cyl", rot = UPRIGHT })
		part("Hoof", Vector3.new(0.6, 0.85, 0.85), Vector3.new(x, -2.6, z), C(70, 55, 50), { shape = "cyl", rot = UPRIGHT })
	end
end
attach("HipAttach", Vector3.zero)
finish()

begin("OwlWings")
hiddenRoot()
for _, side in { -1, 1 } do
	local tilt = CFrame.Angles(0, 0, rad(side * 15))
	part("Wing", Vector3.new(3.4, 0.4, 2.4), Vector3.new(side * 2.0, 0.6, 0.3), C(180, 130, 70), { shape = "egg", rot = tilt })
	part("Covert", Vector3.new(2, 0.45, 1.6), Vector3.new(side * 1.5, 0.65, -0.1), C(225, 190, 140), { shape = "egg", rot = tilt })
	for i = 1, 3 do
		part(
			"Feather",
			Vector3.new(0.5, 0.3, 1.2),
			Vector3.new(side * (2.6 + i * 0.35), 0.9 + i * 0.12, 0.9),
			C(140, 95, 50),
			{ shape = "egg", rot = tilt }
		)
	end
end
attach("BackAttach", Vector3.zero)
finish()

begin("EagleWings")
hiddenRoot()
for _, side in { -1, 1 } do
	local tilt = CFrame.Angles(0, 0, rad(side * 12))
	part("Wing", Vector3.new(4.6, 0.45, 2.6), Vector3.new(side * 2.6, 0.7, 0.3), C(120, 80, 50), { shape = "egg", rot = tilt })
	part("Covert", Vector3.new(2.4, 0.5, 1.6), Vector3.new(side * 1.7, 0.75, -0.2), C(160, 110, 70), { shape = "egg", rot = tilt })
	for i = 1, 4 do
		part(
			"Feather",
			Vector3.new(0.55, 0.3, 1.6),
			Vector3.new(side * (3.4 + i * 0.45), 1.0 + i * 0.15, 0.9),
			if i == 4 then C(250, 250, 245) else C(95, 60, 35),
			{ shape = "egg", rot = tilt }
		)
	end
end
attach("BackAttach", Vector3.zero)
finish()

local names = {}
for _, m in folder:GetChildren() do
	table.insert(names, m.Name)
end
table.sort(names)
return `{#names} models: {table.concat(names, ", ")}`
