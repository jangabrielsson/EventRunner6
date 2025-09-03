--%%name:ER6
--%% offline:true
--%%headers:src/include.txt
--%%file:src/addons.lua,addon

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  er.opts = { started = true, check = true, result = false, triggers=true, nolog=true }
  
  
  local HT = {
    keyfob = 46,
    dialBtn = 1632,
    dialWheel = 1635, 
    main = {
      temp = 1630,
      motion = 1634,
      table = 1626,
      island = 1627,
      lux = 1629,
      window = 1628,
      stars = 1911,
      bedroomStar = 1914,
      bedroomLed = 1877,
      guestStar = 1913,
    },
    hall = {
      door = 1636,
    },
    study = {
      plug = 1638,
    }
  }
  for k,v in pairs(HT) do var[k]=v end
  
  
  rule("!main.island:isDead => main.island:value=50")
  
  rule("@23:00 => main.window:off")
  rule("@{sunset,catch} => main.window:on")
  rule("@23:00 => main.stars:off")
  rule("@{sunset,catch} => main.stars:on")
  
  rule("@07:00 => main.stars:on")
  
  rule("main.bedroomLed:isOn => main.bedroomStar:on; main.guestStar:on")
  rule("main.bedroomLed:isOff => main.bedroomStar:off; main.guestStar:off")
  rule("main.island:isOn =>  main.island:value=70")
  
  rule("log('HC3 uptime %s',uptimeStr)")
  rule("log('Sunrise at %s, Sunset at %s',HM(sunrise),HM(sunset))")
  rule("log('Weather condition is %s',weather:condition)")
  rule("log('Temperature is %s°',weather:temp)")
  rule("log('Wind is %sms',weather:wind)")

  rule("dialWheel:value => log('Dial:%s',dialWheel:value)")
  rule("dialBtn:key => log('Dial button %s',dialBtn:key)")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(4*24)
  er.start()
end