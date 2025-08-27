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
  local rule,var = er.rule,er.variables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = true, check = true, result = false, listTriggers=true}
  
  var.DT = {
    kitchen = {
      light = {
        roof = loadDevice("binarySwitch"),
        window =  loadDevice("multilevelSwitch"),
      }
    }
  }

  function var.async.ASF(cb, x,y) 
    setTimeout(function() 
      cb(x+y) 
    end,100) 
    return 2000 
  end

  rule("log('ASF=%s',ASF(4,5)); ding()")
  rule("#foo => a = 42; post(#a)")
  rule("#a => if a == 42 then ding();  DT.kitchen.light.roof:on; end")
  rule("post(#foo)")

  rule("DT.kitchen.light.roof:isOn => ding()")
end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  --er.speed(1*24)
  er.start()
end