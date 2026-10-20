--!strict
-- PingController: one-tap pings and emotes so players can co-op without chat.
-- Pings go through the server (SocialService), which shows them to everyone; the marker is a
-- floating sign with the ping and the player's name. Emotes use the default character's own
-- emotes, which Roblox already shows to other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Social = require(ReplicatedStorage.Shared.Config.Social)
local CreatureController = require(script.Parent.CreatureController)
local Theme = require(script.Parent.Parent.UI.Theme)

local LOOK_DISTANCE = 150

local player = Players.LocalPlayer
-- One marker per player: a new ping replaces their old one.
local markers: { [number]: BasePart } = {}
local markerFolder: Folder? = nil

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- "Look!" goes where the camera points (whatever is under the middle of the screen).
local function lookTarget(root: BasePart): Vector3
	local camera = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * LOOK_DISTANCE
	local hit = workspace:Raycast(origin, direction, params)
	local point = if hit ~= nil then hit.Position else origin + direction
	-- Keep it inside the range the server accepts.
	local offset = point - root.Position
	if offset.Magnitude > Social.pingRange - 5 then
		point = root.Position + offset.Unit * (Social.pingRange - 5)
	end
	return point
end

local function showMarker(
	userId: number,
	displayName: string,
	kind: Social.PingKind,
	position: Vector3
): ()
	local info = Social.pings[kind]
	if info == nil then
		return
	end
	local old = markers[userId]
	if old ~= nil then
		old:Destroy()
	end

	local anchor = Instance.new("Part")
	anchor.Name = `Ping_{userId}`
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 74)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 400
	local bubble = Instance.new("TextLabel")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromScale(1, 0.62)
	bubble.Text = info.label
	Theme.text(bubble, 30)
	bubble.BackgroundTransparency = 0
	bubble.BackgroundColor3 = info.color
	Theme.corner(bubble, UDim.new(0.5, 0))
	Theme.outline(bubble, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = bubble
	bubble.Parent = billboard
	local name = Instance.new("TextLabel")
	name.Name = "Who"
	name.Position = UDim2.fromScale(0, 0.64)
	name.Size = UDim2.fromScale(1, 0.36)
	name.Text = if userId == player.UserId then "You" else displayName
	Theme.text(name, 18)
	name.Parent = billboard
	billboard.Parent = anchor

	local folder = markerFolder
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Pings"
		folder.Parent = workspace
		markerFolder = folder
	end
	anchor.Parent = folder
	markers[userId] = anchor
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(Social.pingSeconds, function()
		if markers[userId] == anchor then
			markers[userId] = nil
		end
		anchor:Destroy()
	end)
end

local PingController = {}

function PingController.ping(kind: Social.PingKind): ()
	local root = rootPart()
	if root == nil then
		return
	end
	local position = if kind == "Look" then lookTarget(root) else root.Position
	Remotes.event("Ping"):FireServer(kind, position)
end

-- Emotes need the character's legs free, so they wait until you hop off.
function PingController.emote(emoteId: string): boolean
	if CreatureController.isRiding() then
		return false
	end
	local character = player.Character
	local animate = if character ~= nil then character:FindFirstChild("Animate") else nil
	local playEmote = if animate ~= nil then animate:FindFirstChild("PlayEmote") else nil
	if playEmote == nil or not playEmote:IsA("BindableFunction") then
		return false
	end
	local ok, played = pcall(playEmote.Invoke, playEmote, emoteId)
	return ok and played == true
end

function PingController.start(): ()
	Remotes.event("PingShown").OnClientEvent
		:Connect(
			function(userId: number, displayName: string, kind: Social.PingKind, position: Vector3)
				showMarker(userId, displayName, kind, position)
			end
		)
	Players.PlayerRemoving:Connect(function(leaving)
		local marker = markers[leaving.UserId]
		if marker ~= nil then
			marker:Destroy()
			markers[leaving.UserId] = nil
		end
	end)
end

return PingController
