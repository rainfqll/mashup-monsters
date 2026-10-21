--!strict
-- The bundle "hatching" reveal: a 3D egg pops in, wobbles harder and harder while it takes on
-- the part's rarity color, its top bursts off in a shower of sparkles, and the part card
-- appears. Deliberately an egg, not reels or a wheel: the spec rules out anything that looks
-- like gambling. The part was already rolled and saved by the server; this is only the show.
-- The egg art is ReplicatedStorage.Art.Egg (a Top and a Bottom MeshPart, centered on the
-- origin); without it a plain white ball stands in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

local SPARKLE_COUNT = 14
-- Taps before this are ignored, so a kid mashing the screen still sees the part.
local MIN_SHOW_SECONDS = 0.8
local EGG_FIELD_OF_VIEW = 30
-- Where the egg is seen from: its best-looking side, a little above.
local EGG_VIEW_DIRECTION = Vector3.new(-0.8, 0.15, 0.6).Unit
-- The egg rocks around a point near its bottom, like an egg on a table.
local EGG_ROCK_HEIGHT = 1.8

export type RevealOverlay = {
	play: (definition: Types.PartDefinition, isNew: boolean, onDone: () -> ()) -> (),
}

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local created = TweenService:Create(instance, info, goal)
	created:Play()
	return created
end

