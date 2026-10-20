--!strict
-- CreatureController: the local side of your creature.
--   * Steers it to follow you (the server gave us network ownership of it).
--   * While riding: plays the sit pose, applies glide, and decides whether you may swim.
-- The server owns everything that matters (which creature, riding on/off, speeds); this only
-- adds feel. Glide and swim run here because character movement is simulated on the client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Water = require(ReplicatedStorage.Shared.Water)

local player = Players.LocalPlayer

-- Where the creature walks relative to you while following (right side, a bit behind).
local FOLLOW_OFFSET = Vector3.new(4.5, 0, 4)
-- Beyond this distance it teleports back instead of running (e.g. after you respawn).
local TELEPORT_DISTANCE = 80

type StateListener = () -> ()
type MessageListener = (string) -> ()

local creature: Model? = nil
local stateListeners: { StateListener } = {}
local messageListeners: { MessageListener } = {}
local sitTrack: AnimationTrack? = nil
local lastSafeCFrame: CFrame? = nil
local WATER_CHECK_INTERVAL = 0.1
-- Invisible box parts in Windy Canyons; gliding inside one lifts you (gliding alone only slows a fall).
local UPDRAFT_TAG = "Updraft"
local nextWaterCheck = 0

local function notifyState(): ()
	for _, listener in stateListeners do
		task.spawn(listener)
	end
end

-- The same message at most every few seconds, so a repeating situation doesn't spam the screen.
local MESSAGE_COOLDOWN = 3
local lastMessage = ""
local lastMessageAt = -math.huge

local function say(message: string): ()
	local now = os.clock()
	if message == lastMessage and now - lastMessageAt < MESSAGE_COOLDOWN then
		return
	end
	lastMessage = message
	lastMessageAt = now
	for _, listener in messageListeners do
		task.spawn(listener, message)
	end
end

local function isOwnCreature(instance: Instance): boolean
	return instance:IsA("Model") and instance:GetAttribute("OwnerUserId") == player.UserId
end

local function hasAbility(model: Model, ability: string): boolean
	local list = model:GetAttribute("Abilities")
	return type(list) == "string" and table.find(string.split(list, ","), ability) ~= nil
end

local function isRiding(): boolean
	return creature ~= nil and creature:GetAttribute("Riding") == true
end

local function characterParts(): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

-- Uses the character's own sit animation (from Roblox's Animate script), so it matches the
-- avatar type without us shipping an animation asset.
local function setSitting(sitting: boolean): ()
	if sitTrack ~= nil then
		sitTrack:Stop(0.15)
		sitTrack = nil
	end
	if not sitting then
		return
	end
	local humanoid = characterParts()
	local character = player.Character
	if humanoid == nil or character == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animate = character:FindFirstChild("Animate")
	local sitFolder = if animate ~= nil then animate:FindFirstChild("sit") else nil
	local animation = if sitFolder ~= nil then sitFolder:FindFirstChildOfClass("Animation") else nil
	if animator == nil or animation == nil then
		return
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15)
	sitTrack = track
end

local function track(model: Model): ()
	creature = model
	model:GetAttributeChangedSignal("Riding"):Connect(function()
		if creature == model then
			setSitting(isRiding())
			notifyState()
		end
	end)
	setSitting(isRiding())
	notifyState()
end

local function untrack(model: Instance): ()
	if creature == model then
		creature = nil
		setSitting(false)
		notifyState()
	end
end

local followParams = RaycastParams.new()
followParams.FilterType = Enum.RaycastFilterType.Exclude

local function follow(model: Model, root: BasePart): ()
	local hitbox = model.PrimaryPart
	if hitbox == nil then
		return
	end
	local alignPosition = hitbox:FindFirstChildOfClass("AlignPosition")
	local alignOrientation = hitbox:FindFirstChildOfClass("AlignOrientation")
	if alignPosition == nil or alignOrientation == nil then
		return
	end
	local halfHeight = model:GetAttribute("HalfHeight")
	if type(halfHeight) ~= "number" then
		return
	end

	local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatLook.Magnitude < 0.01 then
		return
	end
	local facing = CFrame.lookAt(root.Position, root.Position + flatLook)
	local target = facing:PointToWorldSpace(FOLLOW_OFFSET)

	followParams.FilterDescendantsInstances = { model, player.Character :: Model }
	local hit =
		workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), followParams)
	local y = if hit ~= nil then hit.Position.Y + halfHeight else root.Position.Y
	local goal = Vector3.new(target.X, y, target.Z)

	if (hitbox.Position - goal).Magnitude > TELEPORT_DISTANCE then
		model:PivotTo(CFrame.new(goal) * facing.Rotation)
	end
	alignPosition.Position = goal
	alignOrientation.CFrame = facing.Rotation
