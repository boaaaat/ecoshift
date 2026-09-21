-- Local procedural arm posing for both Roblox character rigs. Only arm joints and
-- the equipped grip are overridden; locomotion, root motion and damage are untouched.
local Presentation = require(script.Parent.ItemPresentation)
local BowRig = require(script.Parent.BowRig)
local Pose = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles

local function findMotor(character, name)
	for _, child in ipairs(character:GetDescendants()) do
		if (child:IsA("Motor6D") or child:IsA("AnimationConstraint")) and child.Name == name then return child end
	end
end

local function arm(character, side)
	local shoulder = findMotor(character, side .. "Shoulder") or findMotor(character, side .. " Shoulder")
	if not shoulder or not shoulder.Part0 or not shoulder.Part1 then return nil end
	local elbow, wrist = findMotor(character, side .. "Elbow"), findMotor(character, side .. "Wrist")
	local hand = wrist and wrist.Part1 or shoulder.Part1
	local attach = hand:FindFirstChild(side .. "GripAttachment")
	return { Shoulder = shoulder, Elbow = elbow, Wrist = wrist, Hand = hand,
		Grip = attach and attach.CFrame or CF(0, -hand.Size.Y * .5, 0) }
end

local function boneFrame(start, finish, attachment, right, endpoint)
	local delta = finish - start
	local up = delta.Magnitude > .001 and -delta.Unit or Vector3.yAxis
	local x = right - up * right:Dot(up)
	if x.Magnitude < .001 then x = Vector3.zAxis:Cross(up) end
	x = x.Unit
	local rotation = CFrame.fromMatrix(Vector3.zero, x, up, x:Cross(up))
	-- R6 shoulders sit on the inner edge of the block arm, not its top center.
	-- Align the actual attachment-to-grip vector rather than assuming a -Y bone.
	local localUp = -(endpoint - attachment.Position).Unit
	local localX = Vector3.xAxis - localUp * Vector3.xAxis:Dot(localUp)
	if localX.Magnitude < .001 then localX = Vector3.zAxis:Cross(localUp) end
	localX = localX.Unit
	rotation *= CFrame.fromMatrix(Vector3.zero, localX, localUp, localX:Cross(localUp)):Inverse()
	return CF(start - rotation:VectorToWorldSpace(attachment.Position)) * rotation
end

