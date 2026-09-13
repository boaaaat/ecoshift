-- The overhaul is the only supported game. Prior data stores were retired explicitly.
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules={CurrentVersion=2,CurrentContentRelease=2}
function Rules.GetVersion() return 2 end
function Rules.GetContentRelease() return 2 end
function Rules.IsOverhaul() return true end
function Rules.OnChanged(callback)
 assert(type(callback)=="function","Rules callback required")
 callback(true,2,2)
 return function() end
end
function Rules.Configure(version,release)
 assert(RunService:IsServer(),"Only the server publishes world rules")
 assert(version==2 and release==2,"Retired world rules are unsupported")
 for _,target in ipairs({RS,workspace}) do
  target:SetAttribute("GameplayRulesVersion",2);target:SetAttribute("ContentRelease",2)
 end
end
return Rules
