--!strict
-- IslandController: notices when you arrive on a different island so the UI can show its name,
-- and labels the travel pads (unlocked, or which ability gets you there).
-- Purely cosmetic; the server records islands and checks every trip itself (IslandService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Config.Islands)
local Types = require(ReplicatedStorage.Shared.Types)
local DataController = require(script.Parent.DataController)
local Theme = require(script.Parent.Parent.UI.Theme)

local ZONE_TAG = "IslandZone"
local PAD_PROMPT_TAG = "TravelPrompt"
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

-- A sign above the pad: island name, and a lock line until you have been there.
local function labelPad(prompt: ProximityPrompt, snapshot: Types.PlayerSnapshot?): ()
	local islandId = prompt:GetAttribute("Island")
	local island = if type(islandId) == "string" then Islands.get(islandId) else nil
	local pad = prompt.Parent
	if island == nil or pad == nil or not pad:IsA("BasePart") then
		return
	end
	local unlocked = island.id == Islands.HOME
		or (snapshot ~= nil and snapshot.unlockedIslands[island.id] == true)

	local sign = pad:FindFirstChild("PadSign")
	if sign == nil then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PadSign"
		-- Sized in studs (not pixels) so neighbouring pads' signs never overlap from afar.
		billboard.Size = UDim2.fromScale(8, 2.8)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		billboard.MaxDistance = 80
		billboard.AlwaysOnTop = false
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.55)
		Theme.text(title, 30)
		title.Parent = billboard
		local lock = Instance.new("TextLabel")
		lock.Name = "Lock"
		lock.Position = UDim2.fromScale(0, 0.55)
		lock.Size = UDim2.fromScale(1, 0.45)
		Theme.text(lock, 22)
		lock.Parent = billboard
		billboard.Parent = pad
		sign = billboard
	end
	local title = (sign :: Instance):FindFirstChild("Title") :: TextLabel
	local lock = (sign :: Instance):FindFirstChild("Lock") :: TextLabel
	title.Text = if island.id == Islands.HOME then "Home" else island.displayName
	lock.Visible = not unlocked
	lock.Text = if island.requires ~= nil
		then `Needs {Islands.abilityName(island.requires)}`
		else ""
	lock.TextColor3 = Color3.fromRGB(255, 200, 80)
	prompt.ActionText = if unlocked
		then (if island.id == Islands.HOME then "Go home" else "Travel")
		else "Locked"
end

local function labelAllPads(): ()
	local snapshot = DataController.get()
	for _, prompt in CollectionService:GetTagged(PAD_PROMPT_TAG) do
		if prompt:IsA("ProximityPrompt") then
			labelPad(prompt, snapshot)
		end
	end
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
	DataController.onChanged(labelAllPads)
	CollectionService:GetInstanceAddedSignal(PAD_PROMPT_TAG):Connect(labelAllPads)
	labelAllPads()

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
