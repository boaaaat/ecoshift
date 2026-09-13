local RS=game:GetService("ReplicatedStorage")
if require(RS:WaitForChild("Shared"):WaitForChild("SessionConfig")).GetMode()~="Expedition" then return end
local Players=game:GetService("Players")
local SoundService=game:GetService("SoundService")
local TweenService=game:GetService("TweenService")
local Settings=require(RS.Shared.ClientSettings)
local Biomes=require(RS.Shared.OverhaulBiomes)
local player=Players.LocalPlayer
-- Bundled Roblox sounds avoid permission failures from third-party audio assets.
-- Quiet filtered wind/water beds vary by biome and region; combat stays audible.
local wind=Instance.new("Sound");wind.Name="ExpeditionWind";wind.SoundId="rbxasset://sounds/action_falling.ogg";wind.Looped=true;wind.Volume=0;wind.Parent=SoundService
local water=Instance.new("Sound");water.Name="ExpeditionWater";water.SoundId="rbxasset://sounds/action_swim.mp3";water.Looped=true;water.Volume=0;water.Parent=SoundService
local equalizer=Instance.new("EqualizerSoundEffect");equalizer.LowGain=-9;equalizer.MidGain=-12;equalizer.HighGain=-15;equalizer.Parent=wind
local echo=Instance.new("ReverbSoundEffect");echo.DecayTime=1.2;echo.Density=.5;echo.Diffusion=.7;echo.WetLevel=-25;echo.DryLevel=0;echo.Parent=wind
wind:Play();water:Play()
local wetFamilies={Coast=true,Wetland=true,Ruins=true}
local exposedFamilies={Dunes=true,Alpine=true,Highlands=true,Moon=true,Crater=true}
local function ambience()
 local biome=Biomes.Biomes[RS:GetAttribute("CurrentBiome")];if not biome then return end
 local name=player:GetAttribute("MapRegionName") or "";local depth=player:GetAttribute("MapRegionDepth") or 1
 local interior=player:GetAttribute("InteriorId")~=nil;local cave=player:GetAttribute("MapLayer")=="Cave" or interior
 local watery=wetFamilies[biome.Landform] or name:find("Pool") or name:find("Lake") or name:find("Stream")
 local seed=0;for i=1,#name do seed+=string.byte(name,i) end
 TweenService:Create(wind,TweenInfo.new(3),{Volume=interior and .015 or exposedFamilies[biome.Landform] and .075 or .035,PlaybackSpeed=.65+(seed%11)*.035}):Play()
 TweenService:Create(water,TweenInfo.new(3),{Volume=watery and not interior and .035 or 0,PlaybackSpeed=.65+(depth-1)*.06}):Play()
 TweenService:Create(equalizer,TweenInfo.new(3),{LowGain=cave and -3 or -12,MidGain=-13,HighGain=cave and -25 or exposedFamilies[biome.Landform] and -8 or -18}):Play()
 echo.WetLevel=cave and -12 or -28;echo.DecayTime=cave and 2.5 or .7
end
for _,attribute in ipairs({"MapRegionName","MapRegionDepth","MapLayer","InteriorId"}) do player:GetAttributeChangedSignal(attribute):Connect(ambience) end
RS:GetAttributeChangedSignal("CurrentBiome"):Connect(ambience);ambience()
local tracked=setmetatable({},{__mode="k"})
local function decoration(instance)
 local current=instance
 while current and current~=workspace do if current:GetAttribute("Decoration") then return true end;current=current.Parent end
 return false
end
local function apply(instance)
 if not decoration(instance) then return end
 local low=Settings.Get("GraphicsQuality")=="Low"
 if instance:IsA("ParticleEmitter") then
  tracked[instance]=tracked[instance] or instance.Rate
  instance.Rate=Settings.Get("WeatherParticles") and tracked[instance]*(low and .2 or Settings.Get("GraphicsQuality")=="Medium" and .5 or 1) or 0
 elseif instance:IsA("BasePart") and not instance.CanCollide then
  tracked[instance]=true
  instance.LocalTransparencyModifier=low and .65 or 0
 end
end
workspace.DescendantAdded:Connect(function(instance) task.defer(apply,instance) end)
Settings.Changed:Connect(function() for instance in pairs(tracked) do if instance.Parent then apply(instance) end end end)
for _,instance in ipairs(workspace:GetDescendants()) do apply(instance) end
