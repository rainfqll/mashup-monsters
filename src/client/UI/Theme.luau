--!strict
-- Shared look for every screen (Realism Upgrade, spec 4.9): an adventure-game style with dark
-- slate panels, thin gold edges, small corners, clean fonts and calm motion. Screens build their
-- UI through these helpers so the style changes in one place.
--
-- The color names are older than this style ("lime" was the green action color, "purple" the
-- button color); they keep their meaning, only the shades changed.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.colors = table.freeze({
	-- Positive actions (Ride, Create, Go) and their pressed/darker shade.
	lime = Color3.fromRGB(112, 168, 84),
	limeDark = Color3.fromRGB(72, 122, 58),
	-- Ordinary buttons, panel backgrounds, cards inside panels.
	purple = Color3.fromRGB(52, 58, 74),
	purpleDeep = Color3.fromRGB(20, 23, 30),
	card = Color3.fromRGB(34, 38, 48),
	-- Text shadows and dark details.
	outline = Color3.fromRGB(8, 9, 12),
	text = Color3.fromRGB(240, 234, 220),
	textDim = Color3.fromRGB(170, 164, 150),
	-- Edges, titles and highlights.
	gold = Color3.fromRGB(206, 166, 88),
	edge = Color3.fromRGB(150, 122, 70),
	-- Messages: something went wrong / for your information.
	danger = Color3.fromRGB(176, 64, 56),
	info = Color3.fromRGB(88, 150, 200),
	coin = Color3.fromRGB(220, 178, 70),
})

Theme.font = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
Theme.titleFont = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

-- 48 px is the smallest comfortable thumb target on a phone.
Theme.MIN_TOUCH = 48

-- Callers pass border weights from the old chunky style; this style draws them thinner.
local BORDER_SCALE = 0.5

function Theme.corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 6)
	corner.Parent = parent
	return corner
end

function Theme.outline(parent: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	-- Named so code can find the border and not the text shadow Theme.text adds.
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = math.max(1, (thickness or 4) * BORDER_SCALE)
	stroke.Color = color or Theme.colors.edge
	stroke.Parent = parent
	return stroke
end

-- A soft top-to-bottom shade, so flat panels and buttons get a little depth.
function Theme.shade(parent: GuiObject): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	gradient.Parent = parent
	return gradient
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
	-- A soft dark shadow keeps light text readable over the bright world.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Color = Theme.colors.outline
	stroke.Parent = label
end

-- Panel titles and big headings: the serif title font in gold.
function Theme.title(label: TextLabel, maxSize: number): ()
	Theme.text(label, maxSize)
	label.FontFace = Theme.titleFont
	label.TextColor3 = Theme.colors.gold
end

local PRESS_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- A small press-in on touch, back out on release. Connections die with the button.
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
			TweenService:Create(scale, PRESS_INFO, { Scale = 0.95 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			TweenService:Create(scale, RELEASE_INFO, { Scale = 1 }):Play()
		end
	end)
	return scale
end

-- The standard button. Wire behaviour to .Activated (works for touch, mouse, gamepad).
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
	Theme.shade(button)
	Theme.pressable(button)
	return button
end

local PULSE_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Makes a button's border glow gold to say "press me" (tutorial hints). Returns a function that
-- stops it and restores the border. Uses the border, not the size, so it never fights the press
-- animation.
function Theme.pulse(button: GuiObject): () -> ()
	local border = button:FindFirstChild("Border") :: UIStroke?
	if border == nil then
		border = Theme.outline(button, 3)
	end
	local stroke = border :: UIStroke
	local originalColor, originalThickness = stroke.Color, stroke.Thickness
	stroke.Color = Theme.colors.gold
	local tween = TweenService:Create(stroke, PULSE_INFO, { Thickness = originalThickness + 3 })
	tween:Play()
	return function()
		tween:Cancel()
		stroke.Color = originalColor
		stroke.Thickness = originalThickness
	end
end

-- A quick grow-and-settle, used to draw the eye (e.g. the bag after a pickup).
function Theme.pop(scale: UIScale): ()
	scale.Scale = 1.12
	TweenService:Create(scale, POP_INFO, { Scale = 1 }):Play()
end

return Theme
