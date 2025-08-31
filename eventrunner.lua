--%%name:EventRunner6
--%%headers:include.txt
--%%save:EventRunner6.fqa
--%%offline:true

function QuickApp:main(er)
  local rule,var = er.rule,er.variables
  er.opts = { started = true, check = true, result = false, listTriggers=true}
  
  var.HT = {
    kitchen = {
      light = { roof = 66, window =  67, },
      sensor = { roof = 68, },
    },
  }

  rule("@@00:00:05 => log('Ding!')")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  er.start()
end