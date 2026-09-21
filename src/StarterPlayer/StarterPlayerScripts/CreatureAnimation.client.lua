-- Presentation only: the server still owns movement, collisions, damage, and AI.
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local Settings=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ClientSettings"))
local TAG="AnimatedExpeditionCreature"
local states={}
local function addJoint(state,object)
 if not object:IsA("Motor6D") or state.attributes[object] then return end
 local function refresh()
  local kind=object:GetAttribute("MotionKind")
  state.joints[object]=kind and {kind=kind,phase=object:GetAttribute("MotionPhase") or 0,side=object:GetAttribute("MotionSide") or 1} or nil
 end
 -- Authoring sets metadata before Parent, but streaming may deliver attributes
 -- separately. Refresh cached profiles when their replicated metadata arrives.
 state.attributes[object]=object.AttributeChanged:Connect(function(name)
  if name=="MotionKind" or name=="MotionPhase" or name=="MotionSide" then refresh() end
 end)
 refresh()
end
local function register(model)
 if states[model] then return end
 local state={joints={},attributes={},cycle=0,blend=0,lastPosition=nil}
 states[model]=state
 for _,object in ipairs(model:GetDescendants()) do addJoint(state,object) end
 state.added=model.DescendantAdded:Connect(function(object) addJoint(state,object) end)
 state.removed=model.DescendantRemoving:Connect(function(object)
  state.joints[object]=nil
  if state.attributes[object] then state.attributes[object]:Disconnect();state.attributes[object]=nil end
 end)
end
local function remove(model)
 local state=states[model]
 if not state then return end
 state.added:Disconnect();state.removed:Disconnect()
 for _,connection in pairs(state.attributes) do connection:Disconnect() end
 for joint in pairs(state.joints) do if joint.Parent then joint.Transform=CFrame.identity end end
 states[model]=nil
end
for _,model in ipairs(CollectionService:GetTagged(TAG)) do register(model) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
local elapsed=0
RunService.PreSimulation:Connect(function(dt)
 elapsed+=dt
 local camera=workspace.CurrentCamera
 if not camera then return end
 local reducedMotion=Settings.Get("ReducedMotion")==true
 for model,state in pairs(states) do
  local root=model.PrimaryPart
  if not root or not model:IsDescendantOf(workspace) then continue end
  local position=root.Position
  local distance=(camera.CFrame.Position-position).Magnitude
  local displacement=state.lastPosition and position-state.lastPosition or Vector3.zero
  state.lastPosition=position
  local hum=model:FindFirstChildOfClass("Humanoid")
  if distance>180 or not hum or hum.Health<=0 then
   if state.active then for joint in pairs(state.joints) do joint.Transform=CFrame.identity end end
   state.active=false
   continue
  end
  state.active=true
  local scale=model:GetAttribute("ArtScale") or 1
  local speed=Vector3.new(displacement.X,0,displacement.Z).Magnitude/math.max(dt,.001)
  -- Ignore spawn/teleport jumps and smoothly settle feet when the creature stops.
  local moving=math.clamp(speed/(7*scale),0,1)
  if speed>80 then moving=0 end
  state.blend+=(moving-state.blend)*(1-math.exp(-dt*10))
  state.cycle+=(1.5+math.min(speed,20)*.65)*dt
  local family=model:GetAttribute("ArtFamily")
  local flutter=family=="Bat" or family=="Moth"
  for joint,profile in pairs(state.joints) do
   if not joint.Parent then state.joints[joint]=nil;continue end
   local wave=math.sin(state.cycle+profile.phase)
   local breath=reducedMotion and 0 or math.sin(elapsed*1.7)*.025
   local kind=profile.kind
   if kind=="Leg" then
    joint.Transform=CFrame.Angles(wave*.48*state.blend,0,math.max(0,wave)*.06*profile.side*state.blend)
   elseif kind=="Arm" then
    joint.Transform=CFrame.Angles(-wave*.3*state.blend,0,breath*profile.side)
   elseif kind=="Wing" then
    local flap=math.sin(elapsed*(flutter and 13 or 5))*(flutter and .55 or .12+.3*state.blend)*(reducedMotion and .2 or 1)
    joint.Transform=CFrame.Angles(0,0,profile.side*flap)
   elseif kind=="Tail" then
    joint.Transform=reducedMotion and CFrame.identity or CFrame.Angles(breath,math.sin(elapsed*2.1)*(.09+.18*state.blend),0)
   elseif kind=="Spine" then
    joint.Transform=CFrame.new(math.sin(state.cycle+profile.phase)*.2*state.blend*scale,0,0)*CFrame.Angles(0,wave*.14*state.blend,0)
   elseif kind=="Head" then
    joint.Transform=reducedMotion and CFrame.identity or CFrame.Angles(breath+math.sin(state.cycle*2)*.035*state.blend,math.sin(elapsed*.7)*.035,0)
   else
    local bob=reducedMotion and 0 or math.abs(math.sin(state.cycle))*.07*state.blend
    joint.Transform=CFrame.new(0,(breath+bob)*scale,0)
   end
  end
 end
end)
