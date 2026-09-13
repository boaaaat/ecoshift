local Service={}
function Service:Bind()
 if self._started then return end;self._started=true
 task.spawn(function()
  while true do
   local ok,err=pcall(function()require(script.Parent.EnemySpawner):Tick()end)
   if not ok then warn("[Encounters]",err) end
   task.wait(5)
  end
 end)
end
function Service:SetPeriod() end
return Service
