-- Cache ground-aligned outlines from the same authored models as placed builds.
local BuildModels = require(script.Parent.Parent.Art.OverhaulBuildModels)
local Placement = require(script.Parent.Parent.BuildPlacement)
local BuildPreview = {}
BuildPreview.__index = BuildPreview
local outlines = {}
local V = Vector3.new
local SEGMENTS = 16
local BOX_CORNERS = {
	V(-1,-1,-1), V(1,-1,-1), V(1,-1,1), V(-1,-1,1),
	V(-1,1,-1), V(1,1,-1), V(1,1,1), V(-1,1,1),
}
local BOX_EDGES = {1,2, 2,3, 3,4, 4,1, 5,6, 6,7, 7,8, 8,5, 1,5, 2,6, 3,7, 4,8}
-- WedgeParts slope from their low -Z edge up to their tall +Z face.
local WEDGE_EDGES = {1,2, 2,3, 3,4, 4,1, 3,7, 4,8, 7,8, 1,8, 2,7}

local function outlineFor(itemId)
	if outlines[itemId] then return outlines[itemId] end
	local model = assert(BuildModels.Create(itemId), "Missing build preview: " .. itemId)
	-- Apply the server's surface alignment once, before extracting local lines.
	Placement.PutOnSurface(model, CFrame.identity)
	local points = {}
	for _, part in ipairs(model:GetDescendants()) do
		if not part:IsA("BasePart") or part.Transparency == 1 or part:GetAttribute("ArtDetail") then continue end
		local half, frame = part.Size * .5, part.CFrame
		local function line(a, b)
			points[#points+1] = frame:PointToWorldSpace(a * half)
			points[#points+1] = frame:PointToWorldSpace(b * half)
		end
		if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
			for index = 0, SEGMENTS-1 do
				local a, b = index * math.pi * 2 / SEGMENTS, (index+1) * math.pi * 2 / SEGMENTS
				for _, x in ipairs({-1,1}) do
					line(V(x,math.cos(a),math.sin(a)), V(x,math.cos(b),math.sin(b)))
				end
				if index % 4 == 0 then line(V(-1,math.cos(a),math.sin(a)), V(1,math.cos(a),math.sin(a))) end
			end
		elseif part:IsA("Part") and part.Shape == Enum.PartType.Ball then
			for index = 0, SEGMENTS-1 do
				local a, b = index * math.pi * 2 / SEGMENTS, (index+1) * math.pi * 2 / SEGMENTS
				line(V(math.cos(a),math.sin(a),0), V(math.cos(b),math.sin(b),0))
				line(V(math.cos(a),0,math.sin(a)), V(math.cos(b),0,math.sin(b)))
				line(V(0,math.cos(a),math.sin(a)), V(0,math.cos(b),math.sin(b)))
			end
		else
			local edges = part:IsA("WedgePart") and WEDGE_EDGES or BOX_EDGES
			for index = 1, #edges, 2 do line(BOX_CORNERS[edges[index]], BOX_CORNERS[edges[index+1]]) end
		end
	end
	-- Only line data survives: no preview lights, effects, tags or interaction parts.
	model:Destroy()
	outlines[itemId] = points
	return points
end

function BuildPreview.new(parent, itemId)
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "PlacementPreview", V(.1,.1,.1), 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = true, false, false, false, false
	root.Parent = workspace
	local wire = Instance.new("WireframeHandleAdornment")
	-- Non-unit thickness currently makes Roblox draw these lines at the world
	-- origin instead of following Adornee. Keep this at 1 before adding lines.
	wire.Name, wire.Thickness, wire.Transparency = "StructureOutline", 1, 0
	-- A placement guide must remain visible behind the avatar and ground edges.
	wire.AlwaysOnTop, wire.ZIndex = true, 1
	wire.Visible, wire.Adornee = false, root
	wire.Parent = parent
	local self = setmetatable({Root=root, Wire=wire}, BuildPreview)
	self:SetItem(itemId)
	return self
end

function BuildPreview:SetItem(itemId)
	if self.ItemId == itemId then return end
	self:Hide()
	self.Points = outlineFor(itemId)
	self.ItemId, self.Color = itemId, nil
end

function BuildPreview:Show(frame, color)
	if self.Root.CFrame ~= frame then self.Root.CFrame = frame end
	-- Wireframe colors are stored with each line; redraw only on item/color changes.
	if self.Color ~= color then
		self.Wire:Clear()
		self.Wire.Color3 = color
		self.Wire:AddLines(self.Points)
		self.Color = color
	end
	self.Wire.Visible = true
end

function BuildPreview:Hide()
	self.Wire.Visible = false
end

function BuildPreview:Destroy()
	self.Wire:Destroy()
	self.Root:Destroy()
end

return BuildPreview
