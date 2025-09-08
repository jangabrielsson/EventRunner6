--%%name:ER6
--%% offline:true
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

local _,_ = api.post("/globalVariables/",{name="GV1",value="0"})

function QuickApp:main(er)
  local rule,var,triggerVar = er.rule,er.variables,er.triggerVariables
  local function loadDevice(name) return er.loadSimDevice("/Users/jangabrielsson/Documents/dev/plua_new/plua/examples/fibaro/stdQAs/"..name..".lua") end
  er.opts = { started = false, check = true, result = false, triggers=true, } --nolog=true }
  
  fibaro.EventRunner.debugFlags.sourceTrigger = true
  fibaro.EventRunner.debugFlags.ignoreSourceTrigger = { PluginChangedViewEvent=true, } -- IGNORE PluginChangedViewEvent

  function var.click(id,val) 
    api.post("/plugins/publishEvent",{
      type = "SceneActivationEvent", 
      source = id,
      data = { sceneId = val }
    })
  end
  
  -- var.HT = {
  --   remote = loadDevice("remoteController"),
  --   kitchen = {
  --     light = {
  --       roof = loadDevice("binarySwitch"),
  --       window =  loadDevice("multilevelSwitch"),
  --     }
  --   }
  -- }

  --rule("2:armed=false")

  rule("#alarm{id=2,property='breached'} => log('Alarm')")

end

--%%time:2025/01/01 09:00:00
function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  -- self:debug(er)
  --er.speed(4*24)
  er.start()
end

--[[
  AlarmPartitionArmedEvent = function(d,_,post) post({type='alarm', property='armed', id = d.partitionId, value=d.armed}) end,
  AlarmPartitionBreachedEvent = function(d,_,post) post({type='alarm', property='breached', id = d.partitionId, value=d.breached}) end,
  AlarmPartitionModifiedEvent = function(d,_,post) print(json.encode(d)) end,
  HomeArmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=d.newValue}) end,
  HomeDisarmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=not d.newValue}) end,
  HomeBreachedEvent = function(d,_,post) post({type='alarm', property='homeBreached', value=d.breached}) end,
  --]]

  --setInterval(function() end,1*3600)