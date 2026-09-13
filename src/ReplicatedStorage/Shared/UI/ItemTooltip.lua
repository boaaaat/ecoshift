-- Shared readable item details, drawn above both inventory and chest panels.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local ItemDatabase = require(script.Parent.Parent.Items.ItemDatabase)
local Instances = require(script.Parent.Parent.ItemInstance)
local Catalog = require(script.Parent.Parent.OverhaulCatalog)

local ItemTooltip = {}
local inventory

function ItemTooltip.SetInventory(snapshot)
	inventory = snapshot
end

local function comparisonEntry(gear)
	if not inventory then return nil end
	if gear.Kind == "Armor" then
		local index = table.find({"Head", "Chest", "Legs", "Boots"}, gear.Slot)
		return index and (inventory.Equipment or {})[index]
	elseif gear.Kind == "Accessory" then
		for _, entry in pairs(inventory.Accessory or {}) do
			local definition = entry and Instances.Definition(entry.Id)
			if definition and definition.Family == gear.Family and gear.Family then return entry end
		end
	elseif gear.Kind == "Weapon" or gear.Kind == "Tool" then
		local character = Players.LocalPlayer.Character
		local held = character and character:FindFirstChildOfClass("Tool")
		local uid = held and held:GetAttribute("GearUid")
		if uid then
			for _, entry in pairs(inventory.Hotbar or {}) do
				if entry and entry.Uid == uid then return entry end
			end
		end
	end
	return nil
end

local function protection(entry, gear)
	if entry.MaxDurability and (entry.Durability or 0) <= 0 then return 0 end
	local amount = gear.Defense or 0
	if gear.Set and (entry.Grade or gear.Grade) > gear.Grade then
		amount *= Catalog.PhysicalByTier[entry.Grade] / Catalog.PhysicalByTier[gear.Grade]
	end
	return amount
end

local function resistance(entry, gear, channel)
	if entry.MaxDurability and (entry.Durability or 0) <= 0 then return 0 end
	return (gear.Resistance or {})[channel] or 0
end

local function compare(data, gear)
	local other = comparisonEntry(gear)
	if not other then return nil end
	if data.Uid and data.Uid == other.Uid then return "Currently equipped" end
	local definition = Instances.Definition(other.Id)
	if not definition or definition.Kind ~= gear.Kind then return nil end
	local item = ItemDatabase:Get(other.Id)
	local title = "Compared with " .. (item and item.Name or other.Id)
	if gear.Kind == "Armor" then
		local lines = {title, string.format("Physical protection %+.1f percentage points", (protection(data, gear) - protection(other, definition)) * 100)}
		for _, channel in ipairs({"Heat", "Cold", "Toxin", "Wet"}) do
			local delta = resistance(data, gear, channel) - resistance(other, definition, channel)
			if delta ~= 0 then table.insert(lines, string.format("%s protection %+.1f percentage points", channel, delta * 100)) end
		end
		return table.concat(lines, "\n")
	elseif gear.Kind == "Weapon" then
		local damage = data.MaxDurability and (data.Durability or 0) <= 0 and 0 or gear.Damage or 0
		local otherDamage = other.MaxDurability and (other.Durability or 0) <= 0 and 0 or definition.Damage or 0
		return title .. string.format("\nDamage %+.1f / reach %+.1f studs", damage - otherDamage, (gear.Reach or 0) - (definition.Reach or 0))
	elseif gear.Kind == "Tool" then
		local power = (gear.Power or 0) * 2 ^ ((data.Grade or gear.Grade) - gear.Grade)
		local otherPower = (definition.Power or 0) * 2 ^ ((other.Grade or definition.Grade) - definition.Grade)
		if data.MaxDurability and (data.Durability or 0) <= 0 then power = 0 end
		if other.MaxDurability and (other.Durability or 0) <= 0 then otherPower = 0 end
		return title .. string.format("\nBreaking power %+.0f", power - otherPower)
	elseif gear.Kind == "Accessory" then
		return title .. "\n" .. (definition.Description or "Same accessory family; its effects do not stack.")
	end
	return nil
end

local function sourceHint(id)
	local guide = require(script.Parent.Parent.RecipeGuide).GetEntry(id)
	if not guide then return "" end
	if guide.Recipe then
		local ingredients = {}
		for _, entry in ipairs(guide.Recipe.Ingredients or {}) do
			local item = entry.Id and ItemDatabase:Get(entry.Id)
			local text = item and item.Name or "deep-region trophy"
			if entry.Distinct then text = "different deep-region trophies" end
			table.insert(ingredients, tostring(entry.N or 1) .. " " .. text)
		end
		local stations = {}
		for _, id in ipairs(guide.Recipe.AllowedStations or {}) do table.insert(stations, Catalog.Stations[id] and Catalog.Stations[id].Name or id) end
		return "Craft: " .. table.concat(ingredients, ", ") .. (#stations > 0 and "\nAt: " .. table.concat(stations, " / ") or "")
	end
	return table.concat(guide.Sources or {}, "\n")
end

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
	local comparison = label("EquippedComparison", 16.5, Theme.Colors.Sage, 6)
	local source = label("Source", 15, Theme.Colors.TextMuted, 7)
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
   local lines={gear.Description or "","Grade "..tostring(grade)}
   if gear.Kind=="Weapon" then
    table.insert(lines,string.format("Base damage %.1f / range %.1f studs / %.2fs attack",(data.Durability or 1)>0 and (gear.Damage or 0) or 0,gear.Reach or 0,gear.AttackCycle or 1))
    table.insert(lines,"Special: "..(gear.Special or "None").." / 20 stamina / 8s cooldown")
   elseif gear.Kind=="Tool" then
    table.insert(lines,string.format("Breaking power %.0f / combat damage %.0f",(data.Durability or 1)>0 and (gear.Power or 0)*2^(grade-gear.Grade) or 0,data.Id=="Harvester" and 6 or 0))
   elseif gear.Kind=="Armor" then
    local defense=protection(data,gear)
    table.insert(lines,string.format("Physical reduction %.1f%% / %s",defense*100,gear.Slot))
    local protections={};for _,channel in ipairs({"Heat","Cold","Toxin","Wet"}) do local amount=resistance(data,gear,channel);if amount>0 then table.insert(protections,channel.." "..math.floor(amount*100).."%") end end
    table.insert(lines,table.concat(protections," / "))
    local set=gear.Set and catalog.ArmorFamilies[gear.Set]
    if set then table.insert(lines,"2 pieces: "..set.TwoDescription);table.insert(lines,"4 pieces: "..set.FourDescription) end
   end
			if data.MaxDurability then table.insert(lines,string.format("Durability: %d / %d%s",math.ceil(data.Durability or 0),data.MaxDurability,(data.Durability or 0)<=0 and " · BROKEN" or "")) end
			for id,level in pairs(data.Enchantments or {}) do local def=catalog.Enchantments[id];table.insert(lines,(def and def.Name or id).." "..tostring(type(level)=="table" and level.Level or level)) end
			description.Text=table.concat(lines,"\n")
		end
		comparison.Text = gear and compare(data, gear) or ""
		comparison.Visible = comparison.Text ~= ""
		source.Text = sourceHint(data.Id)
		source.Visible = source.Text ~= ""
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
