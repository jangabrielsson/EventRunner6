fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags
local fmt = string.format

local args = {}
local builtin = {}
ER.builtin = builtin

local function detag(str) 
  str = str:gsub("(#C:)(.-)(#)",function(_,c) color=c return "" end)
  if color then str=string.format("<font color='%s'>%s</font>",color,str) end
  return str
end

function builtin.log(...) -- printable tables and #C:color# tag
  local args,n = {...},0
  for i=1,#args do 
    local a = args[i]
    local typ = type(a)
    n = n+1
    if typ == 'string' then args[i] = detag(a)
    elseif typ == 'table' or typ == 'userdata' then 
      local mt = getmetatable(a)
      if mt and mt.__tostring then args[i] = tostring(a)
      else args[i] = json.encodeFast(a) end
    end
  end
  local msg = ""
  if n == 1 then msg = args[1] elseif n > 1 then msg = string.format(table.unpack(args)) end
  print(msg)
  return msg
end

function builtin.post(ev,time) return ER._er.post(ev,time) end
function builtin.cancel(ref) return ER._er.cancel(ref) end
function builtin.fmt(...) return string.format(...) end
function builtin.HM(t) return os.date("%H:%M",t < os.time()-8760*3600 and t+ER.midnight() or t) end
function builtin.HMS(t) return os.date("%H:%M",t < os.time()-8760*3600 and t+ER.midnight() or t) end
function builtin.sign(t) return t < 0 and -1 or 1 end
function builtin.rnd(min,max) return math.random(min,max)end
function builtin.round(num) return math.floor(num+0.5) end
function builtin.sum(...) 
  local args = {...}
  if #args == 1 and type(args[1]) == "table" then args = args[1] end
  local s = 0 for i=1,#arg do s = s + arg[i] end
  return s
end
function builtin.average(...) local s = builtin.sum(...) return s / select("#", ...) end
function builtin.size(t) return #t end
function builtin.min(...) 
  local args = {...}
  if #args == 1 and type(args[1]) == "table" then args = args[1] end
  return math.min(table.unpack(args))
end
function builtin.max(...) 
  local args = {...}
  if #args == 1 and type(args[1]) == "table" then args = args[1] end
  return math.max(table.unpack(args))
end
function builtin.sort(t) table.sort(t) return t end
function builtin.osdate(a,b) return os.date(a,b) end
function builtin.ostime(t) return os.time(t) end

function builtin.global(name)
  local s = fibaro.getGlobalVariable(name)     
  api.post("/globalVariables/",{name=name})
  return s == nil,(s == nil and fmt("'%s' created",name) or fmt("'%s' exists",name))
end

function builtin.listglobals() return api.get("/globalVariables") end
function builtin.deleteglobal(name) api.delete("/globalVariables/"..name) end

function builtin.subscribe(event) end
function builtin.publish(event) end
function builtin.remote(deviceId,event) end
function builtin.adde(t,v) table.insert(t,v) return t end
function builtin.remove(t,v) 
  for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end 
  return t
end

function builtin.enable(rule) end
function builtin.disable(rule) end

