-- Shared readable item details, drawn above both inventory and chest panels.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local ItemDatabase = require(script.Parent.Parent.Items.ItemDatabase)

local ItemTooltip = {}

function ItemTooltip.new(owner)
	local screen = Instance.new("ScreenGui")
	screen.Name = owner.Name .. "ItemDetails"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = math.max(95, owner.DisplayOrder + 1)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Name = "Tooltip"
	frame.Size = UDim2.fromOffset(360, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Colors.Background
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Border
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local function label(name, size, color, order, bold)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.TextWrapped = true
		text.TextSize = size
		text.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		text.TextColor3 = color
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.LayoutOrder = order
		text.Parent = frame
		return text
	end
	local name = label("ItemName", 21, Theme.Colors.Text, 1, true)
	local tags = label("Tags", 16.5, Theme.Colors.Sage, 2)
	local description = label("Description", 16.5, Theme.Colors.Text, 3)
	local quantity = label("Quantity", 16.5, Theme.Colors.TextMuted, 4)
	local hint = label("Hint", 15, Theme.Colors.TextMuted, 5)
	local self = {Frame = frame}
	function self:Move()
		local mouse = UserInputService:GetMouseLocation() - screen.AbsolutePosition
		local bounds = screen.AbsoluteSize
		local size = frame.AbsoluteSize
		local x, y = mouse.X + 18, mouse.Y + 18
		if x + size.X > bounds.X - 8 then x = mouse.X - size.X - 18 end
		if y + size.Y > bounds.Y - 8 then y = mouse.Y - size.Y - 18 end
		frame.Position = UDim2.fromOffset(math.clamp(x, 8, math.max(8, bounds.X - size.X - 8)), math.clamp(y, 8, math.max(8, bounds.Y - size.Y - 8)))
	end
	function self:Show(data, controls)
		if not data or not data.Id then self:Hide(); return end
		local item = ItemDatabase:Get(data.Id)
		name.Text = item and item.Name or data.Id
		local itemTags = item and item.Tags or {}
		tags.Text = table.concat(itemTags, " • ")
		tags.Visible = #itemTags > 0
		description.Text = item and item.Description or ""
		local instances=require(script.Parent.Parent.ItemInstance)
		local gear=instances.Definition(data.Id)
		if gear then
			local catalog=require(script.Parent.Parent.OverhaulCatalog)
			local grade=data.Grade or gear.Grade
   local lines={description.Text,"Grade "..tostring(grade)}
   if gear.Kind=="Weapon" then
    table.insert(lines,string.format("Damage %.1f / range %.1f studs / %.2fs attack",gear.Damage or 0,gear.Reach or 0,gear.AttackCycle or 1))
    table.insert(lines,"Special: "..(gear.Special or "None").." / 20 stamina / 8s cooldown")
   elseif gear.Kind=="Tool" then
    table.insert(lines,string.format("Breaking power %.0f / combat damage %.0f",(gear.Power or 0)*2^(grade-gear.Grade),gear.Damage or 6))
   elseif gear.Kind=="Armor" then
    local defense=(gear.Defense or 0)*(catalog.PhysicalByTier[grade]/catalog.PhysicalByTier[gear.Grade])
    table.insert(lines,string.format("Physical reduction %.1f%% / %s",defense*100,gear.Slot))
    local protection={};for _,channel in ipairs({"Heat","Cold","Toxin","Wet"}) do local amount=(gear.Resistance or {})[channel] or 0;if amount>0 then table.insert(protection,channel.." "..math.floor(amount*100).."%") end end
    table.insert(lines,table.concat(protection," / "))
    local set=gear.Set and catalog.ArmorFamilies[gear.Set]
    if set then table.insert(lines,"2 pieces: "..set.TwoDescription);table.insert(lines,"4 pieces: "..set.FourDescription) end
   end
			if data.MaxDurability then table.insert(lines,string.format("Durability: %d / %d%s",math.ceil(data.Durability or 0),data.MaxDurability,(data.Durability or 0)<=0 and " · BROKEN" or "")) end
			for id,level in pairs(data.Enchantments or {}) do local def=catalog.Enchantments[id];table.insert(lines,(def and def.Name or id).." "..tostring(type(level)=="table" and level.Level or level)) end
			description.Text=table.concat(lines,"\n")
		end
		if data.Id=="FieldJournal" then
   local installed={};for id in pairs(data.InstalledModules or {}) do local def=ItemDatabase:Get(id);table.insert(installed,def and def.Name or id) end;table.sort(installed)
   description.Text=description.Text.."\nInstalled: "..(#installed>0 and table.concat(installed,", ") or "No modules")
  end
  description.Visible = description.Text ~= ""
		quantity.Text = "Quantity: " .. tostring(data.N or 1)
		hint.Text = controls or ""
		hint.Visible = hint.Text ~= ""
		frame.Visible = true
		self:Move()
	end
	function self:Hide() frame.Visible = false end
	local moveConnection = UserInputService.InputChanged:Connect(function(input)
		if frame.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then self:Move() end
	end)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if frame.Visible then self:Move() end end)
	owner.Destroying:Connect(function() moveConnection:Disconnect(); screen:Destroy() end)
	Theme.BindResponsive(screen, function(_, bounds)
		frame.Size = UDim2.fromOffset(math.min(360, math.max(100, bounds.X - 16)), 0)
		if frame.Visible then self:Move() end
	end)
	Theme.TrackRoot(screen)
	return self
end

return ItemTooltip
