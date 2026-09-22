-- WorldGenController.lua
-- Now uses ChunkStreamingService for dynamic chunk loading instead of generating entire world at once.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldGenConfig = require(ReplicatedStorage.Shared.BiomeConfig)
local BiomeService = require(script.Parent.BiomeService)
local ChunkStreamingService = require(script.Parent.ChunkStreamingService)

local Players = game:GetService("Players")
local WorldGenController = {}
WorldGenController._busy = false
WorldGenController._initialized = false
WorldGenController._pendingBiome = nil

function WorldGenController:_generateOverhaul(biomeName)
 self._pendingBiome=biomeName
 if self._busy then return end
 self._busy=true
 task.spawn(function()
  local held={}
  while self._pendingBiome do
   local name=self._pendingBiome;self._pendingBiome=nil
   ReplicatedStorage:SetAttribute("WorldShifting",true)
   local dropService=require(script.Parent.ItemDropService)
   dropService:BeginBiomeShift()
   local frozen=held
   local death=require(script.Parent.DeathService)
   for _,player in ipairs(Players:GetPlayers()) do
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if frozen[player] then continue end
    if root then
     frozen[player]={Root=root,Anchored=root.Anchored,Position=root.Position,WasInterior=player:GetAttribute("InteriorId")~=nil}
     root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero
     player:SetAttribute("WorldPlayerLoading",true)
    elseif player:GetAttribute("IsDead") then
     local record=death._deadPlayers[player]
     if record and record.ragdoll and record.ragdoll.Parent then
      local parts={}
      for _,p in ipairs(record.ragdoll:GetDescendants()) do if p:IsA("BasePart") then parts[p]=p.Anchored;p.Anchored=true end end
      frozen[player]={Corpse=record.ragdoll,Record=record,Parts=parts,Position=record.ragdoll:GetPivot().Position,WasInterior=player:GetAttribute("InteriorId")~=nil}
      death._reviveHolds[player]=nil
     end
    end
   end
   local ok,err=pcall(function()
    local world=require(script.Parent.OverhaulWorldService)
    local ordered={};for player,entry in pairs(frozen) do table.insert(ordered,{Player=player,Entry=entry}) end
    table.sort(ordered,function(a,b)return a.Player.UserId<b.Player.UserId end)
    local ignored={};for _,record in ipairs(ordered) do if record.Entry.Corpse then table.insert(ignored,record.Entry.Corpse) end end
    local arrivals=self._hasGenerated and world:GetCampArrivalPositions(#ordered,ignored) or nil
    -- Move everyone to the existing camp before any event, enemy, terrain or
    -- generated-world mutation becomes visible. Roots stay anchored while the
    -- replacement camp terrain is produced underneath them.
    if arrivals then
     for index,record in ipairs(ordered) do
      local player,entry=record.Player,record.Entry
      if entry.WasInterior then
       local root=entry.Root;local force=root and root:FindFirstChild("MoonGravity");if force then force:Destroy() end
       player:SetAttribute("InteriorId",nil);player:SetAttribute("MapLayer","Surface")
      end
      local arrival=arrivals[index]
      if entry.Root and entry.Root.Parent and player.Character then
       player.Character:PivotTo(CFrame.new(arrival)*player.Character:GetPivot().Rotation)
       entry.Root.AssemblyLinearVelocity=Vector3.zero
      elseif entry.Corpse and entry.Corpse.Parent then
       entry.Corpse:PivotTo(CFrame.new(arrival)*entry.Corpse:GetPivot().Rotation)
       entry.Record.deathPosition=arrival
      end
     end
    end
    if self._hasGenerated then require(script.Parent.EventService):EndAll("BiomeShift") end
    local enemies=workspace:FindFirstChild("Enemies")
    if enemies then for _,model in ipairs(enemies:GetChildren()) do if not model:GetAttribute("InteriorId") then model:Destroy() end end end
    world:Generate(name)
    dropService:CompleteBiomeShift(world)
    if self._hasGenerated then require(script.Parent.BuildService):RemoveBiomeShiftLights() end
    local function aboveLand(position)
     local minimumY=world:GetHeight(position.X,position.Z)+3.2
     if position.Y>=minimumY then return position end
     return Vector3.new(position.X,minimumY,position.Z)
    end
    for index,record in ipairs(ordered) do
     local player,entry=record.Player,record.Entry
     if entry.WasInterior and not arrivals then
      local root=entry.Root;local force=root and root:FindFirstChild("MoonGravity");if force then force:Destroy() end
      player:SetAttribute("InteriorId",nil);player:SetAttribute("MapLayer","Surface")
     end
     if entry.Root and entry.Root.Parent then
      local safe=arrivals and arrivals[index] or world:SafePosition(entry.Position);world:EnsureArea(safe)
      if not arrivals then safe=world:SafePosition(safe) end
      safe=aboveLand(safe)
      player.Character:PivotTo(CFrame.new(safe)*player.Character:GetPivot().Rotation)
      entry.Root.AssemblyLinearVelocity=Vector3.zero
     elseif entry.Corpse and entry.Corpse.Parent then
      local safe=arrivals and arrivals[index] or world:SafePosition(entry.Position);world:EnsureArea(safe)
      if not arrivals then safe=world:SafePosition(safe) end
      safe=aboveLand(safe)
      entry.Corpse:PivotTo(CFrame.new(safe)*entry.Corpse:GetPivot().Rotation)
      entry.Record.deathPosition=safe
     end
    end
   end)
   if self._hasGenerated then require(script.Parent.WorldControlService):ResolveGeneration(ok) end
   if ok then
   for player,entry in pairs(frozen) do
    if entry.Root and entry.Root.Parent then entry.Root.Anchored=entry.Anchored end
    for p,anchored in pairs(entry.Parts or {}) do if p.Parent then p.Anchored=anchored;p.AssemblyLinearVelocity=Vector3.zero end end
    player:SetAttribute("WorldPlayerLoading",nil)
   end
   held={}
   self._hasGenerated=true;ReplicatedStorage:SetAttribute("WorldShifting",false)
   else
    warn("[OverhaulWorld] Surface generation failed; retaining frozen active timers",err)
    if not self._hasGenerated then
     require(script.Parent.LoadingProgress).World(0,"Terrain generation interrupted; retrying")
    end
    -- Retry the committed serial/seed, without awarding another visit or rerolling resources.
    self._pendingBiome=self._pendingBiome or name
    task.wait(2)
   end
  end
  self._busy=false
 end)
end
function WorldGenController:GenerateBiome(biomeName)
 if type(biomeName)~="string" or not WorldGenConfig.BIOMES[biomeName] then return end
 self:_generateOverhaul(biomeName)
end

function WorldGenController:Init()
	if self._initialized then return end
	self._initialized = true
	
	-- Initialize ChunkStreamingService
	ChunkStreamingService:Init()
	
	local initial = BiomeService:GetCurrent()
	self:GenerateBiome(initial)
	
	_G.Ecoshift = _G.Ecoshift or {}
	task.spawn(function()
		for _ = 1, 50 do
			if type(_G.Ecoshift.OnBiomeChangedAdd) == "function" then
				_G.Ecoshift.OnBiomeChangedAdd(function(newBiome)
					self:GenerateBiome(newBiome)
				end)
				break
			end
			task.wait(0.1)
		end
	end)
end

return WorldGenController
