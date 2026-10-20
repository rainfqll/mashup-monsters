--!strict
-- The bundle "hatching" reveal: an egg pops in, wobbles harder and harder while glowing in the
-- part's rarity color, bursts into sparkles, and the part card appears. Deliberately an egg,
-- not reels or a wheel: the spec rules out anything that looks like gambling.
-- The part was already rolled and saved by the server; this is only the show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local PartCard = require(script.Parent.PartCard)
local Theme = require(script.Parent.Theme)

local SPARKLE_COUNT = 14
-- Taps before this are ignored, so a kid mashing the screen still sees the part.
local MIN_SHOW_SECONDS = 0.8

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

	local egg = Instance.new("Frame")
	egg.Name = "Egg"
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.fromScale(0.5, 0.5)
	egg.Size = UDim2.fromScale(0.62, 0.8)
	egg.BackgroundColor3 = Color3.fromRGB(255, 245, 225)
	egg.ZIndex = 52
	Theme.corner(egg, UDim.new(0.5, 0))
	local eggStroke = Theme.outline(egg, 6)
	local eggScale = Instance.new("UIScale")
	eggScale.Parent = egg
	egg.Parent = stage
	for _, spot in { { 0.3, 0.3, 0.2 }, { 0.68, 0.45, 0.16 }, { 0.42, 0.7, 0.22 } } do
		local dot = circle(egg, Theme.colors.purple)
		dot.Position = UDim2.fromScale(spot[1], spot[2])
		dot.Size = UDim2.fromScale(spot[3], spot[3] * 0.78)
		dot.ZIndex = 53
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
		egg.Visible = true
		egg.Rotation = 0
		egg.BackgroundTransparency = 0
		eggStroke.Color = Theme.colors.outline
		eggStroke.Transparency = 0
		eggScale.Scale = 0
		glow.Size = UDim2.fromScale(0, 0)
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 0.5
		cardScale.Scale = 0
		root.Visible = true

		task.spawn(function()
			tween(eggScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.45)

			-- Wobbles grow stronger and the glow swells: anticipation, not a spin.
			for round = 1, 3 do
				local angle = 8 + round * 6
				tween(egg, 0.08, { Rotation = -angle }).Completed:Wait()
				tween(egg, 0.12, { Rotation = angle }).Completed:Wait()
				tween(egg, 0.08, { Rotation = 0 }).Completed:Wait()
				tween(glow, 0.2, { Size = UDim2.fromScale(0.5 + round * 0.25, 0.5 + round * 0.25) })
				if round == 2 then
					eggStroke.Color = color
				end
				task.wait(0.22)
			end

			-- Burst: the egg pops and sparkles fly out in the rarity color.
			tween(eggScale, 0.18, { Scale = 1.35 })
			tween(egg, 0.18, { BackgroundTransparency = 1 })
			tween(eggStroke, 0.18, { Transparency = 1 })
			tween(glow, 0.5, { Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 })
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
			task.wait(0.15)
			egg.Visible = false

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
