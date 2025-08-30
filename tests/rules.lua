--%%name:ER6
--%%offline:true
--%%headers:include.txt

local YES = "✅"
local NO = "❌"
local BELL = "🔔"

local function printf(...) print(string.format(...)) end
count,dings = 0,3
function ding()
  printf(BELL)
  count = count+1
  if count == dings then printf("%s All tests done!",YES) os.exit() end
end

local a,b = api.post("/globalVariables/",{name="GV1",value="0"})

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = true, check = true, result = false, listTriggers=true }
  
  var.HT = {
    remote = loadDevice("remoteController"),
    kitchen = {
      light = {
        roof = loadDevice("binarySwitch"),
        window =  loadDevice("multilevelSwitch"),
      }
    }
  }

  function var.async.ASF(cb, x,y) -- Define an async function
    setTimeout(function() 
      cb(x+y) 
    end,100) 
    return 2000 
  end

  -- rule("log('ASF=%s',ASF(4,5)); ding()")
  -- rule("#foo => a = 42; post(#a)")
  -- rule("#a => if a == 42 then ding();  HT.kitchen.light.roof:on; end")
  -- rule("post(#foo)")

  -- rule("HT.kitchen.light.roof:isOn => ding()")
  triggerVar.x = 36000

  -- rule("trueFor(00:00:02,HT.kitchen.light.roof:isOn) => log(x); log('TrueFor:%s',again(5))")
  -- rule("HT.kitchen.light.roof:on")

  -- rule("wait(00:00:15); HT.kitchen.light.roof:off; HT.kitchen.light.roof:on")

  -- rule("x => log('X=%s',x)")
  -- rule("x = 42")

  -- rule("$GV1 => log('GV1=%s',$GV1)")
  -- rule("$GV1=true")

  -- rule("$$QV1 => log('QV1=%s',$$QV1)")
  -- rule("$$QV1 = true; log('OKOK')")
  -- rule("c = 0")
  -- rule("@x => c += 1; if c > 2 then x = 11:00 end; log('TIME %s',HM(now))")
  -- rule("local a = 9; b = 8")
  -- rule("log(a); log('ok %s',b)")
  -- var.r1 = rule("@@00:00:03 => log('ok')")
  -- rule("wait(00:00:10); r1:disable()")

  function var.click(id,val) 
    api.post("/plugins/publishEvent",{
      type = "SceneActivationEvent", 
      source = id,
      data = { sceneId = val }
  })
  end

  -- rule("HT.remote:central => log('OK %s',json.encode(HT.remote:central))")
  -- rule("fibaro.call(HT.remote,'emitCentralSceneEvent',1,'Pressed')")

  -- rule("HT.remote:scene==S1.click => log('S1 click %s',HT.remote:scene)")
  -- rule("click(HT.remote,S1.click)")

  rule("@now+1 => return a>'h'")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(4*24)
  er.start()
end