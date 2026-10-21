--!strict
-- A still 3D picture of one part, used on cards. ViewportFrames only redraw when something in
-- them changes, so a grid of still icons costs about the same as a grid of images, and every
-- new part gets its picture for free from its model in ReplicatedStorage.PartModels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FIELD_OF_VIEW = 30
local FRAMING = 0.72
-- Front-left and a little above, like the creature preview (models face -Z).
local VIEW_DIRECTION = Vector3.new(-0.8, 0.5, -1).Unit

local PartIcon = {}

-- Nil when the part has no model yet; the card then keeps its plain color swatch.
function PartIcon.create(partId: string): ViewportFrame?
	local folder = ReplicatedStorage:FindFirstChild("PartModels")
	local template = if folder ~= nil then folder:FindFirstChild(partId) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(215, 208, 195)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -2, -1)

	local model = template:Clone()
	local center, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - center.Position)
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	-- Closer than "the whole bounding sphere fits": parts are rarely as deep as they are wide.
	local distance = (size.Magnitude / 2) / math.sin(math.rad(FIELD_OF_VIEW / 2)) * FRAMING
	camera.CFrame = CFrame.lookAt(VIEW_DIRECTION * distance, Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return PartIcon