end

local function inUpdraft(position: Vector3): boolean
	for _, updraft in CollectionService:GetTagged(UPDRAFT_TAG) do
		if updraft:IsA("BasePart") then
			local localPoint = updraft.CFrame:PointToObjectSpace(position)
			local half = updraft.Size / 2
			if
				math.abs(localPoint.X) <= half.X
				and math.abs(localPoint.Y) <= half.Y
				and math.abs(localPoint.Z) <= half.Z
			then
				return true
			end
		end
	end
	return false
end

local function glide(model: Model, humanoid: Humanoid, root: BasePart): ()
	if not hasAbility(model, "Glide") or humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end
	local tuning = Abilities.glide
	if inUpdraft(root.Position) then
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y < tuning.updraftSpeed then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, tuning.updraftSpeed, velocity.Z)
		end
		return
	end
	local glideStat = model:GetAttribute("GlideStat")
	local bonus = if type(glideStat) == "number"
		then glideStat * tuning.fallSpeedPerGlideStat
		else 0
	local maxFall = math.max(tuning.minFallSpeed, tuning.maxFallSpeed - bonus)
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y < -maxFall then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, -maxFall, velocity.Z)
	end
end

-- Water is how islands are gated, so swimming needs a creature with Swim. Without it, you are
-- gently put back where you last stood on dry ground.
local function checkWater(humanoid: Humanoid, root: BasePart): ()
	local inWater = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or Water.isWaterAt(Water.feetPosition(humanoid, root))
	if inWater then
		local canSwim = creature ~= nil and isRiding() and hasAbility(creature, "Swim")
		if not canSwim and lastSafeCFrame ~= nil then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = lastSafeCFrame
			humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			say("You need a swimmer to go in the water!")
		end
		return
	end
	local floor = humanoid.FloorMaterial
	if
		floor ~= Enum.Material.Air
		and floor ~= Enum.Material.Water
		and not Water.isWaterAt(root.Position)
	then
		lastSafeCFrame = root.CFrame
	end
end

local CreatureController = {}

function CreatureController.hasCreature(): boolean
	return creature ~= nil
end

function CreatureController.isRiding(): boolean
	return isRiding()
end

-- Your creature's model in the world, or nil if none is out.
function CreatureController.getCreature(): Model?
	return creature
end

-- True if your creature that is out has `ability` (e.g. "Swim").
function CreatureController.creatureHas(ability: string): boolean
	return creature ~= nil and hasAbility(creature, ability)
end

function CreatureController.toggleRide(): ()
	if creature ~= nil then
		Remotes.event("ToggleRide"):FireServer()
	end
end

-- Called whenever you gain/lose a creature or hop on/off.
function CreatureController.onStateChanged(listener: StateListener): ()
	table.insert(stateListeners, listener)
end

-- Short messages for the player (e.g. why they were pulled out of the water).
function CreatureController.onMessage(listener: MessageListener): ()
	table.insert(messageListeners, listener)
end

function CreatureController.start(): ()
	local folder = workspace:WaitForChild("Creatures", 15)
	if folder == nil then
		error("workspace.Creatures did not appear (CreatureService creates it at server start)")
	end
	folder.ChildAdded:Connect(function(child)
		if isOwnCreature(child) then
			track(child :: Model)
		end
	end)
	folder.ChildRemoved:Connect(untrack)
	for _, child in folder:GetChildren() do
		if isOwnCreature(child) then
			track(child :: Model)
		end
	end

	player.CharacterAdded:Connect(function()
		lastSafeCFrame = nil
		sitTrack = nil
	end)

	RunService.Heartbeat:Connect(function()
		local humanoid, root = characterParts()
		if humanoid == nil or root == nil or humanoid.Health <= 0 then
			return
		end
		local model = creature
		if model ~= nil then
			if isRiding() then
				glide(model, humanoid, root)
			else
				follow(model, root)
			end
		end
		-- Ten checks a second is plenty to catch someone stepping into water.
		local now = os.clock()
		if now >= nextWaterCheck then
			nextWaterCheck = now + WATER_CHECK_INTERVAL
			checkWater(humanoid, root)
		end
	end)
end

return CreatureController
