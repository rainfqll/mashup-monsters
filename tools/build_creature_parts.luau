--!nocheck
-- Turns AI-generated creatures into part models in ReplicatedStorage.PartModels.
-- Run in Studio Edit mode (Studio MCP execute_luau, or paste into the command bar).
--
-- Input: a folder CreatureStaging in Workspace (new generations) or in ServerStorage.ArtSource
-- (where this script keeps it afterwards), one Model per family named after it (Ember, Tide, ...),
-- straight from Studio's generate_mesh with explicit segmentation into
--   head, body, left arm, right arm, left leg, right leg, and a back piece
--   (left wing + right wing, or tail, shell, back)
-- ("front/back left/right leg" labels work too). Labels are from the creature's own point of
-- view. A model named "Blob" becomes the free StitchyBlob body.
-- If a finished creature faces the wrong way (check in Studio), set a Vector3 attribute
-- "Facing" on its staging model to the direction it really faces now, and run this again.
-- Re-running is safe: finished creatures are already upright, scaled and facing -Z.
--
-- Model contract (read by src/shared/CreatureAssembler.luau). Every model faces -Z (so its
-- right is +X) and has a PrimaryPart named "Root". Attachments sit where pieces join:
--   Body:  Root = body mesh with NeckAttach, LegFL, LegFR (arms), LegBL, LegBR (legs),
--          HipAttach, BackAttach, TailAttach, WingL, WingR, SeatAttach
--   Head:  Root = head mesh with NeckAttach and SeatAttach (riders sit on the head)
--   Legs:  Root = invisible anchor with HipAttach; limb meshes LegFL, LegFR, LegBL, LegBR, each
--          with an attachment of its own name where it meets the body
--   Back:  wings -> invisible Root with BackAttach, meshes WingL/WingR with WingL/WingR
--          tail  -> Root = tail mesh with TailAttach
--          shell -> Root = shell mesh with BackAttach and SeatAttach (the rider sits on it)
-- Bodies get every socket: ones their own family has no piece for are placed by shape, so any
-- head, legs or back piece can be stitched onto any body.
-- Old models with the same names are replaced; anything else in PartModels is left alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Every finished creature is scaled to this height (studs); the player is about 5.
local CREATURE_HEIGHT = 5.5
local BLOB_HEIGHT = 3.6

local artSource = ServerStorage:FindFirstChild("ArtSource")
if artSource == nil then
	artSource = Instance.new("Folder")
	artSource.Name = "ArtSource"
	artSource.Parent = ServerStorage
end
local staging = workspace:FindFirstChild("CreatureStaging") or artSource:FindFirstChild("CreatureStaging")
assert(staging, "Put the generated creatures in Workspace.CreatureStaging first")
local folder = ReplicatedStorage:FindFirstChild("PartModels")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "PartModels"
	folder.Parent = ReplicatedStorage
end

local ROLES = {
	["head"] = "Head",
	["body"] = "Body",
	["left arm"] = "LegFL",
	["front left leg"] = "LegFL",
	["right arm"] = "LegFR",
	["front right leg"] = "LegFR",
	["left leg"] = "LegBL",
	["back left leg"] = "LegBL",
	["right leg"] = "LegBR",
	["back right leg"] = "LegBR",
	["left wing"] = "WingL",
	["right wing"] = "WingR",
	["tail"] = "Tail",
	["shell"] = "Shell",
	["back"] = "Shell",
}
local MIRROR = { LegFL = "LegFR", LegFR = "LegFL", LegBL = "LegBR", LegBR = "LegBL", WingL = "WingR", WingR = "WingL" }

