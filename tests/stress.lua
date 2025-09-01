--%%name:ER6
--%%offline:true
--%%headers:src/include.txt

local a,b = api.post("/globalVariables/",{name="GV1",value="0"})

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables

   rule("a=0")
   local str = "@@00:00:02 => a = a+1"
   for i=1,300 do rule(str) end
   rule("@@00:00:02 => log('%s',a % 100 == 0 & 'OK' | 'BAD')")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  er.start()
end