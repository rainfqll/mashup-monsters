--!strict
-- PortalController: knows whether you own the Portal Pass (PassState from the server) and passes
-- on "you pressed Travel at a portal" (PortalOpened) to the UI. Travelling and buying go through
-- here; the server checks every trip (PortalService) and every purchase (PassService).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local portalPass = false
local openedListeners: { (fromIsland: string) -> () } = {}

local PortalController = {}

function PortalController.hasPortalPass(): boolean
	return portalPass
end

-- Called with the region of the portal you pressed Travel at.
function PortalController.onPortalOpened(listener: (fromIsland: string) -> ()): ()
	table.insert(openedListeners, listener)
end

function PortalController.travel(destination: string): ()
	Remotes.event("PortalTravel"):FireServer(destination)
end

function PortalController.buyPortalPass(): ()
	if Monetization.portalPassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, Monetization.portalPassId)
	end
end

function PortalController.start(): ()
	Remotes.event("PassState").OnClientEvent:Connect(function(owns: unknown)
		portalPass = owns == true
	end)
	Remotes.event("PortalOpened").OnClientEvent:Connect(function(fromIsland: unknown)
		if type(fromIsland) == "string" then
			for _, listener in openedListeners do
				task.spawn(listener, fromIsland)
			end
		end
	end)
end

return PortalController
