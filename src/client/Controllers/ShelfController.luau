--!strict
-- ShelfController: your saved creatures that are not out stand on the lab shelf's pedestals
-- (parts tagged "ShelfPedestal" with an "Order" number), and a sign shows the coins they have
-- earned, counting up live. Display only: the server works out real earnings (ShelfService).
-- Each player sees their own creatures on the shelf.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureAssembler = require(ReplicatedStorage.Shared.CreatureAssembler)
local Types = require(ReplicatedStorage.Shared.Types)
local DataController = require(script.Parent.DataController)
local Theme = require(script.Parent.Parent.UI.Theme)

local SHELF_TAG = "DisplayShelf"
local PEDESTAL_TAG = "ShelfPedestal"
local SIGN_REFRESH = 1

local displayFolder: Folder? = nil
-- What is on display now, so unrelated snapshots (coins, parts) don't rebuild the models.
local shownKey = ""

local function loadoutKey(loadouts: { Types.Loadout }): string
	local parts = {}
	for _, loadout in loadouts do
		table.insert(
			parts,
			`{loadout.Head or "-"}/{loadout.Body or "-"}/{loadout.Legs or "-"}/{loadout.Back or "-"}`
		)
	end
	return table.concat(parts, "|")
end

local function sortedPedestals(): { BasePart }
	local pedestals: { BasePart } = {}
	for _, pedestal in CollectionService:GetTagged(PEDESTAL_TAG) do
		if pedestal:IsA("BasePart") then
			table.insert(pedestals, pedestal)
		end
	end
	table.sort(pedestals, function(a, b)
		return (tonumber(a:GetAttribute("Order")) or 0) < (tonumber(b:GetAttribute("Order")) or 0)
	end)
	return pedestals
end

local function showCreatures(snapshot: Types.PlayerSnapshot): ()
	local resting: { Types.Loadout } = {}
	for index, loadout in snapshot.creatures do
		if index ~= snapshot.activeCreature then
			table.insert(resting, loadout)
		end
	end
	local pedestals = sortedPedestals()
	local key = loadoutKey(resting) .. `#{#pedestals}`
	if key == shownKey then
		return
	end
	shownKey = key

	if displayFolder ~= nil then
		displayFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "ShelfDisplay"
	for index, loadout in resting do
		local pedestal = pedestals[index]
		if pedestal == nil then
			break
		end
		local model = CreatureAssembler.build(loadout)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		local halfHeight = model:GetAttribute("HalfHeight")
		local lift = (if type(halfHeight) == "number" then halfHeight else 3) + pedestal.Size.Y / 2
		model:PivotTo(pedestal.CFrame * CFrame.new(0, lift, 0))
		model.Parent = folder
	end
	folder.Parent = workspace
	displayFolder = folder
end

local function makeSign(shelf: BasePart): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShelfSign"
	billboard.Size = UDim2.fromScale(12, 2.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	Theme.text(label, 30)
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.Parent = billboard
	billboard.Parent = shelf
	return label
end

local ShelfController = {}

function ShelfController.start(): ()
	DataController.onChanged(showCreatures)
	CollectionService:GetInstanceAddedSignal(PEDESTAL_TAG):Connect(function()
		local snapshot = DataController.get()
		if snapshot ~= nil then
			showCreatures(snapshot)
		end
	end)

	task.spawn(function()
		while true do
			local snapshot = DataController.get()
			for _, shelf in CollectionService:GetTagged(SHELF_TAG) do
				if shelf:IsA("BasePart") and snapshot ~= nil then
					local sign = shelf:FindFirstChild("ShelfSign")
					local label = if sign ~= nil
						then sign:FindFirstChildOfClass("TextLabel") :: TextLabel
						else makeSign(shelf)
					-- Same sum the server does, extrapolated from the last snapshot.
					local hours = (os.time() - snapshot.shelfUpdatedAt) / 3600
					local stored = math.min(
						snapshot.shelfStored + snapshot.shelfRate * hours,
						math.max(snapshot.shelfCap, snapshot.shelfStored)
					)
					local coins = math.floor(stored)
					label.Text = if coins >= 1 and coins >= snapshot.shelfCap
						then `Shelf full! {coins} coins`
						elseif coins >= 1 then `{coins} coins ready`
						elseif
							snapshot.shelfRate <= 0
						then "Stitch more creatures to fill your shelf!"
						else "Earning coins..."
				end
			end
			task.wait(SIGN_REFRESH)
		end
	end)
end

return ShelfController
