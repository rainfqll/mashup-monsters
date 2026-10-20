--!strict
-- IslandService: knows which island each player is on, and enforces water gates.
--
-- Islands: invisible box parts tagged "IslandZone" with a string attribute "Island" (an id like
-- "LilyLagoon") and "DisplayName". Stepping into any island other than "MeadowIsle" records the
-- FirstNewIsland milestone.
-- Water: the client already bounces non-swimmers out instantly (CreatureController). This is
-- the server's own check, so skipping the client check doesn't get an exploiter past a gate.
-- It waits a moment before acting so it never fights the client's smoother bounce.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Water = require(ReplicatedStorage.Shared.Water)
local CreatureService = require(script.Parent.CreatureService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ZONE_TAG = "IslandZone"
local HOME_ISLAND = "MeadowIsle"
local CHECK_INTERVAL = 0.25
local ZONE_CHECK_INTERVAL = 1
-- Seconds in water without a swimmer before the server steps in.
local WATER_GRACE = 1

type Watch = {
	lastSafe: CFrame?,
	inWaterSince: number?,
}

local watches: { [Player]: Watch } = {}

local function islandAt(position: Vector3): string?
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") then
			local localPoint = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(localPoint.X) <= half.X
				and math.abs(localPoint.Y) <= half.Y
				and math.abs(localPoint.Z) <= half.Z
			then
				local island = zone:GetAttribute("Island")
				return if type(island) == "string" then island else nil
			end
		end
	end
	return nil
end

local function characterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function checkWater(player: Player, watch: Watch, now: number): ()
	local humanoid, root = characterParts(player)
	if humanoid == nil or root == nil then
		watch.inWaterSince = nil
		return
	end
	local inWater = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or Water.isWaterAt(Water.feetPosition(humanoid, root))
	if not inWater then
		watch.inWaterSince = nil
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			watch.lastSafe = root.CFrame
		end
		return
	end
	if CreatureService.canSwim(player) then
		watch.inWaterSince = nil
		return
	end
	local since = watch.inWaterSince
	if since == nil then
		watch.inWaterSince = now
	elseif now - since >= WATER_GRACE and watch.lastSafe ~= nil then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = watch.lastSafe :: CFrame
		watch.inWaterSince = nil
	end
end

local IslandService = {}

function IslandService.start(): ()
	Players.PlayerRemoving:Connect(function(player)
		watches[player] = nil
	end)

	task.spawn(function()
		local nextZoneCheck = 0
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.clock()
			local checkZones = now >= nextZoneCheck
			if checkZones then
				nextZoneCheck = now + ZONE_CHECK_INTERVAL
			end
			for _, player in Players:GetPlayers() do
				local watch = watches[player]
				if watch == nil then
					watch = {}
					watches[player] = watch
				end
				checkWater(player, watch, now)
				if checkZones then
					local _, root = characterParts(player)
					local island = if root ~= nil then islandAt(root.Position) else nil
					if island ~= nil and island ~= HOME_ISLAND then
						PlayerDataService.recordMilestone(player, "FirstNewIsland")
					end
				end
			end
		end
	end)
end

return IslandService
