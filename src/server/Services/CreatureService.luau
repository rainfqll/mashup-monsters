--!strict
-- CreatureService: puts each player's active creature in the world and handles riding.
--
-- Following: the server gives the player network ownership of their creature, and the
-- client steers it with the AlignPosition/AlignOrientation created here. That keeps movement
-- smooth on phones without the server sending positions every frame.
-- Riding: the server welds the creature under the player's character, raises the character's
-- HipHeight so the creature's feet touch the ground, and sets walk speed and jump power from
-- the creature's parts. Glide and swim are handled by the client (CreatureController), which
-- reads the creature's "Abilities" attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CreatureAssembler = require(ReplicatedStorage.Shared.CreatureAssembler)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

-- Where a freshly spawned creature appears, relative to the character (right side, behind).
local SPAWN_OFFSET = CFrame.new(5, 0, 4)

type HumanoidDefaults = {
	hipHeight: number,
	walkSpeed: number,
	jumpPower: number,
	useJumpPower: boolean,
}

type State = {
	model: Model?,
	summary: Types.CreatureSummary?,
	riding: boolean,
	weld: Weld?,
	defaults: HumanoidDefaults?,
	characterConnections: { RBXScriptConnection },
}

local states: { [Player]: State } = {}
local folder: Folder

local function stateFor(player: Player): State
	local state = states[player]
	if state == nil then
		state = { riding = false, characterConnections = {} }
		states[player] = state
	end
	return state
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

local function groundBelow(position: Vector3, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), params)
	return if hit ~= nil then hit.Position.Y else nil
end

local function abilityList(summary: Types.CreatureSummary): string
	local list = {}
	for ability in summary.abilities do
		table.insert(list, ability)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function addLights(model: Model, summary: Types.CreatureSummary): ()
	local hitbox = model.PrimaryPart :: BasePart
	local tuning = if summary.abilities.Light
		then Abilities.light
		elseif summary.abilities.Glow then Abilities.glow
		else nil
	if tuning ~= nil then
		local light = Instance.new("PointLight")
		light.Brightness = tuning.brightness
		light.Range = tuning.range
		light.Color = tuning.color
		light.Shadows = false
		light.Parent = hitbox
	end
end

local function rideNumbers(summary: Types.CreatureSummary): (number, number)
	local tuning = Abilities.ride
	local walkSpeed = tuning.walkSpeed + tuning.walkSpeedPerSpeedStat * summary.stats.speed
	if summary.abilities.Speed then
		walkSpeed += tuning.speedAbilityBonus
	end
	local jumpPower = tuning.jumpPower + tuning.jumpPowerPerJumpStat * summary.stats.jump
	if summary.abilities.SuperJump then
		jumpPower += tuning.superJumpBonus
	end
	return walkSpeed, jumpPower
end

local function setFollowing(model: Model, enabled: boolean): ()
	local hitbox = model.PrimaryPart :: BasePart
	for _, child in hitbox:GetChildren() do
		if child:IsA("AlignPosition") or child:IsA("AlignOrientation") then
			child.Enabled = enabled
		end
	end
end

local function giveOwnership(model: Model, player: Player): ()
	local hitbox = model.PrimaryPart :: BasePart
	-- Fails if the part is anchored or not in the workspace yet; neither should happen here,
	-- but a failure only means the server simulates it instead, so never let it error.
	pcall(hitbox.SetNetworkOwner, hitbox, player)
end

local function dismount(player: Player): ()
	local state = stateFor(player)
	if not state.riding then
		return
	end
	state.riding = false

	if state.weld ~= nil then
		state.weld:Destroy()
		state.weld = nil
	end

	local humanoid, root = characterParts(player)
	local defaults = state.defaults
	if humanoid ~= nil and defaults ~= nil then
		humanoid.HipHeight = defaults.hipHeight
		humanoid.WalkSpeed = defaults.walkSpeed
		humanoid.JumpPower = defaults.jumpPower
		humanoid.UseJumpPower = defaults.useJumpPower
	end
	state.defaults = nil
	if player.Character ~= nil then
		player.Character:SetAttribute("RidingCreature", nil)
	end

	local model = state.model
	if model ~= nil then
		local hitbox = model.PrimaryPart :: BasePart
		hitbox.Massless = false
		model:SetAttribute("Riding", false)
		if root ~= nil then
			local halfHeight = model:GetAttribute("HalfHeight") :: number
			local besideCFrame = root.CFrame * SPAWN_OFFSET
			local groundY = groundBelow(besideCFrame.Position, { model, player.Character :: Model })
			local y = if groundY ~= nil then groundY + halfHeight else besideCFrame.Y
			model:PivotTo(CFrame.new(besideCFrame.X, y, besideCFrame.Z) * root.CFrame.Rotation)
		end
		setFollowing(model, true)
		giveOwnership(model, player)
	end
end

