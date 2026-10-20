--!strict
-- Shared look for every screen: chunky rounded shapes, thick dark outlines, lime + purple.
-- Screens build their UI through these helpers so the style changes in one place.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.colors = table.freeze({
	lime = Color3.fromRGB(150, 230, 50),
	limeDark = Color3.fromRGB(90, 160, 20),
	purple = Color3.fromRGB(125, 70, 210),
	purpleDeep = Color3.fromRGB(70, 35, 125),
	card = Color3.fromRGB(95, 55, 160),
	outline = Color3.fromRGB(30, 15, 50),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(215, 200, 240),
})

Theme.font = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- 48 px is the smallest comfortable thumb target on a phone.
Theme.MIN_TOUCH = 48

function Theme.corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 14)
	corner.Parent = parent
	return corner
end

function Theme.outline(parent: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	-- Named so code can find the border and not the text outline Theme.text adds.
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness or 4
	stroke.Color = color or Theme.colors.outline
	stroke.Parent = parent
	return stroke
end

-- Text that scales with its box but never gets huge on big screens.
function Theme.text(label: TextLabel | TextButton, maxSize: number): ()
	label.FontFace = Theme.font
	label.TextColor3 = Theme.colors.text
	label.TextScaled = true
	label.BackgroundTransparency = 1
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	-- Dark text outline keeps white text readable on any background.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 2
	stroke.Color = Theme.colors.outline
	stroke.Parent = label
end

local PRESS_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Squish on press, spring back on release. Connections die with the button.
function Theme.pressable(button: GuiButton): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			TweenService:Create(scale, PRESS_INFO, { Scale = 0.9 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			TweenService:Create(scale, RELEASE_INFO, { Scale = 1 }):Play()
		end
	end)
	return scale
end

-- The standard chunky button. Wire behaviour to .Activated (works for touch, mouse, gamepad).
function Theme.button(name: string, text: string, maxText: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.AutoButtonColor = false
	Theme.text(button, maxText)
	button.BackgroundTransparency = 0
	button.BackgroundColor3 = Theme.colors.purple
	Theme.corner(button)
	Theme.outline(button, 3)
	Theme.pressable(button)
	return button
end

local PULSE_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Makes a button's border throb in lime to say "press me" (tutorial hints). Returns a function
-- that stops it and restores the border. Uses the border, not the size, so it never fights the
-- press animation.
function Theme.pulse(button: GuiObject): () -> ()
	local border = button:FindFirstChild("Border") :: UIStroke?
	if border == nil then
		border = Theme.outline(button, 3)
	end
	local stroke = border :: UIStroke
	local originalColor, originalThickness = stroke.Color, stroke.Thickness
	stroke.Color = Theme.colors.lime
	local tween = TweenService:Create(stroke, PULSE_INFO, { Thickness = originalThickness + 6 })
	tween:Play()
	return function()
		tween:Cancel()
		stroke.Color = originalColor
		stroke.Thickness = originalThickness
	end
end

-- A quick grow-and-settle, used to draw the eye (e.g. the bag after a pickup).
function Theme.pop(scale: UIScale): ()
	scale.Scale = 1.25
	TweenService:Create(scale, POP_INFO, { Scale = 1 }):Play()
end

return Theme
