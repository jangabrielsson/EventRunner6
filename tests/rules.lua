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

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = true, check = true, result = false, listTriggers=true }
  
  var.HT = {
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
  triggerVar.x = 9

  -- rule("trueFor(00:00:02,HT.kitchen.light.roof:isOn) => log(x); log('TrueFor:%s',again(5))")
  -- rule("HT.kitchen.light.roof:on")

  -- rule("wait(00:00:15); HT.kitchen.light.roof:off; HT.kitchen.light.roof:on")

  rule("x => log('X=%s',x)")
  rule("x = 42")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(1*24)
  er.start()
end