local function mount(player: Player): ()
	local state = stateFor(player)
	local model = state.model
	local summary = state.summary
	local humanoid, root = characterParts(player)
	if state.riding or model == nil or summary == nil or humanoid == nil or root == nil then
		return
	end
	local hitbox = model.PrimaryPart :: BasePart
	if (hitbox.Position - root.Position).Magnitude > Abilities.ride.mountDistance then
		return
	end

	local seatOffset = model:GetAttribute("SeatOffset") :: Vector3
	local halfHeight = model:GetAttribute("HalfHeight") :: number
	local rootHalf = root.Size.Y / 2

	state.defaults = {
		hipHeight = humanoid.HipHeight,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		useJumpPower = humanoid.UseJumpPower,
	}

	setFollowing(model, false)
	-- Massless so the creature's weight doesn't make the character sluggish.
	hitbox.Massless = true

	-- The bottom of the root part sits on the creature's seat.
	local weld = Instance.new("Weld")
	weld.Name = "RideWeld"
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.C0 = CFrame.new(-seatOffset - Vector3.new(0, rootHalf, 0))
	weld.Parent = hitbox
	state.weld = weld

	-- Lift the character so the creature's feet, not the character's, touch the ground.
	humanoid.HipHeight = seatOffset.Y + halfHeight
	local walkSpeed, jumpPower = rideNumbers(summary)
	humanoid.WalkSpeed = walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jumpPower

	state.riding = true
	model:SetAttribute("Riding", true)
	player.Character:SetAttribute("RidingCreature", true)
	PlayerDataService.recordMilestone(player, "FirstRide")
end

local function despawn(player: Player): ()
	dismount(player)
	local state = stateFor(player)
	if state.model ~= nil then
		state.model:Destroy()
		state.model = nil
	end
	state.summary = nil
end

local function spawnCreature(player: Player, loadout: Types.Loadout): ()
	local _, root = characterParts(player)
	if root == nil then
		return
	end
	local state = stateFor(player)
	local summary = Creatures.summarize(loadout)
	local model = CreatureAssembler.build(loadout)
	model.Name = `{player.Name}_Creature`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CreatureName", summary.name)
	model:SetAttribute("Abilities", abilityList(summary))
	model:SetAttribute("GlideStat", summary.stats.glide)
	model:SetAttribute("Riding", false)
	addLights(model, summary)

	local hitbox = model.PrimaryPart :: BasePart
	local followAttachment = Instance.new("Attachment")
	followAttachment.Name = "FollowAttachment"
	followAttachment.Parent = hitbox

	-- The client sets Position / CFrame on these every frame; the server only creates them.
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = followAttachment
	alignPosition.MaxForce = 1e6
	alignPosition.MaxVelocity = 60
	alignPosition.Responsiveness = 25
	alignPosition.Position = hitbox.Position
	alignPosition.Parent = hitbox

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = followAttachment
	alignOrientation.MaxTorque = 1e6
	alignOrientation.Responsiveness = 20
	alignOrientation.Parent = hitbox

	local halfHeight = model:GetAttribute("HalfHeight") :: number
	local spawnCFrame = root.CFrame * SPAWN_OFFSET
	local groundY = groundBelow(spawnCFrame.Position, { model, player.Character :: Model })
	local y = if groundY ~= nil then groundY + halfHeight else spawnCFrame.Y
	model:PivotTo(CFrame.new(spawnCFrame.X, y, spawnCFrame.Z) * root.CFrame.Rotation)
	alignPosition.Position = hitbox.Position
	alignOrientation.CFrame = hitbox.CFrame

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	model.Parent = folder
	giveOwnership(model, player)

	state.model = model
	state.summary = summary
end

-- Makes the world match the save: the active creature is out (fresh model), or nothing is.
local function refresh(player: Player): ()
	if player.Parent ~= Players then
		return
	end
	despawn(player)
	local loadout = PlayerDataService.getActiveLoadout(player)
	if loadout ~= nil then
		spawnCreature(player, loadout)
	end
end

local function onCharacterAdded(player: Player, character: Model): ()
	local state = stateFor(player)
	for _, connection in state.characterConnections do
		connection:Disconnect()
	end
	table.clear(state.characterConnections)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	table.insert(
		state.characterConnections,
		humanoid.Died:Connect(function()
			-- The weld breaks with the old character; forget the ride so the next one is clean.
			dismount(player)
		end)
	)
	-- Wait for the root part so the creature spawns beside the character, not at the origin.
	character:WaitForChild("HumanoidRootPart", 10)
	refresh(player)
end

local function onPlayerAdded(player: Player): ()
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character ~= nil then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local CreatureService = {}

-- True while the player rides a creature that can swim (water gates check this).
function CreatureService.canSwim(player: Player): boolean
	local state = states[player]
	return state ~= nil
		and state.riding
		and state.summary ~= nil
		and (state.summary :: Types.CreatureSummary).abilities.Swim == true
end

function CreatureService.start(): ()
	folder = Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = workspace

	PlayerDataService.onActiveCreatureChanged(refresh)

	Remotes.event("ToggleRide").OnServerEvent:Connect(function(player: Player)
		if not RateLimit.allow(player, "ToggleRide", 0.4) then
			return
		end
		if stateFor(player).riding then
			dismount(player)
		else
			mount(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state ~= nil then
			for _, connection in state.characterConnections do
				connection:Disconnect()
			end
			if state.model ~= nil then
				state.model:Destroy()
			end
		end
		states[player] = nil
	end)
end

return CreatureService