local function cleanName(name)
	return (string.lower(name):gsub('[%[%]"\\]', ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- World-space bounding box of one part (its mesh may be turned).
local function box(part)
	local half = part.Size / 2
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return { min = low, max = high, center = (low + high) / 2, size = high - low }
end

local function clampInto(point, b)
	return point:Max(b.min):Min(b.max)
end

-- Where two pieces meet: halfway between each one's point nearest the other's middle.
local function contact(a, b)
	local boxA, boxB = box(a), box(b)
	return (clampInto(boxB.center, boxA) + clampInto(boxA.center, boxB)) / 2
end

local function boxOfAll(parts)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in parts do
		local b = box(part)
		low = low:Min(b.min)
		high = high:Max(b.max)
	end
	return { min = low, max = high, center = (low + high) / 2, size = high - low }
end

local function horizontal(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Collects the segments of one generated creature by role.
local function segments(model)
	local found = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			local role = ROLES[cleanName(descendant.Parent.Name)] or ROLES[cleanName(descendant.Name)]
			if role and not found[role] then
				found[role] = descendant
			end
		end
	end
	return found
end

-- The creature's facing. Each labelled left/right pair votes (its right side minus its left,
-- turned a quarter); a tail or shell votes twice, since it is always behind. The generator
-- sometimes swaps one pair's labels, and the votes outweigh that. Wings don't vote on
-- "behind": they sit near the middle, and a long tail can pull the body's center back.
local function facing(found)
	local votes = Vector3.zero
	for left, right in { LegFL = "LegFR", LegBL = "LegBR", WingL = "WingR" } do
		local a, b = found[left], found[right]
		if a and b then
			local offset = horizontal(box(b).center - box(a).center)
			if offset.Magnitude > 0.3 then
				votes += Vector3.yAxis:Cross(offset.Unit)
			end
		end
	end
	local backPiece = found.Tail or found.Shell
	if backPiece and found.Body then
		local behind = horizontal(box(backPiece).center - box(found.Body).center)
		if behind.Magnitude > 0.3 then
			votes -= 2 * behind.Unit
		end
	end
	assert(votes.Magnitude > 0.1, "Can't tell which way the creature faces")
	return votes.Unit
end

-- Turns the creature to face -Z, scales it to `height`, and stands it on y = 0 at the origin.
local function normalize(parts, look, height)
	local all = boxOfAll(parts)
	local center = all.center
	local turn = CFrame.new(center) * CFrame.lookAt(center, center + look):Inverse()
	for _, part in parts do
		part.CFrame = turn * part.CFrame
	end
	all = boxOfAll(parts)
	local scale = height / all.size.Y
	local base = Vector3.new(all.center.X, all.min.Y, all.center.Z)
	for _, part in parts do
		local offset = part.Position - base
		part.Size *= scale
		part.CFrame = CFrame.new(offset * scale) * part.CFrame.Rotation
	end
end

local function prepare(part, name)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	-- A SurfaceAppearance (instead of TextureID) lets effects tint the part later.
	if part.TextureID ~= "" then
		local look = Instance.new("SurfaceAppearance")
		look.ColorMap = part.TextureID
		look.Parent = part
		part.TextureID = ""
	end
	return part
end

local function attach(part, name, worldPosition)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = part
	attachment.WorldCFrame = CFrame.new(worldPosition)
	return attachment
end

local function anchorPart(position)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.4
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.new(position)
	return root
end

local function save(model, name)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	model.Name = name
	model.Parent = folder
end

-- Sockets placed by shape, for bodies whose family has no piece there.
local function shapeSockets(b)
	local w, h, l = b.size.X, b.size.Y, b.size.Z
	local c = b.center
	return {
		NeckAttach = Vector3.new(c.X, b.max.Y - 0.1 * h, c.Z - 0.1 * l),
		-- Arms tuck in a little: a round body is narrower than its box away from the middle.
		LegFL = Vector3.new(c.X - 0.36 * w, c.Y + 0.1 * h, c.Z - 0.1 * l),
		LegFR = Vector3.new(c.X + 0.36 * w, c.Y + 0.1 * h, c.Z - 0.1 * l),
		LegBL = Vector3.new(c.X - 0.25 * w, b.min.Y + 0.1 * h, c.Z),
		LegBR = Vector3.new(c.X + 0.25 * w, b.min.Y + 0.1 * h, c.Z),
		WingL = Vector3.new(c.X - 0.2 * w, c.Y + 0.2 * h, b.max.Z - 0.15 * l),
		WingR = Vector3.new(c.X + 0.2 * w, c.Y + 0.2 * h, b.max.Z - 0.15 * l),
		TailAttach = Vector3.new(c.X, c.Y - 0.2 * h, b.max.Z - 0.05 * l),
		BackAttach = Vector3.new(c.X, c.Y + 0.1 * h, b.max.Z - 0.1 * l),
	}
end

local function buildFamily(model)
	local family = model.Name
	-- Mirrored limbs from an earlier run sit directly in the model; they are made again below.
	for _, child in model:GetChildren() do
		if child:IsA("MeshPart") then
			child:Destroy()
		end
	end
	local found = segments(model)
	assert(found.Head and found.Body, `{family}: needs a head and a body segment`)
	local parts = {}
	for _, part in found do
		table.insert(parts, part)
	end
	local override = model:GetAttribute("Facing")
	normalize(parts, if typeof(override) == "Vector3" then override.Unit else facing(found), CREATURE_HEIGHT)
	model:SetAttribute("Facing", nil)

	local body = found.Body
	local bodyBox = box(body)
	local sockets = shapeSockets(bodyBox)
	sockets.NeckAttach = contact(found.Head, body)

	-- Limbs: a missing or duplicated limb is copied from its partner, mirrored across the body.
	local limbs = {}
	for _, role in { "LegFL", "LegFR", "LegBL", "LegBR", "WingL", "WingR" } do
		limbs[role] = found[role]
	end
	for role, partner in MIRROR do
		local a, b = limbs[role], limbs[partner]
		if a and b and (box(a).center - box(b).center).Magnitude < 0.25 then
			limbs[role] = nil
		end
	end
	for role, partner in MIRROR do
		if limbs[role] == nil and limbs[partner] ~= nil then
			local copy = limbs[partner]:Clone()
			local mirroredX = 2 * bodyBox.center.X - limbs[partner].Position.X
			copy.CFrame = CFrame.new(mirroredX, copy.Position.Y, copy.Position.Z) * copy.CFrame.Rotation
			copy.Parent = model
			limbs[role] = copy
		end
	end
	-- Left is -X when facing -Z: swap any pair the labels got backwards.
	for left, right in { LegFL = "LegFR", LegBL = "LegBR", WingL = "WingR" } do
		local a, b = limbs[left], limbs[right]
		if a and b and box(a).center.X > box(b).center.X then
			limbs[left], limbs[right] = b, a
		end
	end
	for role, limb in limbs do
		sockets[role] = contact(limb, body)
	end
	if found.Tail then
		sockets.TailAttach = contact(found.Tail, body)
	end
	if found.Shell then
		sockets.BackAttach = contact(found.Shell, body)
	end
	if sockets.LegBL and sockets.LegBR then
		sockets.HipAttach = (sockets.LegBL + sockets.LegBR) / 2
	end
	local seat = Vector3.new(bodyBox.center.X, bodyBox.max.Y, bodyBox.center.Z + 0.15 * bodyBox.size.Z)

	-- Body
	local bodyModel = Instance.new("Model")
	local bodyRoot = prepare(body:Clone(), "Root")
	for name, position in sockets do
		attach(bodyRoot, name, position)
	end
	attach(bodyRoot, "SeatAttach", seat)
	bodyRoot.Parent = bodyModel
	bodyModel.PrimaryPart = bodyRoot
	save(bodyModel, family .. "Body")

	-- Head
	local headModel = Instance.new("Model")
	local headBox = box(found.Head)
	local headRoot = prepare(found.Head:Clone(), "Root")
	attach(headRoot, "NeckAttach", sockets.NeckAttach)
	-- The rider sits on top of the big head, toward the back, so the face stays in view.
	attach(headRoot, "SeatAttach", Vector3.new(headBox.center.X, headBox.max.Y - 0.1 * headBox.size.Y, headBox.center.Z + 0.2 * headBox.size.Z))
	headRoot.Parent = headModel
	headModel.PrimaryPart = headRoot
	save(headModel, family .. "Head")

	-- Legs (arms count as the front pair)
	if limbs.LegFL and limbs.LegFR and limbs.LegBL and limbs.LegBR then
		local legsModel = Instance.new("Model")
		local legsRoot = anchorPart(sockets.HipAttach)
		attach(legsRoot, "HipAttach", sockets.HipAttach)
		legsRoot.Parent = legsModel
		for _, role in { "LegFL", "LegFR", "LegBL", "LegBR" } do
			local limb = prepare(limbs[role]:Clone(), role)
			attach(limb, role, sockets[role])
			limb.Parent = legsModel
		end
		legsModel.PrimaryPart = legsRoot
		save(legsModel, family .. "Legs")
	end

	-- Back piece
	local backModel = Instance.new("Model")
	local backName
	if limbs.WingL and limbs.WingR then
		local middle = (sockets.WingL + sockets.WingR) / 2
		local backRoot = anchorPart(middle)
		attach(backRoot, "BackAttach", middle)
		backRoot.Parent = backModel
		backModel.PrimaryPart = backRoot
		for _, role in { "WingL", "WingR" } do
			local wing = prepare(limbs[role]:Clone(), role)
			attach(wing, role, sockets[role])
			wing.Parent = backModel
		end
		backName = "Wings"
	elseif found.Tail then
		local tail = prepare(found.Tail:Clone(), "Root")
		attach(tail, "TailAttach", sockets.TailAttach)
		tail.Parent = backModel
		backModel.PrimaryPart = tail
		backName = "Tail"
	elseif found.Shell then
		local shell = prepare(found.Shell:Clone(), "Root")
		local shellBox = box(found.Shell)
		attach(shell, "BackAttach", sockets.BackAttach)
		attach(shell, "SeatAttach", Vector3.new(shellBox.center.X, shellBox.max.Y, shellBox.center.Z))
		shell.Parent = backModel
		backModel.PrimaryPart = shell
		backName = if family == "Moss" then "Back" else "Shell"
	end
	if backName then
		save(backModel, family .. backName)
	end
	return family
end

local function buildBlob(model)
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	assert(mesh, "Blob: no mesh")
	normalize({ mesh }, Vector3.new(0, 0, -1), BLOB_HEIGHT)
	local blobBox = box(mesh)
	local blobModel = Instance.new("Model")
	local root = prepare(mesh:Clone(), "Root")
	local sockets = shapeSockets(blobBox)
	sockets.HipAttach = (sockets.LegBL + sockets.LegBR) / 2
	for name, position in sockets do
		attach(root, name, position)
	end
	attach(root, "SeatAttach", Vector3.new(blobBox.center.X, blobBox.max.Y, blobBox.center.Z))
	root.Parent = blobModel
	blobModel.PrimaryPart = root
	save(blobModel, "StitchyBlob")
end

local built = {}
for _, model in staging:GetChildren() do
	if model:IsA("Model") then
		if model.Name == "Blob" then
			buildBlob(model)
			table.insert(built, "StitchyBlob")
		elseif model:GetAttribute("Skip") ~= true then
			table.insert(built, buildFamily(model))
		end
	end
end
-- The sources stay as a backup, out of the live world.
staging.Parent = artSource
return "Built: " .. table.concat(built, ", ")
