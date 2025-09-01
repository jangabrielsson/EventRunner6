--%%name:EventRunner6
--%%headers:src/include.txt
--%%u:{label='info', text='EventRunnner 6'}
--%%save:dist/EventRunner6.fqa
--%%offline:true

function QuickApp:main(er)
  local rule,var = er.rule,er.variables
  er.opts = { started = true, check = true, result = false, triggers=true}
  
  var.HT = {
    kitchen = {
      light = { roof = 66, window =  67, },
      sensor = { roof = 68, },
    },
  }

  rule("HT.kitchen.sensor.roof:breached => log('Roof sensor breached!'); HT.kitchen.light.roof:on")
  rule("@@00:00:05 => log('Ding!')")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er) 
  self:updateView('info','text',tostring(er))
  er.start()
end