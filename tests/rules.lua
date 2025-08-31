--%%name:ER6
--%%offline:true
--%%headers:include.txt

local YES = "✅"
local NO = "❌"
local BELL = "🔔"

local function printf(...) print(string.format(...)) end
local regs = {}
function reg(id) regs[id] = true end
function ding(id)
  printf(BELL)
  regs[id] = nil
  if not next(regs) then printf("%s All tests done!",YES) os.exit() end
end

local a,b = api.post("/globalVariables/",{name="GV1",value="0"})

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = true, check = true, result = false, listTriggers=true }
  
  function var.click(id,val) 
    api.post("/plugins/publishEvent",{
      type = "SceneActivationEvent", 
      source = id,
      data = { sceneId = val }
    })
  end
  
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
  
  -- reg('R1') rule("log('ASF=%s',ASF(4,5)); ding('R1')")
  
  -- reg('R2') rule("#foo1 => a1 = 42; post(#a1)")
  -- rule("#a1 => if a1 == 42 then ding('R2');  HT.kitchen.light.roof:on; end")
  -- rule("post(#foo1)")
  
  -- reg('R3') rule("HT.kitchen.light.roof:isOn => ding('R3')")
  
  -- reg('R4') rule("trueFor(00:00:01,HT.kitchen.light.roof:isOn) => b1 = (b1 ?? 0) + 1; again(3); if b1 == 3 then ding('R4') end")
  
  
  -- triggerVar.x1 = 0
  
  -- reg('R5') rule("x1 == 42 => ding('R5')")
  -- rule("x1 = 42")
  
  -- reg('R6') rule("$GV1 => ding('R6')")
  -- rule("$GV1=true")
  
  -- reg('R7') rule("$$QV1 => ding('R7')")
  -- rule("$$QV1 = true")
  
  -- reg('R8') rule("HT.remote:central.keyId==1 => ding('R8')")
  -- rule("fibaro.call(HT.remote,'emitCentralSceneEvent',1,'Pressed')")
  
  -- reg('R9') rule("HT.remote:scene==S1.click => ding('R9')")
  -- rule("click(HT.remote,S1.click)")
  
  -- rule("c1 = 0")
  -- rule("@x2 => c1 += 1; if c1 > 2 then x2 = 11:00 end; log('TIME %s',HM(now))")
  -- var.r1 = rule("@@00:00:03 => log('ok')")
  -- rule("wait(00:00:10); r1:disable()")
  
  -- rule("@@00:00:05 => return a / nil")
  
  -- rule("#rule-error{} => log('OK')")
  -- rule("log(json.encode(#foo{a=3}))")
  
  -- rule("#foo{a='$a>8'} => log('OK: %s',env.p.a)")
  -- rule("post(#foo{a=9},+/00:00:10)")
  
  reg('R10') rule("weather:temp == 32 => log('Temp'); ding('R10')")

  api.put("/weather",{Temperature=32}) er.post({type='weather', property='Temperature', value=32},2) -- trigger weather change
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(4*24)
  er.start()
end