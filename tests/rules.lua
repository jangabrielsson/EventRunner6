--%%name:ER6
--%%offline:true
--%%headers:src/include.txt

local YES = "✅"
local NO = "❌"
local BELL = "🔔"

local function printf(...) print(string.format(...)) end
local regs = {}
function reg(id) regs[id] = true end
function ding(id)
  printf(BELL..id)
  regs[id] = nil
  if not next(regs) then printf("%s All tests done!",YES) os.exit() end
end

local a,b = api.post("/globalVariables/",{name="GV1",value="0"})

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = true, check = true, result = false, triggers=true, } --nolog=true }
  
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

  -- reg('E1') rule("log('ASF=%s',ASF(4,5)); ding('E1')")
  
  -- reg('R1') rule("#foo1 => a1 = 42; post(#a1)")
  -- rule("#a1 => if a1 == 42 then ding('R1');  HT.kitchen.light.roof:on; end")
  -- rule("post(#foo1)")

  -- reg('R2') rule("log('ID:%s',{HT.kitchen.light.roof,66,77}:isOn:id) => ding('R2')")

  -- reg('R3') rule("trueFor(00:00:01,HT.kitchen.light.roof:isOn) => b1 = (b1 ?? 0) + 1; again(3); if b1 == 3 then ding('R3') end")
  
  
  -- triggerVar.x1 = 0
  
  -- reg('R4') rule("x1 == 42 => ding('R4')")
  -- rule("x1 = 42")
  
  -- reg('R5') rule("$GV1 => ding('R5')")
  -- rule("$GV1=true")
  
  -- reg('R6') rule("$$QV1 => ding('R6')")
  -- rule("$$QV1 = true")
  
  -- reg('R7') rule("HT.remote:key=='1:Pressed' => ding('R7')")
  -- rule("fibaro.call(HT.remote,'emitCentralSceneEvent',1,'Pressed')") 
  
  -- reg('R8') rule("HT.remote:scene==S1.click => ding('R8')")
  -- rule("click(HT.remote,S1.click)")
  
  -- reg('R9') rule("weather:temp == 32 => log('Temp'); ding('R9')")
  -- api.put("/weather",{Temperature=32}) er.post({type='weather', property='Temperature', value=32},2) -- trigger weather change

  -- reg('R10') rule("#bar{a='$v'} => if env.p.v == 99 then ding('R10') end")
  -- rule("post(#bar{a=99})")

  -- reg('R11') rule("#foo2 & sunrise..sunset => ding('R11')")
  -- rule("post(#foo2)")

  --  reg('R12') rule("#foo3 & /08/00/00:00../09/18/00:00 => $GV1 = 'Fopp'; ding('R12')")
  --  rule("post(#foo3)")

  --  reg('R13') rule("#foo4{'a'} => ding('R13')").start()
  -- rule("c1 = 0")
  -- rule("@x2 => c1 += 1; if c1 > 2 then x2 = 11:00 end; log('TIME %s',HM(now))")
  -- var.r1 = rule("@@00:00:03 => log('ok')")
  -- rule("wait(00:00:10); r1:disable()")
  
  -- rule("@@00:00:05 => return a / nil")
  
  -- rule("#rule-error{} => log('OK')")
  -- rule("log(json.encode(#foo{a=3}))")
  
  -- rule("#foo{a='$a>8'} => log('OK: %s',env.p.a)")
  -- rule("post(#foo{a=9},+/00:00:10)")
  
  -- rule([[/12/21/00:00../03/21/00:00 =>
-- $Jaar_Getijde = 'Winter';
-- log('#C:pink#$Jaar_Getijde = Winter');
-- log('64-A');
-- wait(0)
-- ]])

-- rule([[ @10:00 => return "
     
--        foo
-- ]])

  -- rule("@foo => = fooo")

  rule("global('Test')")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(4*24)
  er.start()
end