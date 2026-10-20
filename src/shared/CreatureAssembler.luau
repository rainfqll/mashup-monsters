--!strict
-- Builds a creature Model from a loadout by snapping part models together at their named
-- attachments. Used by the server (the real creature) and the client (the stitch preview),
-- so both always agree on what a creature looks like.
--
-- Part models live in ReplicatedStorage.PartModels; their contract is documented in
-- tools/build_part_models.luau. A missing model becomes a gray block plus a warning, so a new
-- part without art yet never breaks stitching.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(script.Parent.Creatures)
local Parts = require(script.Parent.Config.Parts)
local Types = require(script.Parent.Types)

-- Which body attachment each slot snaps to. Back parts pick whichever they carry, so wings and
-- shells sit on top while tails sit at the rear.
local SOCKETS: { [Types.Slot]: { string } } = {
	Head = { "NeckAttach" },
	Legs = { "HipAttach" },
	Back = { "BackAttach", "TailAttach" },
}

-- Seconds; bounded so a missing PartModels folder is a clear error instead of a hang.
local WAIT_SECONDS = 15

local function templates(): Instance
	local folder = ReplicatedStorage:WaitForChild("PartModels", WAIT_SECONDS)
	if folder == nil then
		error(
			"ReplicatedStorage.PartModels is missing (run tools/build_part_models.luau in Studio)"
		)
	end
	return folder
end

local function findAttachment(model: Model, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	if found ~= nil and found:IsA("Attachment") then
		return found
	end
	return nil
end

local function placeholder(id: string): Model
	warn(`[Mashup Monsters] no model for part "{id}" in PartModels; using a placeholder block`)
	local model = Instance.new("Model")
	model.Name = id
	local block = Instance.new("Part")
	block.Name = "Root"
	block.Size = Vector3.new(2, 2, 2)
	block.Color = Color3.fromRGB(150, 150, 150)
	block.Anchored = true
	block.CanCollide = false
	block.Parent = model
	model.PrimaryPart = block
	return model
end

local function clonePart(folder: Instance, id: string): Model
	local definition = Parts.get(id)
	local template = if definition ~= nil then folder:FindFirstChild(definition.modelName) else nil
	if template == nil or not template:IsA("Model") then
		return placeholder(id)
	end
	return template:Clone()
end

local CreatureAssembler = {}

-- Returns an anchored Model whose PrimaryPart "Hitbox" is an invisible box around the whole
-- creature, with every other part welded to it. Attributes for movement code:
--   SeatOffset (Vector3): where the rider sits, relative to the Hitbox
--   HalfHeight (number):  Hitbox center height above the creature's lowest point
function CreatureAssembler.build(loadout: Types.Loadout): Model
	local folder = templates()
	local creature = Instance.new("Model")
	creature.Name = "Creature"

	local body = clonePart(folder, loadout.Body or Creatures.DEFAULT_BODY)
	body:PivotTo(CFrame.identity)
	body.Parent = creature
	local seat = findAttachment(body, "SeatAttach")

	for slot, socketNames in SOCKETS do
		local id = (loadout :: any)[slot] :: string?
		if id ~= nil then
			local piece = clonePart(folder, id)
			for _, socketName in socketNames do
				local plug = findAttachment(piece, socketName)
				local socket = findAttachment(body, socketName)
				if plug ~= nil and socket ~= nil then
					piece:PivotTo(piece:GetPivot() + (socket.WorldPosition - plug.WorldPosition))
					break
				end
			end
			piece.Parent = creature
			-- A shell on the back raises the seat so the rider sits on top of it.
			local pieceSeat = findAttachment(piece, "SeatAttach")
			if slot == "Back" and pieceSeat ~= nil then
				seat = pieceSeat
			end
		end
	end

	local boxCFrame, boxSize = creature:GetBoundingBox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = boxSize
	hitbox.CFrame = CFrame.new(boxCFrame.Position)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = false
	hitbox.Parent = creature

	for _, descendant in creature:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= hitbox then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hitbox
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	local seatPosition = if seat ~= nil
		then seat.WorldPosition
		else hitbox.Position + Vector3.new(0, boxSize.Y / 2, 0)
	creature:SetAttribute("SeatOffset", hitbox.CFrame:PointToObjectSpace(seatPosition))
	creature:SetAttribute("HalfHeight", boxSize.Y / 2)
	creature.PrimaryPart = hitbox
	return creature
end

return CreatureAssembler
