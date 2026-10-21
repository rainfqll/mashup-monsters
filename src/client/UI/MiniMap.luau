--!strict
-- The round mini map in the top-right corner: the world map zoomed in and slid under you, north
-- up, with an arrow showing where you face. Tapping it opens the big map. It only redraws ten
-- times a second, which is plenty for a map and cheap on phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMap = require(ReplicatedStorage.Shared.Config.WorldMap)
local MapView = require(script.Parent.MapView)
local Theme = require(script.Parent.Theme)

-- Studs across the mini map.
local VIEW_SPAN = 320
local UPDATE_INTERVAL = 0.1

export type MiniMap = {
	frame: GuiObject,
	button: TextButton,
}

local MiniMap = {}

function MiniMap.create(parent: GuiObject): MiniMap
	local player = Players.LocalPlayer

	-- A CanvasGroup clips its children to its rounded corners, so the map is a circle.
	local frame = Instance.new("CanvasGroup")
	frame.Name = "MiniMap"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -8, 0, 8)
	frame.Size = UDim2.fromScale(0.28, 0.28)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	frame.BackgroundColor3 = Color3.fromRGB(56, 150, 205)
	Theme.corner(frame, UDim.new(0.5, 0))
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(84, 84)
	limit.MaxSize = Vector2.new(130, 130)
	limit.Parent = frame
	frame.Parent = parent

	-- The ring sits outside the clipped group so it stays crisp.
	local ring = Instance.new("Frame")
	ring.Name = "MiniMapRing"
	ring.AnchorPoint = frame.AnchorPoint
	ring.Position = frame.Position
	ring.Size = frame.Size
	ring.SizeConstraint = frame.SizeConstraint
	ring.BackgroundTransparency = 1
	Theme.corner(ring, UDim.new(0.5, 0))
	Theme.outline(ring, 4)
	local ringLimit = limit:Clone()
	ringLimit.Parent = ring
	ring.Parent = parent

	local zoom = WorldMap.halfSize * 2 / VIEW_SPAN
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.fromScale(zoom, zoom)
	holder.BackgroundTransparency = 1
	holder.Parent = frame
	local view = MapView.create(holder, 0.02)
	-- Region names are too big for the small map; the big map shows them.
	for _, label in view.labels do
		label.Visible = false
	end

	local arrow = MapView.arrow(frame, 20)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromScale(0.18, 0.18)

	local button = Instance.new("TextButton")
	button.Name = "OpenMap"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.ZIndex = 30
	button.Parent = ring

	local nextUpdate = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now < nextUpdate or not frame.Visible then
			return
		end
		nextUpdate = now + UPDATE_INTERVAL
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return
		end
		local point = view.toMap(root.Position.X, root.Position.Z)
		holder.Position = UDim2.fromScale(0.5 - point.X * zoom, 0.5 - point.Y * zoom)
		local look = root.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, look.Z))
	end)

	return { frame = frame, button = button }
end

return MiniMap
