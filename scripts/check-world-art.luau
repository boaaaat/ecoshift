-- Run through Studio Server/Edit execute_luau after source sync.
-- Builds remain unparented; this never touches players or the active world.
-- Optional factory overrides permit checking freshly compiled module sources.
local overrides = ... or {}
local Shared = game.ReplicatedStorage.Shared
local Catalog = require(Shared.OverhaulCatalog)
local Biomes = require(Shared.OverhaulBiomes)
local Builds = overrides.Builds or require(Shared.Art.OverhaulBuildModels)
local Creatures = overrides.Creatures or require(game.ServerScriptService.Art.OverhaulCreatures)
local Armor = overrides.Armor or require(game.ServerScriptService.Art.ExpeditionArmor)
local result = { Builds = 0, Creatures = 0, ArmorDisplays = 0, ArmorMounts = 0, Parts = 0, Checks = 0, Failures = {} }
local function check(value, message)
	result.Checks += 1
	if not value then table.insert(result.Failures, message) end
end
local function finite(value) return value == value and math.abs(value) < math.huge end
local function finiteFrame(frame)
	for _, value in ipairs({frame:GetComponents()}) do if not finite(value) then return false end end
	return true
end
local function inspect(model, label, mode)
	local parts, visible, graph = {}, 0, {}
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			parts[object] = true; graph[object] = {}; result.Parts += 1
			local size = object.Size
			check(finiteFrame(object.CFrame), label .. ": nonfinite transform " .. object.Name)
			check(finite(size.X) and finite(size.Y) and finite(size.Z) and math.min(size.X,size.Y,size.Z)>0,
				label .. ": invalid size " .. object.Name)
			if object.Transparency < 1 then visible += 1 end
			if object:GetAttribute("ArtDetail") then check(not object.CanCollide, label .. ": colliding optional detail " .. object.Name) end
			if mode == "Build" or mode == "Display" then check(object.Anchored, label .. ": unanchored static part " .. object.Name) end
			if mode == "Creature" and object ~= model.PrimaryPart then
				check(not object.CanCollide and object.Massless, label .. ": physical decorative part " .. object.Name)
			end
		end
	end
	check(visible > 0, label .. ": no visible geometry")
	check(model.PrimaryPart ~= nil and parts[model.PrimaryPart], label .. ": missing primary part")
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
			local a,b = object.Part0,object.Part1
			check(parts[a] and parts[b] and a ~= b, label .. ": invalid joint " .. object.Name)
			if parts[a] and parts[b] then
				table.insert(graph[a], b); table.insert(graph[b], a)
				if object:IsA("Motor6D") then
					local left,right = a.CFrame*object.C0,b.CFrame*object.C1
					check(finiteFrame(object.C0) and finiteFrame(object.C1), label .. ": nonfinite motor " .. object.Name)
					check((left.Position-right.Position).Magnitude < .001 and left.LookVector:Dot(right.LookVector)>.9999,
						label .. ": mismatched motor rest frame " .. object.Name)
					check(type(object:GetAttribute("MotionKind"))=="string", label .. ": missing animation kind " .. object.Name)
				end
			end
		end
	end
	if mode == "Creature" or mode == "Display" then
		local reached,queue = {}, {}
		if model.PrimaryPart then reached[model.PrimaryPart] = true; table.insert(queue,model.PrimaryPart) end
		local i = 1
		while queue[i] do
			for _,neighbor in ipairs(graph[queue[i]] or {}) do
				if not reached[neighbor] then reached[neighbor]=true; table.insert(queue,neighbor) end
			end
			i += 1
		end
		for part in pairs(parts) do check(reached[part],label .. ": detached part " .. part.Name) end
	end
	if mode == "Creature" then
		check(model:FindFirstChildOfClass("Humanoid") ~= nil, label .. ": missing humanoid")
		check(model.PrimaryPart and model.PrimaryPart.CanCollide, label .. ": missing movement collider")
	end
end
local function construct(id, factory, category, mode)
	local model
	local ok,message = pcall(function()
		model = factory()
		check(model ~= nil, category .. "/" .. id .. ": factory returned nil")
		if model then inspect(model,category .. "/" .. id,mode) end
	end)
	if model then model:Destroy() end
	check(ok,category .. "/" .. id .. ": " .. tostring(message))
	result[category] += 1
end
for id in pairs(Catalog.Placeables) do construct(id,function() return Builds.Create(id) end,"Builds","Build") end
for id in pairs(Biomes.Creatures) do construct(id,function() return Creatures.Create(id) end,"Creatures","Creature") end

local bodyDefinitions = {
	R6 = {{"Head",Vector3.new(2,1,1),Vector3.new(0,2.5,0)}, {"Torso",Vector3.new(2,2,1),Vector3.new(0,1,0)},
		{"Left Leg",Vector3.new(1,2,1),Vector3.new(-.5,-1,0)}, {"Right Leg",Vector3.new(1,2,1),Vector3.new(.5,-1,0)}},
	R15 = {{"Head",Vector3.new(1.8,1,1),Vector3.new(0,2.6,0)}, {"UpperTorso",Vector3.new(2,1.6,1),Vector3.new(0,1.3,0)},
		{"LeftUpperLeg",Vector3.new(.9,1.2,1),Vector3.new(-.5,-.35,0)}, {"RightUpperLeg",Vector3.new(.9,1.2,1),Vector3.new(.5,-.35,0)},
		{"LeftFoot",Vector3.new(.9,.5,1.2),Vector3.new(-.5,-1.8,-.15)}, {"RightFoot",Vector3.new(.9,.5,1.2),Vector3.new(.5,-1.8,-.15)}},
}
local slotNumbers = {Head=1,Chest=2,Legs=3,Boots=4}
for id, definition in pairs(Catalog.Gear) do
	if definition.Kind == "Armor" then
		construct(id,function() return Armor.CreateDisplay(id,definition) end,"ArmorDisplays","Display")
		for rigType,bodies in pairs(bodyDefinitions) do
			for _,broken in ipairs({false,true}) do
				local rig,folder = Instance.new("Model"),Instance.new("Folder")
				folder.Parent = rig
				for _,data in ipairs(bodies) do
					local part = Instance.new("Part")
					part.Name,part.Size = data[1],data[2]
					part.CFrame = CFrame.new(17,25,-38)*CFrame.Angles(.1,.8,-.05)*CFrame.new(data[3])
					part.Anchored=true; part.Parent=rig
				end
				local label = "Armor/" .. id .. "/" .. rigType .. (broken and "/Broken" or "/Intact")
				local ok,message = pcall(function()
					Armor.Mount(folder,rig,slotNumbers[definition.Slot],definition.Set,id,broken)
					local count = 0
					for _,part in ipairs(folder:GetChildren()) do
						if part:IsA("BasePart") then
							count += 1; result.Parts += 1
							check(finiteFrame(part.CFrame),label .. ": nonfinite transform " .. part.Name)
							check(not part.CanCollide and not part.CanQuery and not part.CanTouch and part.Massless and not part.Anchored,
								label .. ": physical decoration " .. part.Name)
							local weld = part:FindFirstChildOfClass("WeldConstraint")
							check(weld and weld.Part1==part and weld.Part0 and weld.Part0.Parent==rig,label .. ": detached mount " .. part.Name)
							if broken then check(part.Material~=Enum.Material.Neon,label .. ": broken armor glows " .. part.Name) end
						end
					end
					check(count>0,label .. ": no mounted art")
				end)
				rig:Destroy()
				check(ok,label .. ": " .. tostring(message)); result.ArmorMounts += 1
			end
		end
	end
end
result.Passed = #result.Failures == 0
return result
