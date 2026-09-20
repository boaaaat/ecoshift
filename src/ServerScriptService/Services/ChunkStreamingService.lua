-- Public surface API retained for scanner, save, and survival callers.
local World=require(script.Parent.OverhaulWorldService)
local Catalog=require(game.ReplicatedStorage.Shared.OverhaulBiomes)
local Service={}
function Service:Init() return World:Init() end
function Service:GetClassScanMarkers(position,radius,mineralsOnly) return World:GetClassScanMarkers(position,radius,mineralsOnly) end
function Service:RegrowPlants(position,radius,limit) return World:RegrowPlants(position,radius,limit) end
function Service:CaptureWorldState() return World:CaptureWorldState() end
function Service:RestoreWorldState(state) return World:RestoreWorldState(state) end
function Service:GetRegionTempAtPosition(position) return position and World:GetTemperatureAt(position) or 0 end

return Service