function ER.customDefs(er)
    local rule,var = er.rule,er.variables

    ER.computedVar.now = ER.now

    function var.async.trueFor(cb,time,expr)
    local trueFor = cb.env.rule.trueFor or {}
    cb.env.rule.trueFor = trueFor
    if expr then -- test is true
      if not trueFor.ref then -- new, start timer
        trueFor.trigger = cb.env.trigger
        trueFor.ref = cb.env:setTimeout(function() trueFor.ref = nil; cb(true) end, time*1000)
        return math.huge
      else -- already true and we have timer waiting
        cb(false) -- do nothing
      end
    elseif trueFor.ref then -- test is false, and we have timer
      cb.env:clearTimeout(trueFor.ref)
      trueFor.ref = nil
      cb(false)
    else
      cb(false) -- do nothing
    end
    return -1 -- not async...
  end

  function var.async.again(cb,n)
    local trueFor = cb.env.rule.trueFor
    if trueFor then
      if trueFor.again and trueFor.again == 0 then trueFor.again = nil return cb(0) end 
      if trueFor.again == nil then trueFor.again,trueFor.againN = n,n end-- reset
      trueFor.again = trueFor.again - 1
      if trueFor.trigger and  trueFor.again > 0 then 
        cb.env:setTimeout(function() cb.env.rule:start(trueFor.trigger) end, 0)
        cb(trueFor.againN - trueFor.again)
      else trueFor.again = nil cb(trueFor.againN) end
    else cb(0) end
    return -1 -- not async...
  end

  function var.async.once(cb,expr)
    local once = cb.env.rule.once
    if expr then
      if not once then 
        cb.env.rule.once = true
        cb(true)
      else cb(false) 
      end
    else  cb.env.rule.once = nil; cb(false) end
    return -1 -- not async
  end
  
  function var.async.wait(cb,time)
    if cb.env.waiting then cb.env.waiting(cb.env.rule,cb.env,time) end
    cb.env:setTimeout(function() 
      if cb.env.waited then cb.env.waited(cb.env.rule,cb.env,time) end
      cb(true) 
    end, 
    time*1000)
    return -1 -- not async
  end

  local function makeDateFun(str,cache)
    if cache[str] then return cache[str] end
    local f = ER.dateTest(str)
    cache[str] = f
    return f
  end
  
  local cache = { date={}, day = {}, month={}, wday={} }
  var.date = function(s) return (cache.date[s] or makeDateFun(s,cache.date))() end               -- min,hour,days,month,wday
  var.day = function(s) return (cache.day[s] or makeDateFun("* * "..s,cache.day))() end          -- day('1-31'), day('1,3,5')
  var.month = function(s) return (cache.month[s] or makeDateFun("* * * "..s,cache.month))() end  -- month('jan-feb'), month('jan,mar,jun')
  var.wday = function(s) return (cache.wday[s] or makeDateFun("* * * * "..s,cache.wday))() end   -- wday('fri-sat'), wday('mon,tue,wed')
  
  var.S1 = {click = "16", double = "14", tripple = "15", hold = "12", release = "13"}
  var.S2 = {click = "26", double = "24", tripple = "25", hold = "22", release = "23"}
  
  function var.nextDST()
    local d0 = os.date("*t")
    local t0 = os.time({year=d0.year, month=d0.month, day=1, hour=0})
    local h = d0.hour
    repeat  t0 = t0 + 3600*24*30; d0 = os.date("*t",t0) until d0.hour ~= h
    t0 = t0 - 3600*24*30; d0 = os.date("*t",t0)
    repeat h = d0.hour; t0 = t0 + 3600*24; d0 = os.date("*t",t0) until d0.hour ~= h
    t0 = t0 - 3600*24; d0 = os.date("*t",t0)
    repeat h = d0.hour; t0 = t0 + 3600; d0 = os.date("*t",t0) until d0.hour ~= (h+1) % 24
    if d0.month > 7 then t0 = t0 + 3600 end
    return t0
  end
  
    -- Example of home made property object
  Weather = {}
  er.definePropClass("Weather") -- Define custom weather object
  function Weather:__init() PropObject.__init(self) end
  function Weather.getProp.temp(prop,env) return api.get("/weather").Temperature end
  function Weather.getProp.humidity(prop,env) return  api.get("/weather").Humidity end
  function Weather.getProp.wind(prop,env) return  api.get("/weather").Wind end
  function Weather.getProp.condition(prop,env) return  api.get("/weather").WeatherCondition end
  function Weather.trigger.temp(prop) return {type='weather', property='Temperature'} end
  function Weather.trigger.humidity(prop) return {type='weather', property='Humidity'} end
  function Weather.trigger.wind(prop) return {type='weather', property='Wind'} end
  function Weather.trigger.condition(prop) return {type='weather', property='WeatherCondition'} end
  var.weather = Weather()
  
  ------- Patch fibaro.call to track manual switches -------------------------
  local lastID,switchMap = {},{}
  local oldFibaroCall = fibaro.call
  function fibaro.call(id,action,...)
    if ({turnOff=true,turnOn=true,on=true,toggle=true,off=true,setValue=true})[action] then lastID[id]={script=true,time=os.time()} end
    if action=='setValue' and switchMap[id]==nil then
      local actions = (__fibaro_get_device(id) or {}).actions or {}
      switchMap[id] = actions.turnOff and not actions.setValue
    end
    if action=='setValue' and switchMap[id] then return oldFibaroCall(id,({...})[1] and 'turnOn' or 'turnOff') end
    return oldFibaroCall(id,action,...)
  end
  
  local function lastHandler(ev)
    if ev.type=='device' and ev.property=='value' then
      local last = lastID[ev.id]
      local _,t = fibaro.get(ev.id,'value')
      if not(last and last.script and t-last.time <= 2) then
        lastID[ev.id]={script=false, time=t}
      end
    end
  end
  
  ER.sourceTrigger.eventEngine.registerCallback(lastHandler)
  
  function QuickApp:lastManual(id)
    local last = lastID[id]
    if not last then return -1 end
    return last.script and -1 or os.time()-last.time
  end

  local deviceFormatter = {}
  function deviceFormatter.centralSceneEvent(ev) 
    local val = ev.value or {}
    return fmt("#key{id:%s,%s:%s}", ev.id,val.keyId or "*", val.keyAttribute or "*")
  end
  function ER.eventFormatter.device(ev)
    if deviceFormatter[ev.property] then return deviceFormatter[ev.property](ev) end
    return false
  end

end


