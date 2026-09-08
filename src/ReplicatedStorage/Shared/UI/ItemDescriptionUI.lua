local TextService = game:GetService("TextService")
local Theme = require(script.Parent.UITheme)
local DescriptionUI = {}

-- Fit full descriptions between the title and ingredients, including after a
-- viewport/UI scale change. No hover is required on touch devices.
function DescriptionUI.Mount(card, item, ingredients, top, inset)
	local description = Theme.Label(card, item and item.Description or "", UDim2.new(1, -inset * 2, 0, 32), UDim2.fromOffset(inset, top), 12, Theme.Colors.TextMuted)
	description.Name = "ItemDescription"
	description.TextWrapped, description.TextTruncate = true, Enum.TextTruncate.None
	description.TextYAlignment, description.ZIndex = Enum.TextYAlignment.Top, ingredients.ZIndex
	local function resize()
		local scale, ancestor = 1, card
		while ancestor do
			for _, child in ipairs(ancestor:GetChildren()) do if child:IsA("UIScale") then scale *= child.Scale end end
			ancestor = ancestor.Parent
		end
		local width = math.max(80, card.AbsoluteSize.X / math.max(.01, scale) - inset * 2)
		local bounds = TextService:GetTextSize(description.Text, description.TextSize, description.Font, Vector2.new(width, 10000))
		local height = math.ceil(bounds.Y) + 4
		description.Size = UDim2.new(1, -inset * 2, 0, height)
		local ingredientsTop = top + height + 6
		ingredients.Position = UDim2.fromOffset(inset, ingredientsTop)
		card.Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset, 0, ingredientsTop + ingredients.Size.Y.Offset + 8)
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return description
end
return DescriptionUI
