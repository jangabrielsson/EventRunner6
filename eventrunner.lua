--%%name:EventRunner6
--%%type:com.fibaro.genericDevice
--%%offline:true
--%%headers:include.txt
--%%uid:f1e8b22e2-3c4b-4d5a-9f6a-7b8c2360e1f2c
--%%save:EventRunner6.fqa

local tab = {}
json.util.InitArray(tab)
print(json.encodeFast(tab))
function QuickApp:main(er)
  local rule,var = er.rule,er.variables
  er.opts = { started = true, check = true, result = false, listTriggers=true}
  
  var.HT = {
    kitchen = {
      light = {
        roof = 66,
        window =  67,
      },
      sensor = {
        roof = 68,
      }
    }
  }

  rule("HT.kitchen.sensor.roof:breached => HT.kitchen.light.roof:on")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  er.start()
end