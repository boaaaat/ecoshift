-- InteractService.lua (expanded: Harvest, Revive)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ObjectiveService = require(script.Parent.ObjectiveService)
local InventoryService = require(script.Parent.InventoryService)

local InteractService = {}
InteractService._remotesFolder = nil
InteractService._remote = nil

local _lastInteract = {}

local function tooSoon(plr, minGap)
	local now = os.clock(); local last = _lastInteract[plr] or 0
	if now - last < (minGap or 0.05) then return true end
	_lastInteract[plr] = now; return false
end

local ACTIONS = {}

ACTIONS.ObjectiveProgress = function(plr, payload)
	if type(payload) ~= "table" then return end
	local id = payload.ObjectiveId; local delta = tonumber(payload.Delta) or 0
	if not id or delta <= 0 then return end
	ObjectiveService:Advance(id, delta)
end

ACTIONS.Pickup = function(plr, payload)
	local id, n = payload and payload.ItemId, tonumber(payload and payload.Amount) or 1
	if not id or n <= 0 then return end
	InventoryService:Give(plr, id, n)
end

ACTIONS.Harvest = function(plr, payload)
	-- payload = {Node=Instance, Yields={{Id="Wood",N=2}}, Cooldown=seconds}
	local node = payload and payload.Node
	local yields = payload and payload.Yields
	if typeof(node) ~= "Instance" or type(yields) ~= "table" then return end
	if (node:GetAttribute("Enabled") == false) then return end
	local cd = tonumber(node:GetAttribute("CooldownUntil")) or 0
	if os.clock() < cd then return end
	-- distance guard
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local anchor = node:IsA("Attachment") and node.WorldPosition or (node.Position or node:GetAttribute("WorldPosition"))
	if not root or not anchor then return end
	if (root.Position - (anchor)).Magnitude > 25 then return end
	-- grant
	local mult = (_G.Ecoshift and _G.Ecoshift.Mods and _G.Ecoshift.Mods.ResourceMultiplier) or 1.0
	local roleMult = tonumber(plr:GetAttribute("Role_Gather")) or 1.0
	mult *= roleMult
	for _,r in ipairs(yields) do
		InventoryService:Give(plr, r.Id, math.max(1, math.floor((r.N or 1) * mult)))
	end
	-- cooldown
	local cooldown = tonumber(payload.Cooldown) or 5
	node:SetAttribute("CooldownUntil", os.clock()+cooldown)
end

ACTIONS.Repair = function(plr, payload)
	local t = payload and payload.Target; local amt = tonumber(payload and payload.Amount) or 0
	if not t or amt <= 0 then return end
	local dur = t:FindFirstChild("Durability")
	if dur and dur:IsA("NumberValue") then
		dur.Value = math.clamp(dur.Value + amt, 0, (t:GetAttribute("DurabilityMax") or 100))
	end
end

ACTIONS.Revive = function(plr, payload)
	-- payload = {TargetCharacter = Model}
	local targetChar = payload and payload.TargetCharacter
	if typeof(targetChar) ~= "Instance" or not targetChar:FindFirstChildWhichIsA("Humanoid") then return end
	local hum = targetChar:FindFirstChildWhichIsA("Humanoid")
	if hum.Health > 0 then return end -- already alive or not downed (you can adapt to your downed logic)
	-- if you use a "Downed" Attribute instead of death, update here. For now, simple respawn:
	local targetPlr = Players:GetPlayerFromCharacter(targetChar)
	if targetPlr then targetPlr:LoadCharacter() end
end

function InteractService:Bind()
	self._remotesFolder = Util.WaitForDescendant(Config.Paths.Remotes, 10)
	self._remote = Util.GetRemote(self._remotesFolder, Config.RemoteNames.Interact)
	if not self._remote then return end
	self._remote.OnServerEvent:Connect(function(plr, action, payload)
		if typeof(plr) ~= "Instance" or tooSoon(plr, 0.03) then return end
		local fn = ACTIONS[action]; if not fn then return end
		local ok = pcall(fn, plr, payload); if not ok then end
	end)
end

return InteractService