local function circle(parent: GuiObject, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Runs `step(alpha)` every frame for `seconds`, with alpha going 0 -> 1, then returns.
local function animate(seconds: number, step: (alpha: number) -> ()): ()
	local started = os.clock()
	while true do
		local alpha = math.min((os.clock() - started) / seconds, 1)
		step(alpha)
		if alpha >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function buildEgg(): Model
	local art = ReplicatedStorage:FindFirstChild("Art")
	local template = if art ~= nil then art:FindFirstChild("Egg") else nil
	if template ~= nil and template:IsA("Model") then
		return template:Clone()
	end
	warn("[Mashup Monsters] ReplicatedStorage.Art.Egg is missing; using a plain egg")
	local model = Instance.new("Model")
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(3, 3.8, 3)
	top.Color = Color3.fromRGB(255, 245, 225)
	top.Parent = model
	model.PrimaryPart = top
	return model
end

-- Tints the egg art toward a color (white = its own colors; the plain fallback egg stays white).
local function tintEgg(egg: Model, color: Color3): ()
	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") then
			descendant.Color = color
		end
	end
end

local RevealOverlay = {}

function RevealOverlay.create(parent: ScreenGui): RevealOverlay
	local playing = false

	-- Its own ScreenGui without safe-area insets, so the dimming covers the whole screen,
	-- including the strip behind the Roblox top bar.
	local screen = Instance.new("ScreenGui")
	screen.Name = "MashupReveal"
	screen.ResetOnSpawn = false
	screen.ScreenInsets = Enum.ScreenInsets.None
	screen.ZIndexBehavior = parent.ZIndexBehavior
	screen.DisplayOrder = parent.DisplayOrder + 10
	screen.Parent = parent.Parent

	-- Full-screen catcher: dims the game and takes the "tap to continue" tap.
	local root = Instance.new("TextButton")
	root.Name = "Reveal"
	root.Size = UDim2.fromScale(1, 1)
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundColor3 = Color3.fromRGB(20, 10, 35)
	root.BackgroundTransparency = 0.3
	root.ZIndex = 50
	root.Visible = false
	root.Parent = screen

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.48)
	stage.Size = UDim2.fromScale(0.5, 0.5)
	stage.SizeConstraint = Enum.SizeConstraint.RelativeYY
	stage.BackgroundTransparency = 1
	stage.ZIndex = 51
	stage.Parent = root

	local glow = circle(stage, Color3.new(1, 1, 1))
	glow.Name = "Glow"
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.ZIndex = 51

	local eggView = Instance.new("ViewportFrame")
	eggView.Name = "Egg"
	eggView.AnchorPoint = Vector2.new(0.5, 0.5)
	eggView.Position = UDim2.fromScale(0.5, 0.5)
	eggView.Size = UDim2.fromScale(1, 1)
	eggView.BackgroundTransparency = 1
	eggView.Ambient = Color3.fromRGB(200, 190, 215)
	eggView.LightColor = Color3.new(1, 1, 1)
	eggView.LightDirection = Vector3.new(-1, -1.5, 1)
	eggView.ZIndex = 52
	local eggScale = Instance.new("UIScale")
	eggScale.Parent = eggView
	eggView.Parent = stage
	local eggCamera = Instance.new("Camera")
	eggCamera.FieldOfView = EGG_FIELD_OF_VIEW
	eggCamera.CFrame = CFrame.lookAt(EGG_VIEW_DIRECTION * 7.5, Vector3.zero)
	eggCamera.Parent = eggView
	eggView.CurrentCamera = eggCamera
	-- Rocking around the camera's line of sight reads as "side to side" on screen.
	local rockAxis = -EGG_VIEW_DIRECTION
	local rockPivot = CFrame.new(0, -EGG_ROCK_HEIGHT, 0)
	local egg: Model? = nil

	local function rock(model: Model, angle: number): ()
		model:PivotTo(
			rockPivot * CFrame.fromAxisAngle(rockAxis, math.rad(angle)) * rockPivot:Inverse()
		)
	end

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 1)
	headline.Position = UDim2.fromScale(0.5, 0.0)
	headline.Size = UDim2.fromScale(1.6, 0.2)
	Theme.text(headline, 48)
	headline.ZIndex = 55
	headline.Parent = stage

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 1.02)
	hint.Size = UDim2.fromScale(1.4, 0.12)
	hint.Text = "Tap to continue"
	Theme.text(hint, 26)
	hint.TextColor3 = Theme.colors.textDim
	hint.ZIndex = 55
	hint.Parent = stage

	local cardHolder = Instance.new("Frame")
	cardHolder.Name = "CardHolder"
	cardHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	cardHolder.Position = UDim2.fromScale(0.5, 0.5)
	cardHolder.Size = UDim2.fromScale(0.62, 0.62 * PartCard.ASPECT)
	cardHolder.BackgroundTransparency = 1
	cardHolder.ZIndex = 54
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = cardHolder
	cardHolder.Parent = stage

	local onFinished: (() -> ())? = nil
	local tappableAt = math.huge

	root.Activated:Connect(function()
		if not playing or os.clock() < tappableAt then
			return
		end
		playing = false
		root.Visible = false
		local done = onFinished
		onFinished = nil
		if done ~= nil then
			done()
		end
	end)

	local function play(definition: Types.PartDefinition, isNew: boolean, onDone: () -> ()): ()
		if playing then
			return
		end
		playing = true
		onFinished = onDone
		tappableAt = math.huge
		local color = Rarities[definition.rarity].color

		for _, child in cardHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		headline.Text = ""
		hint.Visible = false
		if egg ~= nil then
			egg:Destroy()
		end
		local newEgg = buildEgg()
		newEgg:PivotTo(CFrame.identity)
		newEgg.Parent = eggView
		egg = newEgg
		eggView.Visible = true
		eggView.ImageTransparency = 0
		eggScale.Scale = 0
		glow.Size = UDim2.fromScale(0, 0)
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 0.5
		cardScale.Scale = 0
		root.Visible = true

		task.spawn(function()
			tween(eggScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.45)

			-- Wobbles grow stronger and the glow swells: anticipation, not a spin. Halfway
			-- through, the shell starts to shine in the rarity color.
			for round = 1, 3 do
				local angle = 8 + round * 6
				animate(0.28, function(alpha)
					rock(newEgg, angle * math.sin(alpha * math.pi * 2))
				end)
				tween(glow, 0.2, { Size = UDim2.fromScale(0.5 + round * 0.25, 0.5 + round * 0.25) })
				if round >= 2 then
					tintEgg(newEgg, Color3.new(1, 1, 1):Lerp(color, round * 0.3))
				end
				task.wait(0.22)
			end

			-- Burst: the top of the shell flies off, the rest fades, sparkles fly out.
			local top = newEgg:FindFirstChild("Top")
			local topStart = if top ~= nil and top:IsA("BasePart") then top.CFrame else nil
			tween(eggScale, 0.18, { Scale = 1.15 })
			tween(glow, 0.5, { Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 })
			task.spawn(animate, 0.3, function(alpha)
				if top ~= nil and top:IsA("BasePart") and topStart ~= nil then
					top.CFrame = CFrame.new(0, alpha * 5, 0)
						* topStart
						* CFrame.fromAxisAngle(rockAxis, alpha * 1.2)
				end
				eggView.ImageTransparency = alpha * alpha
			end)
			for index = 1, SPARKLE_COUNT do
				local sparkle = circle(stage, color)
				sparkle.Position = UDim2.fromScale(0.5, 0.5)
				sparkle.Size = UDim2.fromScale(0.08, 0.08)
				sparkle.ZIndex = 56
				local angle = (index / SPARKLE_COUNT) * math.pi * 2
				local distance = 0.55 + math.random() * 0.25
				local goal = UDim2.fromScale(
					0.5 + math.cos(angle) * distance,
					0.5 + math.sin(angle) * distance
				)
				tween(sparkle, 0.6, { Position = goal, BackgroundTransparency = 1 })
				task.delay(0.65, sparkle.Destroy, sparkle)
			end
			task.wait(0.3)
			eggView.Visible = false

			local card = PartCard.create(definition)
			card.Size = UDim2.fromScale(1, 1)
			card.ZIndex = 54
			for _, descendant in card:GetDescendants() do
				if descendant:IsA("GuiObject") then
					descendant.ZIndex = 55
				end
			end
			card.Parent = cardHolder
			tween(cardScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			headline.Text = if isNew then `NEW! {definition.rarity}!` else `{definition.rarity}!`
			headline.TextColor3 = color

			tappableAt = os.clock() + MIN_SHOW_SECONDS
			task.wait(MIN_SHOW_SECONDS)
			if playing then
				hint.Visible = true
			end
		end)
	end

	return { play = play }
end

return RevealOverlay
