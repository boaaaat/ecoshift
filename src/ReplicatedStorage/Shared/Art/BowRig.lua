-- Bow coordinates are handle-local: +X is the arrow's flight direction, +Y is up.
-- Every moving piece uses a joint, so drawing never moves the tool's physical root.
local Rig = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
Rig.Span = 2.3
Rig.DrawLength = 1.15
Rig.Segments = 12

function Rig.Nock(draw)
	return V(.12 - Rig.DrawLength * draw, .12, 0)
end

function Rig.Limb(t, side, draw)
	local a, b = V(0, .36, 0), V(.58, .92, 0)
	local c, d = V(.7 - draw * .22, 1.8, 0), V(.12 - draw * .42, Rig.Span - draw * .2, 0)
	local u = 1 - t
	local p = a * u ^ 3 + b * 3 * u ^ 2 * t + c * 3 * u * t ^ 2 + d * t ^ 3
	return V(p.X, p.Y * side, 0)
end

local function segment(from, to)
	return CFrame.lookAt((from + to) / 2, to) * A(math.pi / 2, 0, 0), (to - from).Magnitude
end

function Rig.Create(tool, handle, wood, metal, accent, grade)
	tool:SetAttribute("ArticulatedBow", true)
	local function piece(name, size, frame, color, material, dynamic)
		local p = Instance.new((name == "NockedHead" or name == "NockedFeather") and "WedgePart" or "Part")
		p.Name, p.Size, p.CFrame = name, size, handle.CFrame * frame
		if dynamic == "Limb" then
			p.Shape = Enum.PartType.Cylinder
			p.Size, frame = V(size.Y, size.X, size.Z), frame * A(0, 0, math.pi / 2)
			p.CFrame = handle.CFrame * frame
		end
		p.Color, p.Material = color, material
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = tool
		local joint = Instance.new("Weld")
		joint.Name, joint.Part0, joint.Part1, joint.C0, joint.Parent = "BowJoint", handle, p, frame, p
		if dynamic then p:SetAttribute("BowMotion", dynamic) end
		return p
	end
	for side = -1, 1, 2 do
		for i = 1, Rig.Segments do
			local frame, length = segment(Rig.Limb((i - 1) / Rig.Segments, side, 0), Rig.Limb(i / Rig.Segments, side, 0))
			local width = .25 - i / Rig.Segments * .104
			local p = piece("LaminatedLimb", V(width, length + .035, .19), frame,
				i >= Rig.Segments - 1 and metal or wood:Lerp(metal, grade > 1 and .17 or 0), i >= Rig.Segments - 1 and Enum.Material.Metal or Enum.Material.Wood, "Limb")
			p:SetAttribute("BowSide", side); p:SetAttribute("BowSegment", i)
			local strip = piece("LimbLamination", V(.04, length, .025), frame * CF(0, 0, -.108), accent, Enum.Material.SmoothPlastic, "Lamination")
			strip:SetAttribute("BowSide", side); strip:SetAttribute("BowSegment", i)
		end
		local frame, length = segment(Rig.Limb(1, side, 0), Rig.Nock(0))
		local stringPart = piece("Bowstring", V(.022, length, .022), frame, Color3.fromRGB(207, 194, 157), Enum.Material.Fabric, "String")
		stringPart:SetAttribute("BowSide", side)
	end
	local arrow = {
		{ "NockedShaft", V(.055, 2.55, .055), CF(0, 1.275, 0), Color3.fromRGB(138, 102, 64), Enum.Material.Wood },
		{ "NockedHead", V(.26, .38, .09), CF(0, 2.63, 0), metal, Enum.Material.Metal },
		{ "NockedFeather", V(.02, .4, .23), CF(0, .25, 0), accent, Enum.Material.Fabric },
		{ "NockedFeather", V(.23, .4, .02), CF(0, .25, 0), accent, Enum.Material.Fabric },
	}
	for _, data in ipairs(arrow) do
		local p = piece(data[1], data[2], CF(Rig.Nock(0)) * A(0, 0, -math.pi / 2) * data[3], data[4], data[5], "Arrow")
		p:SetAttribute("ArrowOffset", data[3]); p.Transparency = 1
	end
	local grip = Instance.new("Attachment")
	grip.Name, grip.Parent = "ItemGrip", handle
end

function Rig.Bind(tool)
	local pieces = {}
	for _, p in ipairs(tool:GetChildren()) do
		local motion = p:GetAttribute("BowMotion")
		local joint = p:FindFirstChild("BowJoint")
		if p:IsA("BasePart") and motion and joint then
			pieces[#pieces + 1] = { Part = p, Joint = joint, Motion = motion, Side = p:GetAttribute("BowSide"), Segment = p:GetAttribute("BowSegment"), Offset = p:GetAttribute("ArrowOffset") }
		end
	end
	local controller = {}
	function controller:Update(draw, nocked, nockPosition)
		local nock = nockPosition or Rig.Nock(draw)
		local arrowDirection = V(.5, .12, 0) - nock
		local arrowFrame = CFrame.lookAt(nock, nock + (arrowDirection.Magnitude > .001 and arrowDirection.Unit or Vector3.xAxis)) * A(-math.pi / 2, 0, 0)
		for _, r in ipairs(pieces) do
			local frame, length
			if r.Motion == "Limb" or r.Motion == "Lamination" then
				frame, length = segment(Rig.Limb((r.Segment - 1) / Rig.Segments, r.Side, draw), Rig.Limb(r.Segment / Rig.Segments, r.Side, draw))
				if r.Motion == "Lamination" then frame *= CF(0, 0, -.108) end
				if r.Motion == "Limb" then frame *= A(0, 0, math.pi / 2) end
			elseif r.Motion == "String" then frame, length = segment(Rig.Limb(1, r.Side, draw), nock)
			else
				frame = arrowFrame * r.Offset
				r.Part.LocalTransparencyModifier = nocked and 0 or 1
				r.Part.Transparency = 0
			end
			r.Joint.C0 = frame
			if r.Motion == "Limb" then r.Part.Size = V(length + .035, r.Part.Size.Y, r.Part.Size.Z)
			elseif length then r.Part.Size = V(r.Part.Size.X, length, r.Part.Size.Z) end
		end
	end
	function controller:Destroy() self:Update(0, false) end
	return controller
end

return Rig
