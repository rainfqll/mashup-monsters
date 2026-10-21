--!strict
-- The Portal Pass pop-up, shown when you press Travel at a portal without the pass. It says
-- plainly what the pass does (travel between portals you have already reached) and that
-- walking and riding get you everywhere too. Buying goes through Roblox's own purchase window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)

export type PassScreen = {
	panel: Panel.Panel,
}

local PassScreen = {}

function PassScreen.create(parent: ScreenGui, onBuy: () -> ()): PassScreen
	local gap = Panel.GAP
	local panel = Panel.create(parent, "PortalPass", Monetization.portalPassName)
	panel.frame.Size = UDim2.fromScale(0.6, 0.7)
	local limit = panel.frame:FindFirstChildOfClass("UISizeConstraint")
	if limit ~= nil then
		limit.MaxSize = Vector2.new(520, 400)
	end

	-- A little portal picture: a glowing purple ring.
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromScale(0.34, 0.34)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.BackgroundColor3 = Color3.fromRGB(110, 76, 170)
	Theme.corner(icon, UDim.new(0.5, 0))
	Theme.outline(icon, 6, Theme.colors.gold)
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.5, 0.5)
	inner.BackgroundColor3 = Color3.fromRGB(200, 186, 230)
	Theme.corner(inner, UDim.new(0.5, 0))
	inner.Parent = icon
	icon.Parent = panel.body

	local text = Instance.new("TextLabel")
	text.Name = "Pitch"
	text.Position = UDim2.new(0, 0, 0.34, gap)
	text.Size = UDim2.new(1, 0, 0.36, -gap)
	text.Text = "Step into any portal and zoom to every place you've already found. "
		.. "You can always walk and ride there too!"
	Theme.text(text, 24)
	text.TextWrapped = true
	text.Parent = panel.body

	local available = Monetization.portalPassId ~= 0
	local buy = Theme.button("Buy", if available then "Get the Portal Pass" else "Coming soon!", 28)
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.fromScale(0.5, 1)
	buy.Size = UDim2.fromScale(0.8, 0.24)
	buy.BackgroundColor3 = if available then Theme.colors.limeDark else Theme.colors.card
	buy.Parent = panel.body
	buy.Activated:Connect(function()
		if available then
			onBuy()
		end
	end)

	return { panel = panel }
end

return PassScreen
