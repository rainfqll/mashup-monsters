--!strict
-- PickupController: makes pickups bob and spin, and shows the real part model inside part
-- bubbles. Purely visual and local: the server keeps pickups still (moving them there would
-- send every frame to every player for nothing) and only sends a small colored block, which
-- this swaps for a clone of the part's model from ReplicatedStorage.PartModels.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PICKUP_TAG = "PartPickup"
local BOB_HEIGHT = 0.5
local BOB_SPEED = 2
local SPIN_SPEED = 1.5
-- Far-away pickups are too small to notice; skipping them keeps low-end phones cheap.
local ANIMATE_DISTANCE = 200
-- The part model is scaled so its longest side is this many studs (the bubble is 4).
local VISUAL_SIZE = 2.6

type Tracked = {
	core: BasePart,
	base: CFrame,
	phase: number,
	-- The part model drawn instead of the core, and its pivot relative to the core.
	visual: Model?,
	visualOffset: CFrame,
	activeChanged: RBXScriptConnection?,
}

local tracked: { [Instance]: Tracked } = {}

local function buildVisual(partId: string): (Model?, CFrame)
	local folder = ReplicatedStorage:FindFirstChild("PartModels")
	local template = if folder ~= nil then folder:FindFirstChild(partId) else nil
	if template == nil or not template:IsA("Model") then
		return nil, CFrame.identity
	end
	local visual = template:Clone()
	local _, size = visual:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		visual:ScaleTo(visual:GetScale() * VISUAL_SIZE / longest)
	end
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end
	-- Centered on the core, so it spins around its middle.
	local center = visual:GetBoundingBox()
	return visual, center:ToObjectSpace(visual:GetPivot())
end

local function setVisualShown(entry: Tracked, shown: boolean): ()
	local visual = entry.visual
	if visual == nil then
		return
	end
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if shown then 0 else 1
		end
	end
end

local function untrack(model: Instance): ()
	local entry = tracked[model]
	if entry == nil then
		return
	end
	tracked[model] = nil
	if entry.activeChanged ~= nil then
		entry.activeChanged:Disconnect()
	end
	if entry.visual ~= nil then
		entry.visual:Destroy()
	end
end

local function track(model: Instance): ()
	local core = model:WaitForChild("Core", 5)
	-- The model may have streamed out again while we waited.
	if core == nil or not core:IsA("BasePart") or model.Parent == nil or tracked[model] ~= nil then
		return
	end
	local entry: Tracked = {
		core = core,
		base = core.CFrame,
		-- Different start points so a row of pickups doesn't bob in lockstep.
		phase = math.random() * math.pi * 2,
		visualOffset = CFrame.identity,
	}
	local partId = model:GetAttribute("PartId")
	if type(partId) == "string" then
		local visual, offset = buildVisual(partId)
		if visual ~= nil then
			entry.visual = visual
			entry.visualOffset = offset
			core.LocalTransparencyModifier = 1
			visual.Parent = model
			-- The server hides a collected pickup by hiding the core; follow along.
			setVisualShown(entry, model:GetAttribute("Active") ~= false)
			entry.activeChanged = model:GetAttributeChangedSignal("Active"):Connect(function()
				setVisualShown(entry, model:GetAttribute("Active") ~= false)
			end)
		end
	end
	tracked[model] = entry
end

local PickupController = {}

function PickupController.start(): ()
	CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(function(model)
		task.spawn(track, model)
	end)
	-- Fires when a pickup streams out or is removed; forget it so nothing leaks.
	CollectionService:GetInstanceRemovedSignal(PICKUP_TAG):Connect(untrack)
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
				local cframe = entry.base * offset * CFrame.Angles(0, t * SPIN_SPEED, 0.4)
				table.insert(parts, entry.core)
				table.insert(cframes, cframe)
				local visual = entry.visual
				if visual ~= nil then
					-- Part models are several pieces; a pivot move per nearby pickup is cheap.
					visual:PivotTo(
						entry.base
							* offset
							* CFrame.Angles(0, t * SPIN_SPEED, 0)
							* entry.visualOffset
					)
				end
			end
		end
		-- One engine call for all cores instead of one per part.
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return PickupController
