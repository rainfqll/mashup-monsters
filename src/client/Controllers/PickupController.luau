--!strict
-- PickupController: makes part pickups bob and spin. Purely visual and local: the server keeps
-- pickups still (moving them there would send every frame to every player for nothing).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PICKUP_TAG = "PartPickup"
local BOB_HEIGHT = 0.5
local BOB_SPEED = 2
local SPIN_SPEED = 1.5
-- Far-away pickups are too small to notice; skipping them keeps low-end phones cheap.
local ANIMATE_DISTANCE = 200

type Tracked = { core: BasePart, base: CFrame, phase: number }

local tracked: { [Instance]: Tracked } = {}

local function track(model: Instance): ()
	local core = model:WaitForChild("Core", 5)
	-- The model may have streamed out again while we waited.
	if core == nil or not core:IsA("BasePart") or model.Parent == nil then
		return
	end
	tracked[model] = {
		core = core,
		base = core.CFrame,
		-- Different start points so a row of pickups doesn't bob in lockstep.
		phase = math.random() * math.pi * 2,
	}
end

local PickupController = {}

function PickupController.start(): ()
	CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(function(model)
		task.spawn(track, model)
	end)
	-- Fires when a pickup streams out or is removed; forget it so nothing leaks.
	CollectionService:GetInstanceRemovedSignal(PICKUP_TAG):Connect(function(model)
		tracked[model] = nil
	end)
	for _, model in CollectionService:GetTagged(PICKUP_TAG) do
		task.spawn(track, model)
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()

		table.clear(parts)
		table.clear(cframes)
		for _, entry in tracked do
			if (entry.base.Position - cameraPosition).Magnitude <= ANIMATE_DISTANCE then
				local t = now + entry.phase
				local offset = CFrame.new(0, math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0)
				table.insert(parts, entry.core)
				table.insert(cframes, entry.base * offset * CFrame.Angles(0, t * SPIN_SPEED, 0.4))
			end
		end
		-- One engine call for all pickups instead of one per part.
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return PickupController
