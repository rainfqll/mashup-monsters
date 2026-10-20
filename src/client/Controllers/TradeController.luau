--!strict
-- TradeController: puts a "Trade" prompt over friends' characters (only you see it) and
-- passes trade messages between the server and the trade screens. The server decides who may
-- trade; this only offers the button where it makes sense.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Trading = require(ReplicatedStorage.Shared.Config.Trading)
local Types = require(ReplicatedStorage.Shared.Types)

local player = Players.LocalPlayer
local friendCache: { [number]: boolean } = {}

type StateListener = (view: Types.TradeView?) -> ()
type InviteListener = (fromUserId: number, fromName: string) -> ()
local stateListeners: { StateListener } = {}
local inviteListeners: { InviteListener } = {}

local function isFriend(other: Player): boolean
	if RunService:IsStudio() and Trading.studioAllowsAnyone then
		return true
	end
	local cached = friendCache[other.UserId]
	if cached == nil then
		local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
		cached = ok and result == true
		friendCache[other.UserId] = cached
	end
	return cached :: boolean
end

local function addPrompt(other: Player, character: Model): ()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not isFriend(other) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = other.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		Remotes.event("TradeRequest"):FireServer(other.UserId)
	end)
	prompt.Parent = root
end

local function watch(other: Player): ()
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		addPrompt(other, character)
	end)
	if other.Character ~= nil then
		task.spawn(addPrompt, other, other.Character)
	end
end

local TradeController = {}

function TradeController.onStateChanged(listener: StateListener): ()
	table.insert(stateListeners, listener)
end

function TradeController.onInvite(listener: InviteListener): ()
	table.insert(inviteListeners, listener)
end

function TradeController.respond(fromUserId: number, accept: boolean): ()
	Remotes.event("TradeRespond"):FireServer(fromUserId, accept)
end

function TradeController.start(): ()
	Remotes.event("TradeState").OnClientEvent:Connect(function(view: Types.TradeView?)
		for _, listener in stateListeners do
			task.spawn(listener, view)
		end
	end)
	Remotes.event("TradeInvite").OnClientEvent
		:Connect(function(fromUserId: number, fromName: string)
			for _, listener in inviteListeners do
				task.spawn(listener, fromUserId, fromName)
			end
		end)
	Players.PlayerAdded:Connect(watch)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerRemoving:Connect(function(other)
		friendCache[other.UserId] = nil
	end)
end

return TradeController