function Pose.Bind(character, tool)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local handle = tool:FindFirstChild("Handle")
	if not torso or not handle or not handle:IsA("BasePart") then return nil end
	local left, right = arm(character, "Left"), arm(character, "Right")
	if not left or not right then return nil end
	local grip
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("JointInstance") and child.Part1 == handle and child.Part0 ~= handle then grip = child; break end
	end
	if not grip then return nil end
	local state = { Tool = tool, Family = Presentation.Family(tool), Alpha = 0, Draw = 0, Raise = 0, Joints = {},
		Grip = grip, GripPart = grip.Part0, GripC0 = grip.C0, GripC1 = grip.C1 }
	for _, limb in ipairs({ left, right }) do
		for _, key in ipairs({ "Shoulder", "Elbow", "Wrist" }) do
			local joint = limb[key]
			if joint then state.Joints[joint] = { C0 = joint.C0, Transform = joint.Transform } end
		end
	end
	if tool:GetAttribute("ArticulatedBow") then state.Bow = BowRig.Bind(tool) end
	function state:Restore()
		for joint, base in pairs(self.Joints) do
			if joint.Parent then joint.Transform = base.Transform end
		end
		if grip.Parent then grip.Part0, grip.C0, grip.C1 = self.GripPart, self.GripC0, self.GripC1 end
	end
	function state:Destroy()
		self:Restore()
		if self.Bow then self.Bow:Destroy() end
	end
	local function placeJoint(joint, parentFrame, frame, weight)
		local base = state.Joints[joint]
		base.Transform = joint.Transform
		local target = base.C0:Inverse() * parentFrame:ToObjectSpace(frame) * joint.C1
		joint.Transform = base.Transform:Lerp(target, weight)
		return parentFrame * base.C0 * joint.Transform * joint.C1:Inverse()
	end
	local function solve(limb, point, rotation, pole, weight)
		local shoulder = limb.Shoulder
		local start = (shoulder.Part0.CFrame * state.Joints[shoulder].C0).Position
		local reference = torso.CFrame.RightVector
		if not limb.Elbow or not limb.Wrist then
			local length = (limb.Grip.Position - shoulder.C1.Position).Magnitude
			local delta = point - start
			local finish = start + (delta.Magnitude > .001 and delta.Unit or -torso.CFrame.UpVector) * length
			local upper = boneFrame(start, finish, shoulder.C1, reference, limb.Grip.Position)
			return placeJoint(shoulder, shoulder.Part0.CFrame, upper, weight) * limb.Grip
		end
		local elbow, wrist = limb.Elbow, limb.Wrist
		local hand = CF(point) * rotation * limb.Grip:Inverse()
		local target = (hand * wrist.C1).Position
		local a = (state.Joints[elbow].C0.Position - shoulder.C1.Position).Magnitude
		local b = (state.Joints[wrist].C0.Position - elbow.C1.Position).Magnitude
		local delta = target - start
		local direction = delta.Magnitude > .001 and delta.Unit or -torso.CFrame.UpVector
		local distance = math.clamp(delta.Magnitude, math.abs(a - b) + .001, math.max(.002, a + b - .001))
		local projected = pole - direction * pole:Dot(direction)
		if projected.Magnitude < .001 then projected = torso.CFrame.RightVector:Cross(direction) end
		local along = (a * a + distance * distance - b * b) / (2 * distance)
		local bend = math.sqrt(math.max(0, a * a - along * along))
		local middle = start + direction * along + projected.Unit * bend
		local finish = start + direction * distance
		local upper = placeJoint(shoulder, shoulder.Part0.CFrame, boneFrame(start, middle, shoulder.C1, reference, state.Joints[elbow].C0.Position), weight)
		local lower = placeJoint(elbow, upper, boneFrame(middle, finish, elbow.C1, reference, state.Joints[wrist].C0.Position), weight)
		-- Keep the wrist anchor attached even when an oversized avatar exceeds the reach.
		local handRotation = rotation * limb.Grip:Inverse().Rotation
		hand = CF(finish - handRotation:VectorToWorldSpace(wrist.C1.Position)) * handRotation
		return placeJoint(wrist, lower, hand, weight) * limb.Grip
	end
	local function supportPoint(limb, frame, desired, handRotation)
		local joint = limb.Shoulder
		local shoulder = (joint.Part0.CFrame * state.Joints[joint].C0).Position
		local length = (limb.Grip.Position - joint.C1.Position).Magnitude
		local wristOffset = Vector3.zero
		if limb.Elbow and limb.Wrist then
			length = (state.Joints[limb.Elbow].C0.Position - joint.C1.Position).Magnitude
				+ (state.Joints[limb.Wrist].C0.Position - limb.Elbow.C1.Position).Magnitude - .01
			wristOffset = (handRotation * limb.Grip:Inverse()):PointToWorldSpace(limb.Wrist.C1.Position)
		end
		local delta, axis = frame.Position + wristOffset - shoulder, frame.UpVector
		local center = -delta:Dot(axis)
		local radius = length * length - (delta + axis * center).Magnitude ^ 2
		if radius >= 0 then
			local reach = math.sqrt(radius)
			local a, b = center - reach, center + reach
			if limb.Elbow then desired = math.clamp(desired, a, b)
			else desired = math.abs(a - desired) < math.abs(b - desired) and a or b end
		else
			-- A fixed forward socket may sit beyond the other arm's reach during a
			-- thrust. Slide that hand along the real shaft toward its nearest point.
			desired = center
		end
		return frame:PointToWorldSpace(V(0, math.clamp(desired, -.45, 1.1), 0))
	end
	local function restGrip(limb)
		local frame=limb.Shoulder.Part0.CFrame * state.Joints[limb.Shoulder].C0 * limb.Shoulder.C1:Inverse()
		for _,key in ipairs({"Elbow","Wrist"}) do
			local joint=limb[key]
			if joint then frame *= state.Joints[joint].C0 * joint.C1:Inverse() end
		end
		return frame * limb.Grip
	end
	local function readyGrip(limb)
		local shoulder = limb.Shoulder
		local upper = shoulder.Part0.CFrame * state.Joints[shoulder].C0 * shoulder.C1:Inverse()
		if limb.Elbow and limb.Wrist then
			local elbow = (upper * state.Joints[limb.Elbow].C0).Position
			local forearm = (state.Joints[limb.Wrist].C0.Position-limb.Elbow.C1.Position).Magnitude
			local palm = (limb.Wrist.C1.Position-limb.Grip.Position).Magnitude
			return elbow + torso.CFrame.LookVector * (forearm+palm)*.96 + torso.CFrame.UpVector*.08
		end
		-- The rigid R6 arm rotates forward as a whole; it has no elbow to bend.
		local start = (shoulder.Part0.CFrame * state.Joints[shoulder].C0).Position
		local length = (limb.Grip.Position-shoulder.C1.Position).Magnitude
		return start + (torso.CFrame.LookVector*.8-torso.CFrame.UpVector*.6)*length
	end
	local function relax(limb, weight)
		local frame=limb.Shoulder.Part0.CFrame
		for _,key in ipairs({"Shoulder","Elbow","Wrist"}) do
			local joint=limb[key]
			if joint then
				frame=placeJoint(joint,frame,frame * state.Joints[joint].C0 * joint.C1:Inverse(),weight)
			end
		end
	end
	function state:Update(dt, now, drawStarted, actionStarted, actionKind, aim, reducedMotion)
		self.Alpha += (1 - self.Alpha) * math.min(1, dt * 14)
		local family = self.Family
		local drawing = drawStarted ~= nil
		-- Present the bow first, then pull the string. Charging still completes at 1.3s.
		local desiredDraw = drawing and math.clamp((now - drawStarted - .2) / 1.1, 0, 1) or 0
		self.Draw += (desiredDraw - self.Draw) * math.min(1, dt * (drawing and 18 or 38))
		local age = actionStarted and now - actionStarted or math.huge
		local cycle = math.clamp(tool:GetAttribute("Cooldown") or .65, .22, 1.3)
		local u = math.clamp(age / cycle, 0, 1)
		local stroke = math.sin(u * math.pi)
		local scale = math.clamp(torso.Size.X / 2, .65, 1.6)
		local base = torso.CFrame
		local forward = aim and aim.Magnitude > .001 and aim.Unit or base.LookVector
		local localAim = base:VectorToObjectSpace(forward)
		local pitch = math.clamp(math.asin(math.clamp(localAim.Y, -1, 1)), -.7, .7)
		local yaw = math.clamp(math.atan2(-localAim.X, -localAim.Z), -.65, .65)
		local facing = base.Rotation * A(pitch, yaw, 0)
		if not drawing and age >= cycle then facing=base.Rotation end
		local idleRight=base:PointToObjectSpace(readyGrip(right))/scale
		local position, rotation = idleRight, base.Rotation * A(-.18, 0, -.3)
		local hand = right
		local weight = self.Alpha
		if family == "Bow" then
			hand = right
			local desiredRaise = drawing and 1 or math.clamp(1 - age / .5, 0, 1)
			self.Raise += (desiredRaise - self.Raise) * math.min(1, dt * 14)
			local raised = self.Raise
			local shoulder = (right.Shoulder.Part0.CFrame * self.Joints[right.Shoulder].C0).Position
			local reach = (right.Grip.Position - right.Shoulder.C1.Position).Magnitude
			if right.Elbow and right.Wrist then
				reach = (self.Joints[right.Elbow].C0.Position-right.Shoulder.C1.Position).Magnitude
					+ (self.Joints[right.Wrist].C0.Position-right.Elbow.C1.Position).Magnitude
					+ (right.Wrist.C1.Position-right.Grip.Position).Magnitude
			end
			-- Size the extension from actual bones, not torso width. Narrow avatars
			-- otherwise held the bow against their chest despite having long arms.
			local extended = shoulder + facing.LookVector * (reach-.06) - base.UpVector*.06
			position = idleRight:Lerp(base:PointToObjectSpace(extended)/scale, raised)
			rotation = (base.Rotation * A(0,math.pi/2,0) * A(0,0,-.18)):Lerp(facing * A(0,math.pi/2,0),raised)
		elseif family == "Spear" then
			position = V(.45,-.6,-.75):Lerp(V(0, -.25, -1.1),stroke)
			rotation = (base.Rotation*A(-.6,0,.4)):Lerp(facing*A(-math.pi/2,0,.1),stroke)
		elseif family == "Staff" then
			position = idleRight:Lerp(V(1, .05, -1),stroke)
			rotation = facing * A(-.18 - stroke * .55, 0, -.12)
		elseif family == "Sword" or family == "Dagger" then
			position = idleRight:Lerp(V(.1,.3,-1.35),stroke)
			rotation = base.Rotation * A(-.25 - stroke * 1.4, .2, -.35 + math.sin(u * math.pi * 2) * .9)
		elseif family == "Sickle" then
			position = idleRight:Lerp(V(1,.1,-1.25),stroke)
			rotation = base.Rotation * A(-.25 - stroke * 1.3,0,0) * A(0,-math.pi/2,0)
		elseif family == "Pickaxe" or family == "Universal" then
			-- Keep the head in a fore/aft plane outside the right side of the torso.
			-- A lateral head and independently rotated wrist made the old pose clip the arm.
			local ready = idleRight
			local raised = V(1.4, .25, -.85)
			local struck = V(1.4, -.9, -1.45)
			local pitch
			local function ease(t) return t*t*(3-2*t) end
			if age >= cycle then position, pitch = ready, -.18
			elseif u < .3 then
				local t = ease(u/.3); position, pitch = ready:Lerp(raised,t), -.18 + .73*t
			elseif u < .62 then
				local t = ease((u-.3)/.32); position, pitch = raised:Lerp(struck,t), .55 - 1.8*t
			else
				local t = ease((u-.62)/.38); position, pitch = struck:Lerp(ready,t), -1.25 + 1.07*t
			end
			rotation = base.Rotation * A(pitch, 0, 0) * A(0, -math.pi/2, 0)
		elseif family == "Axe" or family == "Hammer" then
			local lift = u < .32 and math.sin(u / .32 * math.pi / 2) or math.cos((u - .32) / .68 * math.pi / 2)
			if age >= cycle then lift = 0 end
			position = idleRight:Lerp(V(1.15,.45,-1.25),lift)
			rotation = base.Rotation * A(-.25 + lift * .65 - (u > .32 and stroke * 1.8 or 0), 0, 0) * A(0,-math.pi/2,0)
			if family=="Hammer" then
				position=V(.35,-.95,-.8):Lerp(V(.1,.3,-1.05),lift)
				rotation=base.Rotation*A(-1.05+lift*1.1-(u>.32 and stroke*1.2 or 0),0,.45)
			end
		elseif family == "Bucket" then
			position, rotation = idleRight, base.Rotation
		elseif family == "Food" or family == "Drink" or family == "Medicine" or (family == "Carry" and actionKind == "Use") then
			local use = age < .9 and math.sin(math.clamp(age / .9, 0, 1) * math.pi) or 0
			position = idleRight:Lerp(V(.3, .85, -.72), use)
			rotation = base.Rotation * A(family == "Drink" and -.6 * use or .1, 0, .25 * use)
		end
		local point = base:PointToWorldSpace(position * scale)
		local handRotation = restGrip(hand).Rotation:Lerp(facing * A(math.pi / 2, 0, 0),family=="Bow" and self.Raise or stroke)
		if family == "Pickaxe" or family == "Universal" then
			-- Grip +Y follows the shaft; yaw keeps the pick in the swing plane while
			-- the wrist remains square to the forearm instead of rolling sideways.
			handRotation = rotation * A(0, math.pi/2, 0)
		elseif family == "Bow" then
			handRotation = (base.Rotation*A(0,0,-.18)):Lerp(facing, self.Raise)
		elseif family == "Axe" or family == "Sickle" then
			-- These heads cut in their local XY plane; seat the palm on the shaft
			-- with one fixed quarter-turn throughout the swing.
			handRotation = rotation * A(0,math.pi/2,0)
		else
			-- The palm follows the authored grasp, including tilting a drink or
			-- thrusting a spear. Independent world rotations made handles spin in it.
			handRotation = rotation
		end
		local pole = base:VectorToWorldSpace(V(hand == left and -.8 or .8, -.8, .3))
		local actualGrip = solve(hand, point, handRotation, pole, weight)
		local handleFrame = CF(actualGrip.Position) * rotation
		local itemGrip = handle:FindFirstChild("ItemGrip")
		if itemGrip and itemGrip:IsA("Attachment") then handleFrame *= itemGrip.CFrame:Inverse()
		elseif not tool:GetAttribute("ArtKind") then
			-- Non-generated prefabs retain the authored offset instead of grasping their bounds.
			handleFrame *= self.GripC1:Inverse()
		end
		grip.Part0 = hand.Hand
		local handFrame = actualGrip * hand.Grip:Inverse()
		grip.C0 = handFrame:ToObjectSpace(handleFrame) * grip.C1
		if family == "Bow" then
			local nock = handleFrame:PointToWorldSpace(BowRig.Nock(self.Draw))
			local drawnNock
			if drawing or self.Raise > .01 then
				local recoil = not reducedMotion and actionKind == "Release" and age < .22 and math.sin(age / .22 * math.pi) * .22 or 0
				local target=restGrip(left).Position:Lerp(nock-forward*recoil,self.Raise)
				local drawHand = solve(left, target, restGrip(left).Rotation:Lerp(facing * A(math.pi / 2, 0, 0),self.Raise), base:VectorToWorldSpace(V(-1, .2, .3)), weight)
				-- R6's rigid arm follows an arc. Keep the physical string and arrow
				-- nock on that hand instead of leaving a gap at short draw lengths.
				-- The hand approaches an untouched string while the lead arm extends.
				-- Attaching during that approach pulled the string from the resting hip.
				if drawing and self.Raise >= .95 and self.Draw > 0 then
					drawnNock = handleFrame:PointToObjectSpace(drawHand.Position)
				end
			else relax(left,weight) end
			if self.Bow then self.Bow:Update(self.Draw, drawing, drawnNock) end
		elseif family == "Spear" or family == "Hammer" or (family=="Staff" and stroke>.01) then
			solve(left, supportPoint(left, handleFrame, family == "Spear" and .8 or .65, handRotation), handRotation,
				base:VectorToWorldSpace(V(-1, -.6, .3)), weight)
		end
	end
	return state
end

return Pose
