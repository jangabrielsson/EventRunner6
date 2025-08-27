--%%name:EventRunner6
--%% offline:true
--%%headers:include.txt
--%%save:EventRunner6.fqa

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