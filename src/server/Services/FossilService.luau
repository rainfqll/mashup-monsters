--!strict
-- FossilService: giant fossils that are quicker to dig out together (spec 4.4).
--
-- A fossil is a part tagged "GiantFossil" (its model is the parent, built in Studio). Pressing
-- its "Dig" prompt joins the dig; the server keeps the list of diggers, drops anyone who walks
-- away, and fills a shared progress value the clients draw as a bar ("Progress" attribute).
-- 2+ players fill it fast. A lone digger gets Bolt, a little helper robot, after a few
-- seconds, and the two of them fill it slowly, so solo players are never stuck.
-- Every real digger gets their own server-rolled reward. Then the fossil hides for a while.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fossils = require(ReplicatedStorage.Shared.Config.Fossils)
local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)

local FOSSIL_TAG = "GiantFossil"
local TICK = 0.2

type Fossil = {
	part: BasePart,
	model: Instance,
	prompt: ProximityPrompt,
	diggers: { [Player]: true },
	progress: number,
	aloneSince: number?,
	helper: Model?,
	hidden: boolean,
	savedLooks: { [BasePart]: { transparency: number, collide: boolean } },
}

local fossils: { Fossil } = {}
local random = Random.new()
local noticeRemote: RemoteEvent

local partsByRarity: { [Types.Rarity]: { string } } = {}
for _, definition in Parts.list do
	if not definition.free then
		local list = partsByRarity[definition.rarity] or {}
		table.insert(list, definition.id)
		partsByRarity[definition.rarity] = list
	end
end

