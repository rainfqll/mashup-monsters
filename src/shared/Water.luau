--!strict
-- Terrain water lookups shared by the client (instant feedback) and the server (the check that
-- an exploiter can't skip). Islands are gated by water, so both sides must agree on "in water".

local Water = {}

-- True if the 4-stud terrain cell(s) around `position` hold water.
function Water.isWaterAt(position: Vector3): boolean
	local region = Region3.new(position - Vector3.one, position + Vector3.one):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4)
	for x = 1, materials.Size.X do
		for y = 1, materials.Size.Y do
			for z = 1, materials.Size.Z do
				if materials[x][y][z] == Enum.Material.Water then
					return true
				end
			end
		end
	end
	return false
end

-- A point just above the character's (or its creature's) feet. A tall creature wades through
-- shallow water without ever "swimming", so checking here also catches wading.
function Water.feetPosition(humanoid: Humanoid, root: BasePart): Vector3
	return root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight - 1, 0)
end

return Water
