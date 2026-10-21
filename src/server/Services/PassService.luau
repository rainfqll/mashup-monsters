--!strict
-- PassService: who owns which game pass (Config/Monetization). The server asks Roblox once per
-- player on join (with retries; a failed check counts as "not owned" until it works) and again
-- when a purchase in the game finishes, then tells that player's client (PassState). Other
-- services ask PassService, never the client.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RETRIES = 3

local portalPass: { [Player]: boolean } = {}
local stateRemote: RemoteEvent

local function checkPortalPass(player: Player): boolean
	if RunService:IsStudio() and ServerStorage:GetAttribute("DevPortalPass") == true then
		return true
	end
	if Monetization.portalPassId == 0 then
		return false
	end
	for attempt = 1, RETRIES do
		local ok, owns = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			Monetization.portalPassId
		)
		if ok then
			return owns == true
		end
		task.wait(attempt * 2)
	end
	return false
end

local function refresh(player: Player): ()
	local owns = checkPortalPass(player)
	if player.Parent ~= Players then
		return
	end
	portalPass[player] = owns
	stateRemote:FireClient(player, owns)
end

local PassService = {}

function PassService.ownsPortalPass(player: Player): boolean
	return portalPass[player] == true
end

function PassService.start(): ()
	stateRemote = Remotes.event("PassState")

	Players.PlayerAdded:Connect(refresh)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		portalPass[player] = nil
	end)
	-- A purchase in the game counts right away (Roblox already took the Robux).
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Monetization.portalPassId then
			portalPass[player] = true
			stateRemote:FireClient(player, true)
		end
	end)
	-- The client asks again once it is listening, so the first answer is never missed.
	Remotes.event("ClientReady").OnServerEvent:Connect(function(player)
		if portalPass[player] ~= nil then
			stateRemote:FireClient(player, portalPass[player])
		end
	end)
end

return PassService
