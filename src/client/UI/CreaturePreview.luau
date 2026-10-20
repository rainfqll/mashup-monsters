--!strict
-- A slowly spinning 3D view of a creature, built with the same assembler the server uses,
-- so what you see at the station is exactly what you get.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureAssembler = require(ReplicatedStorage.Shared.CreatureAssembler)
local Types = require(ReplicatedStorage.Shared.Types)

local FIELD_OF_VIEW = 40
local SPIN_SPEED = 0.8
-- Camera direction from the creature: front-left and a little above (creatures face -Z).
local VIEW_DIRECTION = Vector3.new(-0.7, 0.45, -1).Unit

export type Preview = {
	frame: ViewportFrame,
	show: (loadout: Types.Loadout?) -> (),
	setSpinning: (spinning: boolean) -> (),
}

local CreaturePreview = {}

function CreaturePreview.create(parent: GuiObject): Preview
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 160, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = parent

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model: Model? = nil
	local basePivot = CFrame.identity
	local angle = 0
	local spinConnection: RBXScriptConnection? = nil

	local function show(loadout: Types.Loadout?): ()
		if model ~= nil then
			model:Destroy()
			model = nil
		end
		if loadout == nil then
			return
		end
		local built = CreatureAssembler.build(loadout)
		-- Center it on the origin so spinning turns it in place.
		local center, size = built:GetBoundingBox()
		built:PivotTo(built:GetPivot() - center.Position)
		basePivot = built:GetPivot()
		built:PivotTo(CFrame.Angles(0, angle, 0) * basePivot)
		built.Parent = viewport
		model = built

		local radius = size.Magnitude / 2
		-- A little closer than "whole bounding sphere fits", since creatures are wider than tall.
		local distance = radius / math.sin(math.rad(FIELD_OF_VIEW / 2)) * 0.8
		camera.CFrame = CFrame.lookAt(VIEW_DIRECTION * distance, Vector3.zero)
	end

	-- Spin only while visible; a hidden screen should cost nothing per frame.
	local function setSpinning(spinning: boolean): ()
		if spinConnection ~= nil then
			spinConnection:Disconnect()
			spinConnection = nil
		end
		if spinning then
			spinConnection = RunService.RenderStepped:Connect(function(deltaTime)
				angle += deltaTime * SPIN_SPEED
				if model ~= nil then
					model:PivotTo(CFrame.Angles(0, angle, 0) * basePivot)
				end
			end)
		end
	end

	viewport.Destroying:Connect(function()
		setSpinning(false)
	end)

	return {
		frame = viewport,
		show = show,
		setSpinning = setSpinning,
	}
end

return CreaturePreview
