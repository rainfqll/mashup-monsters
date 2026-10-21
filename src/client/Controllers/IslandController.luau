--!strict
-- IslandController: notices when you arrive in a different region ("island" in code) so the UI
-- can show its name and the ambience can change. Purely cosmetic; the server records regions
-- and checks every arrival itself (IslandService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)

local ZONE_TAG = "IslandZone"
local CHECK_INTERVAL = 0.5

local player = Players.LocalPlayer
local currentIsland: string? = nil
local listeners: { (displayName: string) -> () } = {}

local function zoneAt(position: Vector3): BasePart?
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") then
			local localPoint = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(localPoint.X) <= half.X
				and math.abs(localPoint.Y) <= half.Y
				and math.abs(localPoint.Z) <= half.Z
			then
				return zone
			end
		end
	end
	return nil
end

local IslandController = {}

-- The region (island id) you are in now, or nil before the first check or between regions.
function IslandController.current(): string?
	return currentIsland
end

-- Called with the island's display name each time you arrive on a different island.
function IslandController.onIslandEntered(listener: (displayName: string) -> ()): ()
	table.insert(listeners, listener)
end

function IslandController.start(): ()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			local zone = if root ~= nil and root:IsA("BasePart") then zoneAt(root.Position) else nil
			if zone ~= nil then
				local islandId = zone:GetAttribute("Island")
				if type(islandId) == "string" and islandId ~= currentIsland then
					-- The first zone after joining is just where you spawned, so don't announce it.
					local announce = currentIsland ~= nil
					currentIsland = islandId
					local island = Islands.get(islandId)
					local displayName = if island ~= nil
						then island.displayName
						else zone:GetAttribute("DisplayName")
					if announce and type(displayName) == "string" then
						for _, listener in listeners do
							task.spawn(listener, displayName)
						end
					end
				end
			end
		end
	end)
end

return IslandController
