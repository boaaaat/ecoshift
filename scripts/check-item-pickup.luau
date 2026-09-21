-- Run as a ModuleScript from a server Script during a Studio play session.
-- Uses real drop physics, the server pickup loop, and Humanoid movement.
return function(player, report)
	assert(game:GetService("RunService"):IsStudio(), "Studio only")
	local services = game.ServerScriptService.Services
	local drops = require(services.ItemDropService)
	local inventory = require(services.InventoryService)
	local instances = require(game.ReplicatedStorage.Shared.ItemInstance)
	local items = require(game.ReplicatedStorage.Shared.Items.ItemDatabase)
	local character = assert(player.Character)
	local root, humanoid = character.HumanoidRootPart, character.Humanoid
	assert(drops._worldActive and humanoid.Health > 0, "Wait for the expedition to finish loading")
	local originalPivot = character:GetPivot()
	local originalInventory = instances.Copy(inventory._inventories[player])
	local originalSpeed = humanoid.WalkSpeed
	local originalOwner, automaticOwner = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
	local spawned, results = {}, {}
	local floor = Instance.new("Part")
	floor.Name, floor.Size, floor.Position = "PickupRegressionFloor", Vector3.new(100, 2, 60), Vector3.new(0, 220, 0)
	floor.Anchored, floor.Parent = true, workspace
	local function record(name, passed, details)
		local result = {Name = name, Passed = passed, Details = details}
		table.insert(results, result)
		if report then report(result) end
	end
	local function waitUntil(predicate, seconds)
		local deadline = os.clock() + seconds
		repeat
			if predicate() then return true end
			task.wait(.05)
		until os.clock() >= deadline
		return predicate()
	end
	local function resetInventory()
		inventory._inventories[player] = {Hotbar = {}, Storage = {}, Equipment = {}, Accessory = {}, StorageCapacity = 18}
		inventory:Sync(player)
	end
	local function moveTo(position)
		root.CFrame = CFrame.new(position)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		humanoid:MoveTo(position)
	end
	local function spawn(id, count, position, options)
		local drop = assert(drops:SpawnDrop(id, count, position, options), "Could not spawn " .. id)
		drop.Name = "PickupRegression_" .. tostring(#spawned + 1)
		-- Keep names only: retaining the Instance masks weak-registry failures.
		table.insert(spawned, drop.Name)
		return drop
	end
	local function groundCase(id, surface, name)
		resetInventory()
		moveTo(surface + Vector3.new(-18, 4, 0))
		task.wait(.5)
		local drop = spawn(id, 1, surface + Vector3.new(0, 7, 0))
		local entry = drops:CaptureWorldState()
		local expectedUid
		for _, state in ipairs(entry) do if state.Id == id and state.Entry then expectedUid = state.Entry.Uid end end
		local dropName = drop.Name
		drop = nil
		-- Roblox does not expose forced GC. Allocation pressure and a weak
		-- sentinel verify a collection cycle while no test owns the drop.
		local sentinel = setmetatable({}, {__mode = "v"})
		do local marker = {}; sentinel[1] = marker end
		local collected = waitUntil(function()
			local garbage = {}
			for index = 1, 20000 do garbage[index] = {index, string.rep("g", 128)} end
			return sentinel[1] == nil
		end, 8)
		task.wait(2.5) -- The item must land before the character approaches.
		drop = assert(workspace.ItemDrops:FindFirstChild(dropName), "Drop disappeared before approach")
		local tracked = false
		for _, state in ipairs(drops:CaptureWorldState()) do
			if state.Id == id and state.Entry and state.Entry.Uid == expectedUid and state.LifetimeRemaining < 599 then tracked = true end
		end
		record("Retained after GC: " .. name, collected and tracked, {CollectionObserved = collected, EntryAndLifetimePreserved = tracked})
		local settled = drop.Parent and drop.PrimaryPart.AssemblyLinearVelocity.Magnitude < .5
		local landingPosition = drop.Parent and drop.PrimaryPart.Position
		-- Physics can roll an item down a slope; approach its landed position.
		humanoid:MoveTo(landingPosition + Vector3.new(0, 2, 0))
		local pickedUp = waitUntil(function() return not drop.Parent end, 4)
		local identityPreserved = expectedUid == nil
		for _, bag in ipairs({inventory._inventories[player].Hotbar, inventory._inventories[player].Storage}) do
			for _, item in pairs(bag) do if item.Uid == expectedUid then identityPreserved = true end end
		end
		record(name, settled and pickedUp and inventory:TotalCount(player, id) == 1 and identityPreserved, {
			SettledBeforeApproach = settled == true, PickedUp = pickedUp, Count = inventory:TotalCount(player, id),
			IdentityPreserved = identityPreserved, LandingPosition = tostring(landingPosition), Floor = humanoid.FloorMaterial.Name,
			CharacterPosition = tostring(root.Position),
		})
		if drop.Parent then drop:Destroy() end
	end
	local ok, failure = xpcall(function()
		root:SetNetworkOwner(nil)
		humanoid.WalkSpeed = 16
		local surface = floor.Position + Vector3.new(0, 1, 0)
		for _, id in ipairs({"Stone", "Wood", "Arrow", "Harvester", "CrystalStaff"}) do
			groundCase(id, surface, "Settled on floor: " .. id)
		end
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {workspace.Terrain}
		params.IgnoreWater = true
		local terrain = assert(workspace:Raycast(originalPivot.Position + Vector3.new(12, 40, 0), Vector3.new(0, -100, 0), params), "No terrain near the original spawn")
		groundCase("Stone", terrain.Position, "Settled on terrain: Stone")
		groundCase("Wood", terrain.Position, "Settled on terrain: Wood")
		resetInventory()
		moveTo(surface + Vector3.new(0, 14, 0))
		local airborne = spawn("Stone", 3, root.Position + Vector3.new(0, 1, 0))
		local caught = waitUntil(function() return not airborne.Parent end, .4)
		record("Catch before landing", caught and humanoid.FloorMaterial == Enum.Material.Air and inventory:TotalCount(player, "Stone") == 3,
			{PickedUp = caught, Floor = humanoid.FloorMaterial.Name, Count = inventory:TotalCount(player, "Stone")})
		resetInventory()
		moveTo(surface + Vector3.new(-18, 4, 0))
		local inv = inventory._inventories[player]
		local limit = items:Get("Wood").StackSize
		for index = 1, 6 do inv.Hotbar[index] = {Id = "Stone", N = items:Get("Stone").StackSize} end
		for index = 1, 18 do inv.Storage[index] = {Id = "Stone", N = items:Get("Stone").StackSize} end
		inv.Storage[1] = {Id = "Wood", N = limit - 2}
		inventory:Sync(player)
		local partial = spawn("Wood", 5, surface + Vector3.new(0, 7, 0))
		task.wait(2.5)
		humanoid:MoveTo(surface + Vector3.new(0, 3, 0))
		waitUntil(function() return partial:GetAttribute("Count") == 3 end, 4)
		record("Partial stack leaves remainder", partial.Parent ~= nil and partial:GetAttribute("Count") == 3 and inventory:TotalCount(player, "Wood") == limit,
			{Remaining = partial:GetAttribute("Count"), InventoryCount = inventory:TotalCount(player, "Wood")})
		task.wait(.5)
		record("Full inventory leaves drop intact", partial.Parent ~= nil and partial:GetAttribute("Count") == 3, {Remaining = partial:GetAttribute("Count")})
		inv.Storage[2] = nil
		inventory:Sync(player)
		local retried = waitUntil(function() return not partial.Parent end, 2)
		record("Pickup retries after freeing space", retried and inventory:TotalCount(player, "Wood") == limit + 3,
			{PickedUp = retried, InventoryCount = inventory:TotalCount(player, "Wood")})
	end, debug.traceback)
	for _, name in ipairs(spawned) do
		local drop = workspace.ItemDrops:FindFirstChild(name)
		if drop then drop:Destroy() end
	end
	inventory._inventories[player] = originalInventory
	inventory:Sync(player)
	if root.Parent then
		character:PivotTo(originalPivot)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		humanoid.WalkSpeed = originalSpeed
		humanoid:MoveTo(root.Position)
		if automaticOwner then root:SetNetworkOwnershipAuto() else root:SetNetworkOwner(originalOwner) end
	end
	floor:Destroy()
	if not ok then record("Test execution", false, {Error = failure}) end
	return results
end
