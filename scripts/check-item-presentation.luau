-- Studio Edit or Server: put this file in a temporary ModuleScript and call
-- require(module)({}). Returns a structured report; never starts/stops Play.
-- Options: ItemIds={...} for a focused rerun, MaxFailures=150, ToolService=service.
-- Uses real inventory construction and native R6/R15 rigs. No player inventories,
-- live characters, damage, saves or published assets are changed.
return function(options)
	options = options or {}
	local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
	local Players = game:GetService("Players")
	local Shared = RS:WaitForChild("Shared")
	local Catalog = require(Shared.OverhaulCatalog)
	local report = { Checks = 0, Failures = {}, FailureCount = 0, Items = 0, FactoryItems = 0, PoseSamples = 0,
		Rigs = {}, Families = {}, Warnings = {}, Passed = false }
	local cleanup = {}
	local function own(instance) cleanup[#cleanup + 1] = instance; return instance end
	local function check(condition, context, message)
		report.Checks += 1
		if condition then return end
		report.FailureCount += 1
		if #report.Failures < (options.MaxFailures or 150) then
			report.Failures[#report.Failures + 1] = context .. ": " .. message
		end
	end
	local function finite(number) return number == number and math.abs(number) < 1e12 end
	local function finiteFrame(frame)
		for _, n in ipairs({ frame:GetComponents() }) do if not finite(n) then return false end end
		return true
	end
	local function nearFrame(a, b, tolerance)
		local _, angle = a:ToObjectSpace(b):ToAxisAngle()
		return (a.Position - b.Position).Magnitude < tolerance and math.abs(angle) < tolerance
	end
	local function jointLike(object)
		return object:IsA("JointInstance") or object:IsA("AnimationConstraint")
	end
	local function boxesOverlap(a, aSize, b, bSize)
		local aAxes, bAxes = { a.RightVector, a.UpVector, a.LookVector }, { b.RightVector, b.UpVector, b.LookVector }
		local aHalf, bHalf = { aSize.X / 2, aSize.Y / 2, aSize.Z / 2 }, { bSize.X / 2, bSize.Y / 2, bSize.Z / 2 }
		local axes = { aAxes[1], aAxes[2], aAxes[3], bAxes[1], bAxes[2], bAxes[3] }
		for _, x in ipairs(aAxes) do for _, y in ipairs(bAxes) do
			local cross = x:Cross(y)
			if cross.Magnitude > .0001 then axes[#axes + 1] = cross.Unit end
		end end
		local delta = b.Position - a.Position
		for _, axis in ipairs(axes) do
			local radius = 0
			for i = 1, 3 do radius += aHalf[i] * math.abs(aAxes[i]:Dot(axis)) + bHalf[i] * math.abs(bAxes[i]:Dot(axis)) end
			if math.abs(delta:Dot(axis)) >= radius - .0001 then return false end
		end
		return true
	end
	local function armJoint(object)
		return (object:IsA("Motor6D") or object:IsA("AnimationConstraint"))
			and (object.Name:find("Shoulder") or object.Name:find(" Shoulder") or object.Name:find("Elbow") or object.Name:find("Wrist"))
	end
	local function gripFrame(character, side, frames)
		local hand = character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")
		local attachment = hand:FindFirstChild(side .. "GripAttachment")
		return frames[hand] * (attachment and attachment.CFrame or CFrame.new(0, -hand.Size.Y / 2, 0))
	end
	local function inspectTool(tool, context)
		check(tool and tool:IsA("Tool"), context, "constructor did not return a Tool")
		if not tool or not tool:IsA("Tool") then return false end
		local handle = tool:FindFirstChild("Handle")
		check(handle and handle:IsA("BasePart"), context, "missing BasePart Handle")
		if not handle or not handle:IsA("BasePart") then return false end
		check(tool.RequiresHandle, context, "tool does not require its visible handle")
		local linked = { [handle] = true }
		local parts, joints = {}, {}
		for _, child in ipairs(tool:GetDescendants()) do
			if child:IsA("BasePart") then
				parts[#parts + 1] = child
				check(not child.Anchored and not child.CanCollide and child.Massless, context, child.Name .. " can pin/collide with the character")
				check(finiteFrame(child.CFrame) and child.Size.X > 0 and child.Size.Y > 0 and child.Size.Z > 0, context, child.Name .. " has invalid geometry")
			elseif jointLike(child) or child:IsA("WeldConstraint") then joints[#joints + 1] = child end
		end
		for _ = 1, #parts do
			local changed = false
			for _, joint in ipairs(joints) do
				if joint.Part0 and joint.Part1 then
					if linked[joint.Part0] and not linked[joint.Part1] then linked[joint.Part1] = true; changed = true end
					if linked[joint.Part1] and not linked[joint.Part0] then linked[joint.Part0] = true; changed = true end
				end
			end
			if not changed then break end
		end
		for _, joint in ipairs(joints) do check(joint.Enabled, context, joint.Name .. " is disabled in the constructed tool") end
		for _, part in ipairs(parts) do check(linked[part], context, part.Name .. " is disconnected from Handle") end
		return true
	end
	local ok, fatal = xpcall(function()
		local folder = own(Instance.new("Folder")); folder.Name = "_ItemPresentationChecks"; folder.Parent = SS
		-- Clone this cohesive art package so editor reruns see freshly edited modules.
		local art = own(Shared.Art:Clone()); art.Name = "_ItemPresentationChecksArt"; art.Parent = Shared
		local Factory, Pose = require(art.OverhaulGearModels), require(art.ItemPose)
		local Presentation = require(art.ItemPresentation)
		local production = options.ToolService
		if not production then
			local module = own(game.ServerScriptService.Services.ToolService:Clone())
			module.Name = "_ItemPresentationChecksToolService"; module.Parent = game.ServerScriptService.Services
			production = require(module)
		end
		local filter = options.ItemIds and {}
		for _, id in ipairs(options.ItemIds or {}) do filter[id] = true end
		local factoryIds = {}
		for id, definition in pairs(Catalog.Gear) do
			if (definition.Kind == "Tool" or definition.Kind == "Weapon") and (not filter or filter[id]) then factoryIds[#factoryIds + 1] = id end
		end
		table.sort(factoryIds)
		for _, id in ipairs(factoryIds) do
			local success, result = pcall(Factory.Create, id, Catalog.Gear[id])
			check(success and typeof(result) == "Instance", "factory/" .. id, "factory returned " .. tostring(result))
			if success and typeof(result) == "Instance" then inspectTool(result, "factory/" .. id); result:Destroy() end
			report.FactoryItems += 1
		end
		local rigTemplates = {}
		for _, rigType in ipairs({ Enum.HumanoidRigType.R6, Enum.HumanoidRigType.R15 }) do
			local description = Instance.new("HumanoidDescription")
			local rig = Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
			description:Destroy(); rig.Name = rigType.Name; rig.Parent = folder
			for _, child in ipairs(rig:GetDescendants()) do
				if child:IsA("BasePart") then child.Anchored = true end
				if jointLike(child) or child:IsA("Constraint") then child.Enabled = false end
				if armJoint(child) then child.Transform = CFrame.Angles(.06, -.025, .035) end
			end
			rig:PivotTo(CFrame.new(0, 20, 0) * rig.HumanoidRootPart.CFrame:Inverse() * rig:GetPivot())
			rigTemplates[#rigTemplates + 1] = rig
			report.Rigs[#report.Rigs + 1] = rigType.Name
		end
		local ids = {}
		for id in pairs(Catalog.Items) do
			if (not filter or filter[id]) and production:IsHoldable(id) then ids[#ids + 1] = id end
		end
		table.sort(ids)
		local function poseItem(template, source, id, family)
			local character = template:Clone(); character.Parent = folder
			local tool = source:Clone(); tool.Parent = character
			local handle = tool.Handle
			local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			for _, joint in ipairs(character:GetDescendants()) do
				if joint:IsA("JointInstance") and joint.Part1 == handle then joint:Destroy() end
			end
			local grip = Instance.new("Weld"); grip.Name = "RightGrip"; grip.Part0 = hand; grip.Part1 = handle
			local attachment = hand:FindFirstChild("RightGripAttachment")
			grip.C0 = attachment and attachment.CFrame or CFrame.new(0, -hand.Size.Y / 2, 0)
			grip.C1, grip.Enabled, grip.Parent = tool.Grip, false, hand
			local initial, offsets, baseline, joints = {}, {}, {}, {}
			for _, child in ipairs(character:GetDescendants()) do
				if child:IsA("BasePart") then initial[child] = child.CFrame; child.Anchored = true
				elseif jointLike(child) or child:IsA("WeldConstraint") then
					child.Enabled = false; joints[#joints + 1] = child
					if child:IsA("WeldConstraint") and child.Part0 and child.Part1 then offsets[child] = child.Part0.CFrame:ToObjectSpace(child.Part1.CFrame) end
					if armJoint(child) then baseline[child] = child.Transform end
				end
			end
			local originalGrip = { Part = grip.Part0, C0 = grip.C0, C1 = grip.C1 }
			local state = Pose.Bind(character, tool)
			local context = template.Name .. "/" .. id
			check(state ~= nil, context, "pose could not bind to native rig")
			if not state then character:Destroy(); return end
			local miningTool = family == "Pickaxe" or family == "Universal"
			local idleGraspRotation
			local function project()
				local frames = table.clone(initial)
				-- Pure FK projection: disabled physics joints cannot drag an anchored rig
				-- while a test is assigning or reading its individual part transforms.
				for _ = 1, 8 do
					for _, joint in ipairs(joints) do
						if joint.Part0 and joint.Part1 then
							if offsets[joint] then frames[joint.Part1] = frames[joint.Part0] * offsets[joint]
							else
								local transform = (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and joint.Transform or CFrame.identity
								frames[joint.Part1] = frames[joint.Part0] * joint.C0 * transform * joint.C1:Inverse()
							end
						end
					end
				end
				return frames
			end
			local function observe(label, drawing, idle, drawAge)
				local where = context .. "/" .. label
				report.PoseSamples += 1
				local frames = project()
				for part, frame in pairs(frames) do check(finiteFrame(frame), where, part.Name .. " contains NaN/infinite transform") end
				local leadSide = "Right"
				local palm = gripFrame(character, leadSide, frames)
				local itemGrip = handle:FindFirstChild("ItemGrip")
				local grasp = itemGrip and frames[handle] * itemGrip.CFrame
					or (not tool:GetAttribute("ArtKind") and frames[handle] * originalGrip.C1 or frames[handle])
				check((palm.Position - grasp.Position).Magnitude < .025, where, "lead hand separates from authored item grasp")
				if template.Name == "R15" then
					local elbow, wrist
					for _, joint in ipairs(joints) do
						if joint.Name == leadSide .. "Elbow" then elbow = joint end
						if joint.Name == leadSide .. "Wrist" then wrist = joint end
					end
					check(elbow ~= nil and wrist ~= nil, where, "held arm lacks elbow or wrist joint")
					if elbow and wrist then
						local elbowPoint = (frames[elbow.Part1] * elbow.C1).Position
						local wristPoint = (frames[wrist.Part0] * wrist.C0).Position
						local palmWristPoint = (frames[wrist.Part1] * wrist.C1).Position
						check((wristPoint-palmWristPoint).Magnitude < .025, where, "palm detaches from forearm at wrist")
						if idle then
							local torso = character.UpperTorso
							local forearm = wristPoint-elbowPoint
							local forward = frames[torso].LookVector
							local direction = forearm.Magnitude > .001 and forearm.Unit:Dot(forward) or 0
							local palmAdvance = (palm.Position-elbowPoint):Dot(forward)
							check(direction >= .5, where, string.format("held forearm hangs instead of facing forward (forward cosine %.3f)",direction))
							check(palmAdvance >= .5*forearm.Magnitude, where,
								string.format("held palm advances only %.3f studs ahead of elbow; needs %.3f",palmAdvance,.5*forearm.Magnitude))
						end
					end
				end
				if family ~= "Bow" then
					local relative = palm:ToObjectSpace(grasp).Rotation
					if not idleGraspRotation then idleGraspRotation = relative end
					-- R15 has a wrist and must retain its authored palm-to-tool seating.
					-- R6 has a rigid block arm: judge its swing plane and clearance below.
					if template.Name == "R15" then
						local _, drift = idleGraspRotation:ToObjectSpace(relative):ToAxisAngle()
						check(math.abs(drift) < math.rad(5), where, string.format("item rotates %.1f degrees independently of its palm", math.deg(math.abs(drift))))
					end
				end
				if miningTool or family == "Axe" or family == "Sickle" then
					local torso = character:FindFirstChild("UpperTorso") or character.Torso
					local headAxis = frames[handle].RightVector
					check(math.abs(headAxis:Dot(frames[torso].RightVector)) < .35, where, "cutting head turns crosswise through the torso instead of the forward swing plane")
					if idle then
						check(math.abs(headAxis:Dot(frames[torso].LookVector)) > .75, where, "idle cutting head does not point along avatar forward/back")
					end
					if idle and miningTool then
						local headParts = 0
						for _, part in ipairs(tool:GetDescendants()) do
							if part:IsA("BasePart") and part.Transparency < .95 and initial[handle]:PointToObjectSpace(initial[part].Position).Y > 1.05 then
								headParts += 1
								check(not boxesOverlap(frames[part], part.Size, frames[torso], torso.Size - Vector3.new(.12, .12, .12)), where,
									part.Name .. " overlaps the torso while the mining tool is idle")
							end
						end
						check(headParts > 0, where, "mining tool contains no geometry in its authored head region")
					end
				end
				if family == "Spear" or family == "Hammer" then
					local haft = tool:FindFirstChild("Haft")
					if haft then
						local support = gripFrame(character, "Left", frames).Position
						local localPoint = frames[haft]:PointToObjectSpace(support)
						-- The generated cylindrical haft's long axis is local X.
						local closest = Vector3.new(math.clamp(localPoint.X, -haft.Size.X / 2, haft.Size.X / 2), 0, 0)
						check((localPoint - closest).Magnitude < .4, where, string.format("supporting hand floats %.3f studs off the haft", (localPoint - closest).Magnitude))
					end
				end
				if family == "Bow" then
					check(grip.Part0 == (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")), where, "bow not attached to right lead hand")
					local strings, shaft = {}, tool:FindFirstChild("NockedShaft")
					for _, p in ipairs(tool:GetChildren()) do if p:IsA("BasePart") and p:GetAttribute("BowMotion") == "String" then strings[#strings + 1] = p end end
					check(#strings == 2 and shaft ~= nil, where, "bow lacks two physical string halves or nocked arrow")
					if shaft then
						local visible = shaft.Transparency < .99 and shaft.LocalTransparencyModifier < .99
						check(visible == drawing, where, drawing and "drawn arrow is hidden" or "released/cancelled arrow remains visible")
						if idle then
							local torso = character:FindFirstChild("UpperTorso") or character.Torso
							local freePalm = gripFrame(character, "Left", frames).Position
							local nock = frames[shaft]:PointToWorldSpace(Vector3.new(0,-shaft.Size.Y/2,0))
							check(freePalm.Y < frames[torso].Position.Y-torso.Size.Y*.2, where, "empty left arm stays raised while bow is idle")
							check((freePalm-nock).Magnitude > torso.Size.X*.3, where, "idle left hand remains on the bowstring")
						end
						if drawing then
							local drawHand = gripFrame(character, "Left", frames).Position
							local nock = frames[shaft]:PointToWorldSpace(Vector3.new(0, -shaft.Size.Y / 2, 0))
							-- The drawing hand approaches a relaxed string before grasping it.
							-- After that approach, the physical nock must remain in the hand.
							if drawAge and drawAge >= .25 then
								check((nock - drawHand).Magnitude < .035, where, "draw hand separates from arrow nock after approach")
							end
							for _, stringPart in ipairs(strings) do
								local cf = frames[stringPart]
								local a = cf:PointToWorldSpace(Vector3.new(0, stringPart.Size.Y / 2, 0))
								local b = cf:PointToWorldSpace(Vector3.new(0, -stringPart.Size.Y / 2, 0))
								check(math.min((a - nock).Magnitude, (b - nock).Magnitude) < .035, where, "physical string does not meet arrow nock")
							end
						end
					end
				end
				if idle then
					local head = character.Head
					for _, part in ipairs(tool:GetDescendants()) do
						if part:IsA("BasePart") and part.Transparency < .95 and part.LocalTransparencyModifier < .95 then
							local p = frames[part]:PointToObjectSpace(frames[head].Position)
							local half = part.Size / 2
							local closest = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
							-- Deep head-core penetration, not grazing an oversized bounding box.
							check((p - closest).Magnitude > math.min(head.Size.X, head.Size.Y, head.Size.Z) * .2, where, part.Name .. " crosses the head core while idle")
						end
					end
				end
				return frames
			end
			local function update(now, drawStart, actionStart, kind, reduced, aim)
				state:Restore()
				-- Mimic an Animator supplying a fresh (non-identity) baseline each frame.
				for joint, transform in pairs(baseline) do joint.Transform = transform end
				state:Update(1 / 60, now, drawStart, actionStart, kind, aim or Vector3.new(0, 0, -1), reduced)
			end
			for i = 1, 90 do update(10 + i / 60) end
			local idleFrames = observe("idle", false, true)
			if family == "Bow" then
				-- Free camera motion must not rotate a lowered bow or either idle arm.
				for index, aim in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.new(0, .9, -.3).Unit }) do
					for i = 1, 45 do update(12 + index + i / 60, nil, nil, nil, false, aim) end
					local frames = observe("idle-camera-" .. index, false, true)
					check(nearFrame(frames[handle], idleFrames[handle], .005), context .. "/idle-camera", "camera aim twists or moves the lowered bow")
					for _, side in ipairs({ "Left", "Right" }) do
						check(nearFrame(gripFrame(character, side, frames), gripFrame(character, side, idleFrames), .005), context .. "/idle-camera", "camera aim twists the idle " .. side .. " hand")
					end
				end
				local torso = character:FindFirstChild("UpperTorso") or character.Torso
				local scale = math.clamp(torso.Size.X / 2, .65, 1.6)
				local aim = Vector3.new(0, 0, -1)
				local idleLead = gripFrame(character, "Right", idleFrames).Position
				local shaft = tool:FindFirstChild("NockedShaft")
				local restNock = shaft and idleFrames[handle]:PointToObjectSpace(idleFrames[shaft]:PointToWorldSpace(Vector3.new(0,-shaft.Size.Y/2,0)))
				local rigidShoulder, rigidReach, availableExtension
				if template.Name == "R6" then
					for _, joint in ipairs(joints) do if joint.Name == "Right Shoulder" then rigidShoulder = joint; break end end
					if rigidShoulder then
						local shoulder = (idleFrames[rigidShoulder.Part0]*rigidShoulder.C0).Position
						rigidReach = (idleLead-shoulder).Magnitude
						availableExtension = math.max(0,rigidReach-(idleLead-shoulder):Dot(aim))
					end
				end
				local reachedDraw = false
				for i = 1, 96 do
					update(20 + i / 60, 20)
					local frames = project()
					local lead = gripFrame(character, "Right", frames).Position
					local shaft = tool:FindFirstChild("NockedShaft")
					if shaft then
						local nock = frames[shaft]:PointToWorldSpace(Vector3.new(0, -shaft.Size.Y / 2, 0))
						local forwardTravel, pullback = (lead - idleLead):Dot(aim), (lead - nock):Dot(aim)
						if i <= 12 and restNock then
							check((frames[handle]:PointToObjectSpace(nock)-restNock).Magnitude < .035, context .. "/approach-" .. i,
								"string leaves its relaxed position while the drawing hand is still approaching")
						end
						if not reachedDraw and pullback > .3 * scale then
							reachedDraw = true
							local minimumAdvance = availableExtension and availableExtension*.7 or .35*scale
							check(forwardTravel >= minimumAdvance, context .. "/raise-before-draw",
								string.format("at %.3fs string pulls %.2f studs back after the lead hand has advanced only %.2f", i/60, pullback, forwardTravel))
						end
						if i == 96 then
							if rigidShoulder and rigidReach then
								local shoulder = (frames[rigidShoulder.Part0]*rigidShoulder.C0).Position
								local extension = (lead-shoulder):Dot(aim)/rigidReach
								check(extension >= .95, context .. "/full-draw", string.format("rigid bow arm reaches only %.1f%% forward extension",extension*100))
							else
								check(forwardTravel >= .65 * scale, context .. "/full-draw", string.format("bow lead hand advances only %.2f studs from idle", forwardTravel))
							end
							check(pullback >= .35 * scale, context .. "/full-draw", string.format("nock is not behind lead grip along aim (%.2f studs)", pullback))
						end
					end
					if i == 6 or i == 30 or i == 78 or i == 96 then observe("draw-" .. i, true, false, i/60) end
				end
				check(reachedDraw, context .. "/draw", "string never enters a substantial physical pullback")
				for i = 1, 45 do update(21.6 + i / 60, nil, 21.6, "Release"); if i == 1 or i == 8 then observe("release-" .. i, false, false) end end
				for i = 1, 45 do update(23 + i / 60, 23) end
				-- The render pipeline restores its inputs before Animator evaluates.
				-- Check that boundary separately from the deliberate relaxed output pose.
				state:Restore()
				for joint, transform in pairs(baseline) do
					check(nearFrame(joint.Transform, transform, .002), context .. "/cancel-before-Animator", "previous pose contaminates Animator input: " .. joint.Name)
				end
				for i = 1, 90 do
					update(23.75 + i / 60)
					if i == 1 then observe("cancel-first-frame", false, false) end
				end
				local frames = observe("cancel-settled", false, true)
				local freePalm = gripFrame(character, "Left", frames).Position
				local torso = character:FindFirstChild("UpperTorso") or character.Torso
				check(freePalm.Y < frames[torso].Position.Y - torso.Size.Y * .2, context .. "/cancel", "free hand remains raised instead of resting below the torso")
				local shaft = tool:FindFirstChild("NockedShaft")
				if shaft then
					local nock = frames[shaft]:PointToWorldSpace(Vector3.new(0, -shaft.Size.Y / 2, 0))
					check((freePalm - nock).Magnitude > torso.Size.X * .3, context .. "/cancel", "free hand remains attached to the relaxed string")
				end
			else
				local def = Catalog.Gear[id]
				local duration = def and def.AttackCycle or .9
				tool:SetAttribute("Cooldown", duration)
				local kind = def and (def.Kind == "Tool" and "Harvest" or "Attack") or "Use"
				local fractions, nextSample = { .05, .25, .5, .8, 1.1 }, 1
				for i = 1, math.ceil(duration * 1.1 * 60) do
					local age = i / 60
					update(30 + age, nil, 30, kind)
					if fractions[nextSample] and age + .0001 >= duration * fractions[nextSample] then
						observe(kind .. "-" .. fractions[nextSample], false, false)
						nextSample += 1
					end
				end
			end
			-- Destruction while active must recover all six R15 or two R6 arm joints.
			update(40.9, family == "Bow" and 40 or nil, family ~= "Bow" and 40.7 or nil, "Attack", true)
			state:Destroy()
			for joint, transform in pairs(baseline) do check(nearFrame(joint.Transform, transform, .002), context .. "/destroy", "original Animator transform not restored: " .. joint.Name) end
			check(grip.Part0 == originalGrip.Part and nearFrame(grip.C0, originalGrip.C0, .002) and nearFrame(grip.C1, originalGrip.C1, .002), context .. "/destroy", "grip not restored")
			character:Destroy()
		end
		for index, id in ipairs(ids) do
			local definition = Catalog.Gear[id]
			local entry = { Id = id, Grade = definition and definition.Grade or 1 }
			local success, tool = pcall(production.CreateTool, production, entry)
			check(success and typeof(tool) == "Instance", "inventory/" .. id, "constructor returned " .. tostring(tool))
			if success and typeof(tool) == "Instance" then
				local valid = inspectTool(tool, "inventory/" .. id)
				local family = Presentation.Family(tool)
				report.Families[family] = (report.Families[family] or 0) + 1
				if valid then
					for _, rig in ipairs(rigTemplates) do
						local posed, err = pcall(poseItem, rig, tool, id, family)
						check(posed, rig.Name .. "/" .. id, "pose exception: " .. tostring(err))
					end
				end
				tool:Destroy()
			end
			report.Items += 1
			if index % 12 == 0 then task.wait() end
		end
	end, debug.traceback)
	if not ok then check(false, "harness", fatal) end
	for i = #cleanup, 1, -1 do cleanup[i]:Destroy() end
	report.Passed = report.FailureCount == 0
	report.Warnings[#report.Warnings + 1] = "Geometric/offline pose checks do not replace live input, animation scheduling, streaming or multiplayer replication checks."
	return report
end
