--!strict
-- ShelfService: the "Collect" prompt on the lab's display shelf (a part tagged "DisplayShelf",
-- built in Studio). Earnings are worked out from the save (PlayerDataService.collectShelf);
-- the creatures standing on the pedestals are drawn by the client (ShelfController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SHELF_TAG = "DisplayShelf"
local MAX_DISTANCE = 16

local ShelfService = {}

function ShelfService.start(): ()
	local noticeRemote = Remotes.event("Notice")

	for _, shelf in CollectionService:GetTagged(SHELF_TAG) do
		if not shelf:IsA("BasePart") then
			warn(`[Mashup Monsters] {shelf:GetFullName()} is tagged {SHELF_TAG} but is not a part`)
			continue
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShelfPrompt"
		prompt.ActionText = "Collect"
		prompt.ObjectText = "Display Shelf"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = shelf
		prompt.Triggered:Connect(function(player)
			if not RateLimit.allow(player, "CollectShelf", 1) then
				return
			end
			local character = player.Character
			local root = if character ~= nil
				then character:FindFirstChild("HumanoidRootPart")
				else nil
			if
				root == nil
				or not root:IsA("BasePart")
				or (root.Position - shelf.Position).Magnitude > MAX_DISTANCE
			then
				return
			end
			local coins = PlayerDataService.collectShelf(player)
			noticeRemote:FireClient(
				player,
				if coins > 0
					then `+{coins} coins from your shelf!`
					else "No coins yet. Creatures on the shelf earn while you play and while you're away!"
			)
		end)
	end
end

return ShelfService
