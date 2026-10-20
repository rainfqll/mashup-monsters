--!strict
-- ChallengeController: shows ring course progress. The server decides when a ring counts
-- (ChallengeService); this only lights up the ring to fly through next and runs the countdown.
-- Ring visuals are the BaseParts inside each "ChallengeRing" part (built in Studio).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RING_TAG = "ChallengeRing"
local NEXT_COLOR = Color3.fromRGB(150, 240, 60)
local START_COLOR = Color3.fromRGB(255, 200, 50)
local IDLE_COLOR = Color3.fromRGB(240, 240, 255)

type StatusListener = (text: string?) -> ()

local listeners: { StatusListener } = {}
-- Bumped on every update so an older countdown loop stops.
local runToken = 0

local function setStatus(text: string?): ()
	for _, listener in listeners do
		task.spawn(listener, text)
	end
end

local function paint(ring: Instance, color: Color3): ()
	for _, child in ring:GetChildren() do
		if child:IsA("BasePart") then
			child.Color = color
		end
	end
end

-- With no run going, every course shows its first ring in gold ("start here").
local function paintCourses(activeChallenge: string?, nextRing: number): ()
	for _, ring in CollectionService:GetTagged(RING_TAG) do
		local order = tonumber(ring:GetAttribute("Order")) or 0
		local isActive = ring:GetAttribute("Challenge") == activeChallenge
		local color = if isActive and order == nextRing
			then NEXT_COLOR
			elseif activeChallenge == nil and order == 1 then START_COLOR
			else IDLE_COLOR
		paint(ring, color)
	end
end

local ChallengeController = {}

function ChallengeController.onStatusChanged(listener: StatusListener): ()
	table.insert(listeners, listener)
end

function ChallengeController.start(): ()
	local activeChallenge: string? = nil
	local activeRing = 0
	paintCourses(nil, 0)
	-- Far-away parts stream in later (StreamingEnabled), so paint rings as they arrive too.
	CollectionService:GetInstanceAddedSignal(RING_TAG):Connect(function()
		paintCourses(activeChallenge, activeRing)
	end)
	Remotes.event("ChallengeProgress").OnClientEvent
		:Connect(function(challengeId: string, nextRing: number, total: number, secondsLeft: number)
			runToken += 1
			activeChallenge = if nextRing == 0 then nil else challengeId
			activeRing = nextRing
			if nextRing == 0 then
				paintCourses(nil, 0)
				setStatus(nil)
				return
			end
			paintCourses(challengeId, nextRing)
			local token = runToken
			task.spawn(function()
				local endsAt = os.clock() + secondsLeft
				while token == runToken do
					local left = math.max(0, math.ceil(endsAt - os.clock()))
					setStatus(`Ring {nextRing - 1}/{total}  ·  {left}s`)
					task.wait(0.25)
				end
			end)
		end)
end

return ChallengeController
