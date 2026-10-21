--!strict
-- "Sam wants to trade!" card with Yes / No. Disappears on its own after the invite runs out.

local Theme = require(script.Parent.Theme)

export type TradeInvite = {
	show: (fromName: string, seconds: number, onAnswer: (accept: boolean) -> ()) -> (),
}

local TradeInvite = {}

function TradeInvite.create(parent: ScreenGui): TradeInvite
	local card = Instance.new("Frame")
	card.Name = "TradeInvite"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.2)
	card.Size = UDim2.fromOffset(340, 132)
	card.BackgroundColor3 = Theme.colors.purpleDeep
	card.Visible = false
	card.ZIndex = 20
	Theme.corner(card)
	Theme.outline(card, 5, Theme.colors.lime)
	card.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -20, 0, 56)
	text.Position = UDim2.fromOffset(10, 6)
	Theme.text(text, 28)
	text.ZIndex = 21
	text.Parent = card

	local yes = Theme.button("Yes", "Yes!", 28)
	yes.Position = UDim2.new(0, 14, 1, -62)
	yes.Size = UDim2.new(0.5, -21, 0, 52)
	yes.BackgroundColor3 = Theme.colors.lime
	yes.ZIndex = 21
	yes.Parent = card
	local no = Theme.button("No", "No", 28)
	no.AnchorPoint = Vector2.new(1, 0)
	no.Position = UDim2.new(1, -14, 1, -62)
	no.Size = UDim2.new(0.5, -21, 0, 52)
	no.BackgroundColor3 = Theme.colors.danger
	no.ZIndex = 21
	no.Parent = card

	local answer: ((boolean) -> ())? = nil
	local token = 0

	local function reply(accept: boolean): ()
		local callback = answer
		answer = nil
		card.Visible = false
		if callback ~= nil then
			callback(accept)
		end
	end
	yes.Activated:Connect(function()
		reply(true)
	end)
	no.Activated:Connect(function()
		reply(false)
	end)

	return {
		show = function(fromName: string, seconds: number, onAnswer: (boolean) -> ())
			token += 1
			local mine = token
			answer = onAnswer
			text.Text = `{fromName} wants to trade!`
			card.Visible = true
			task.delay(seconds, function()
				if token == mine and card.Visible then
					answer = nil
					card.Visible = false
				end
			end)
		end,
	}
end

return TradeInvite
