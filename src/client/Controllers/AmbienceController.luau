--!strict
-- AmbienceController: makes each region feel alive (World Upgrade W3d). Floating pollen in the
-- home meadows, fireflies in Lily Lagoon, falling snow on Cliffside Peaks, blowing dust in Windy
-- Canyons, plus a gentle color mood per region. All local and cheap: one invisible box follows
-- the camera and its particle emitter switches style when you change region, so the effect is
-- always around you and never placed all over the world.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local IslandController = require(script.Parent.IslandController)

-- The box the particles appear in, centered a little above the camera.
local AREA = Vector3.new(110, 45, 110)
local LIFT = 10
local CHECK_INTERVAL = 1
local MOOD_TWEEN = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

type Style = {
	color: ColorSequence,
	rate: number,
	size: NumberSequence,
	speed: NumberRange,
	lifetime: NumberRange,
	acceleration: Vector3,
	lightEmission: number,
	-- Region mood: a soft tint, and a small nudge to how colorful things look (on top of the
	-- place's own color correction in Lighting).
	tint: Color3,
	saturation: number,
}

local STYLES: { [string]: Style } = {
	MeadowIsle = {
		color = ColorSequence.new(Color3.fromRGB(255, 250, 200)),
		rate = 7,
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		}),
		speed = NumberRange.new(0.5, 1.5),
		lifetime = NumberRange.new(5, 8),
		acceleration = Vector3.new(0.4, 0.15, 0.2),
		lightEmission = 0.6,
		tint = Color3.fromRGB(255, 252, 245),
		saturation = 0,
	},
	LilyLagoon = {
		color = ColorSequence.new(Color3.fromRGB(200, 255, 120)),
		rate = 12,
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		speed = NumberRange.new(0.4, 1.2),
		lifetime = NumberRange.new(3, 6),
		acceleration = Vector3.zero,
		lightEmission = 1,
		tint = Color3.fromRGB(238, 255, 248),
		saturation = 0.06,
	},
	CliffsidePeaks = {
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		rate = 28,
		size = NumberSequence.new(0.22),
		speed = NumberRange.new(2, 4),
		lifetime = NumberRange.new(5, 7),
		acceleration = Vector3.new(0.6, -3, 0),
		lightEmission = 0.3,
		tint = Color3.fromRGB(238, 245, 255),
		saturation = -0.06,
	},
	WindyCanyons = {
		color = ColorSequence.new(Color3.fromRGB(232, 196, 140)),
		rate = 10,
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
		speed = NumberRange.new(3, 6),
		lifetime = NumberRange.new(3, 5),
		acceleration = Vector3.new(4, 0.2, 1),
		lightEmission = 0,
		tint = Color3.fromRGB(255, 242, 225),
		saturation = 0.03,
	},
}

local box: Part
local emitter: ParticleEmitter
local mood: ColorCorrectionEffect
local shownStyle: string? = nil

local function apply(regionId: string): ()
	local style = STYLES[regionId]
	if style == nil or shownStyle == regionId then
		return
	end
	shownStyle = regionId
	emitter.Color = style.color
	emitter.Rate = style.rate
	emitter.Size = style.size
	emitter.Speed = style.speed
	emitter.Lifetime = style.lifetime
	emitter.Acceleration = style.acceleration
	emitter.LightEmission = style.lightEmission
	TweenService:Create(mood, MOOD_TWEEN, {
		TintColor = style.tint,
		Saturation = style.saturation,
	}):Play()
end

local AmbienceController = {}

function AmbienceController.start(): ()
	box = Instance.new("Part")
	box.Name = "Ambience"
	box.Size = AREA
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Parent = workspace

	emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LockedToPart = false
	emitter.Rate = 0
	emitter.Parent = box

	-- A separate, client-only effect on top of the place's own color correction.
	mood = Instance.new("ColorCorrectionEffect")
	mood.Name = "RegionMood"
	mood.Parent = Lighting

	apply(IslandController.current() or "MeadowIsle")
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera ~= nil then
			box.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, LIFT, 0))
		end
		local now = os.clock()
		if now >= nextCheck then
			nextCheck = now + CHECK_INTERVAL
			local region = IslandController.current()
			if region ~= nil then
				apply(region)
			end
		end
	end)
end

return AmbienceController
