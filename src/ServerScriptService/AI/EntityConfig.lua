local Catalog=require(game.ReplicatedStorage.Shared.OverhaulBiomes)
local Config={StepInterval=.2,Defaults={Monster={Speed=14,Damage=8,AttackRange=5,AttackCooldown=2,DetectionDistance=70,DetectionAngle=180,AutoDetectRadius=8,UsePathfinding=true,RepathInterval=1,RepathDistance=8,AgentCanJump=true},Animal={Speed=7,Damage=0,UsePathfinding=true}},Entities={},EnemyWaves={PeriodSeconds=5,InitialGraceSeconds=90},SpawnPoints={}}
for id,def in pairs(Catalog.Creatures) do
 Config.Entities[id]={Type=def.Role=="N" and "Animal" or "Monster",AIClass="OverhaulCreature",AI={},Spawn={Weight=1,Biomes={[def.Biome]={Weight=1}},GroupSize={min=1,max=1},MinPlayerDistance=55}}
end
return Config