local function rollReward(): string
	local total = 0
	for _, entry in Fossils.rewardOdds do
		total += entry.weight
	end
	local pick = random:NextNumber(0, total)
	local rarity = Fossils.rewardOdds[1].rarity
	for _, entry in Fossils.rewardOdds do
		pick -= entry.weight
		if pick <= 0 then
			rarity = entry.rarity
			break
		end
	end
	local candidates = partsByRarity[rarity] or partsByRarity.Rare :: { string }
	return candidates[random:NextInteger(1, #candidates)]
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function isNear(player: Player, fossil: Fossil): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - fossil.part.Position).Magnitude <= Fossils.digRange
end

-- Bolt: a small block-built robot. Built in code because it only exists while helping.
local function buildHelper(fossil: Fossil): Model
	local model = Instance.new("Model")
	model.Name = "Bolt"
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		if shape ~= nil then
			part.Shape = shape
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part:SetAttribute("Offset", offset)
		part.Parent = model
		return part
	end
	local base =
		piece("Body", Vector3.new(2.4, 2.6, 2), CFrame.identity, Color3.fromRGB(120, 170, 230))
	piece(
		"Head",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(0, 2.2, 0),
		Color3.fromRGB(150, 195, 245),
		nil,
		Enum.PartType.Ball
	)
	piece(
		"Eye",
		Vector3.new(1, 0.5, 0.3),
		CFrame.new(0, 2.3, -1.05),
		Color3.fromRGB(150, 240, 60),
		Enum.Material.Neon
	)
	piece("Antenna", Vector3.new(0.2, 1, 0.2), CFrame.new(0, 3.6, 0), Color3.fromRGB(90, 90, 110))
	piece(
		"AntennaTip",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(0, 4.2, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	piece(
		"Wheel",
		Vector3.new(0.6, 1.4, 1.4),
		CFrame.new(0, -1.5, 0),
		Color3.fromRGB(60, 60, 80),
		nil,
		Enum.PartType.Cylinder
	)
	piece(
		"Shovel",
		Vector3.new(0.3, 2.4, 0.3),
		CFrame.new(1.5, 0.2, -0.8) * CFrame.Angles(math.rad(30), 0, 0),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood
	)
	piece(
		"Blade",
		Vector3.new(1, 0.2, 1.1),
		CFrame.new(1.5, -0.9, -1.5),
		Color3.fromRGB(190, 190, 200),
		Enum.Material.Metal
	)
	model.PrimaryPart = base

	-- Next to the fossil, facing it.
	local away = Vector3.new(fossil.part.Size.X / 2 + 3, 0, 0)
	local spot = fossil.part.Position + away
	local ground = spot.Y - fossil.part.Size.Y / 2 + 2.8
	model:SetAttribute(
		"Home",
		CFrame.lookAt(
			Vector3.new(spot.X, ground, spot.Z),
			Vector3.new(fossil.part.Position.X, ground, fossil.part.Position.Z)
		)
	)
	model.Parent = fossil.model
	return model
end

local function placeHelper(helper: Model, now: number): ()
	local home = helper:GetAttribute("Home") :: CFrame
	-- A little digging bob: lean in and out.
	local lean = CFrame.Angles(math.rad(15 * math.sin(now * 8)), 0, 0)
	for _, part in helper:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = home * lean * (part:GetAttribute("Offset") :: CFrame)
		end
	end
end

local function removeHelper(fossil: Fossil): ()
	if fossil.helper ~= nil then
		fossil.helper:Destroy()
		fossil.helper = nil
	end
end

local function setHidden(fossil: Fossil, hidden: boolean): ()
	fossil.hidden = hidden
	fossil.prompt.Enabled = not hidden
	for _, descendant in fossil.model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Parent ~= fossil.helper then
			if hidden then
				fossil.savedLooks[descendant] =
					{ transparency = descendant.Transparency, collide = descendant.CanCollide }
				descendant.Transparency = 1
				descendant.CanCollide = false
			else
				local saved = fossil.savedLooks[descendant]
				if saved ~= nil then
					descendant.Transparency = saved.transparency
					descendant.CanCollide = saved.collide
				end
			end
		end
	end
	if not hidden then
		table.clear(fossil.savedLooks)
	end
	fossil.part:SetAttribute("Available", not hidden)
end

local function finish(fossil: Fossil): ()
	local diggers = {}
	for player in fossil.diggers do
		if player.Parent == Players then
			table.insert(diggers, player)
		end
	end
	local together = #diggers >= 2
	for _, player in diggers do
		local partId = rollReward()
		PlayerDataService.addPart(player, partId, 1)
		PlayerDataService.addCoins(player, Fossils.rewardCoins, "Fossil")
		if together then
			PlayerDataService.recordMilestone(player, "FirstCoopAction")
		end
		local definition = Parts.get(partId)
		noticeRemote:FireClient(
			player,
			`Fossil dug out! You found {if definition ~= nil then definition.displayName else partId}!`
		)
	end
	table.clear(fossil.diggers)
	fossil.progress = 0
	fossil.aloneSince = nil
	removeHelper(fossil)
	fossil.part:SetAttribute("Progress", 0)
	fossil.part:SetAttribute("Diggers", 0)
	fossil.part:SetAttribute("Helper", false)
	setHidden(fossil, true)
	task.delay(Fossils.respawnSeconds, setHidden, fossil, false)
end

local function step(fossil: Fossil, now: number): ()
	if fossil.hidden then
		return
	end
	for player in fossil.diggers do
		if player.Parent ~= Players or not isNear(player, fossil) then
			fossil.diggers[player] = nil
		end
	end
	local count = 0
	for _ in fossil.diggers do
		count += 1
	end

	if count == 0 then
		-- Everyone left: the dig slowly settles back, and Bolt goes home.
		fossil.progress = math.max(0, fossil.progress - TICK / Fossils.soloSeconds)
		fossil.aloneSince = nil
		removeHelper(fossil)
	elseif count == 1 then
		local since = fossil.aloneSince or now
		fossil.aloneSince = since
		if fossil.helper == nil and now - since >= Fossils.helperDelay then
			fossil.helper = buildHelper(fossil)
			for player in fossil.diggers do
				noticeRemote:FireClient(player, "Bolt the lab helper is here to dig with you!")
			end
		end
		if fossil.helper ~= nil then
			fossil.progress += TICK / Fossils.soloSeconds
		end
	else
		-- Friends dig fast; Bolt isn't needed.
		fossil.aloneSince = nil
		removeHelper(fossil)
		fossil.progress += TICK / Fossils.coopSeconds
	end

	if fossil.helper ~= nil then
		placeHelper(fossil.helper, now)
	end
	fossil.part:SetAttribute("Progress", math.min(fossil.progress, 1))
	fossil.part:SetAttribute("Diggers", count)
	fossil.part:SetAttribute("Helper", fossil.helper ~= nil)
	if fossil.progress >= 1 then
		finish(fossil)
	end
end

local function setUp(part: Instance): ()
	if not part:IsA("BasePart") then
		warn(`[Mashup Monsters] {part:GetFullName()} is tagged {FOSSIL_TAG} but is not a part`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DigPrompt"
	prompt.ActionText = "Dig"
	prompt.ObjectText = "Giant Fossil"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	local fossil: Fossil = {
		part = part,
		model = part.Parent or part,
		prompt = prompt,
		diggers = {},
		progress = 0,
		hidden = false,
		savedLooks = {},
	}
	part:SetAttribute("Available", true)
	part:SetAttribute("Progress", 0)
	prompt.Triggered:Connect(function(player)
		if
			not RateLimit.allow(player, "Dig", 0.5)
			or fossil.hidden
			or not isNear(player, fossil)
		then
			return
		end
		fossil.diggers[player] = true
	end)
	table.insert(fossils, fossil)
end

local FossilService = {}

function FossilService.start(): ()
	noticeRemote = Remotes.event("Notice")
	for _, part in CollectionService:GetTagged(FOSSIL_TAG) do
		setUp(part)
	end
	if #fossils == 0 then
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, fossil in fossils do
			fossil.diggers[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, fossil in fossils do
				step(fossil, now)
			end
		end
	end)
end

return FossilService
