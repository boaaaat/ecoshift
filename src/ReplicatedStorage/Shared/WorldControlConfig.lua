-- All control costs and cooldowns come from the shared item catalog.
local Catalog=require(script.Parent.OverhaulCatalog)
local config={VoteSeconds=20,Order={"Delay","Advance","Select","Anchor"},Actions={}}
local names={Delay={"ShiftStabilizer","Shift Stabilizer","Add 60 seconds, once per visit. All extensions share a 600-second limit."},Advance={"ShiftTrigger","Shift Trigger","Start a 15-second warning after the first active minute."},Select={"WorldDial","World Dial","Choose a previously visited, eligible main biome. Once per visit."},Anchor={"WorldAnchor","World Anchor","Choose any eligible biome and its base weather; optionally extend this visit to 600 seconds."}}
for action,info in pairs(names) do local d=Catalog.WorldDevices[info[1]];config.Actions[action]={Device=info[1],Name=info[2],Description=info[3],Fuel=d.Fuel,Cooldown=d.Cooldown} end
return config
