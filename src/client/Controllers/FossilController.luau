--!strict
-- FossilController: the sign above each giant fossil. Shows the shared dig progress and who is
-- digging, read from attributes the server keeps up to date (FossilService). Display only.

local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Parent.UI.Theme)

local FOSSIL_TAG = "GiantFossil"

type Sign = {
	billboard: BillboardGui,
	fill: Frame,
	caption: TextLabel,
}

local signs: { [BasePart]: Sign } = {}

local function makeSign(part: BasePart): Sign
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FossilSign"
	billboard.Size = UDim2.fromScale(12, 3.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 4, 0)
	billboard.MaxDistance = 120

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Size = UDim2.fromScale(1, 0.55)
	Theme.text(caption, 28)
	caption.Parent = billboard

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.1, 0.62)
	bar.Size = UDim2.fromScale(0.8, 0.3)
	bar.BackgroundColor3 = Theme.colors.purpleDeep
	Theme.corner(bar, UDim.new(0, 4))
	Theme.outline(bar, 3)
	bar.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.colors.lime
	Theme.corner(fill, UDim.new(0, 4))
	fill.Parent = bar

	billboard.Parent = part
	return { billboard = billboard, fill = fill, caption = caption }
end

local function refresh(part: BasePart): ()
	local sign = signs[part]
	if sign == nil then
		sign = makeSign(part)
		signs[part] = sign
	end
	local available = part:GetAttribute("Available") ~= false
	local progress = tonumber(part:GetAttribute("Progress")) or 0
	local diggers = tonumber(part:GetAttribute("Diggers")) or 0
	local helper = part:GetAttribute("Helper") == true
	sign.billboard.Enabled = available
	sign.fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	sign.caption.Text = if diggers >= 2
		then `{diggers} diggers: super fast!`
		elseif helper then "Digging with Bolt..."
		elseif diggers == 1 then "Waiting for a friend..."
		else "Giant Fossil! Dig with a friend"
end

local function track(part: Instance): ()
	if not part:IsA("BasePart") or signs[part] ~= nil then
		return
	end
	refresh(part)
	for _, name in { "Available", "Progress", "Diggers", "Helper" } do
		part:GetAttributeChangedSignal(name):Connect(function()
			refresh(part)
		end)
	end
	part.Destroying:Connect(function()
		signs[part] = nil
	end)
end

local FossilController = {}

function FossilController.start(): ()
	for _, part in CollectionService:GetTagged(FOSSIL_TAG) do
		track(part)
	end
	-- Far fossils stream in later.
	CollectionService:GetInstanceAddedSignal(FOSSIL_TAG):Connect(track)
end

return FossilController
