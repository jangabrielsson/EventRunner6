fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags

local args = {}
local builtin = {}
ER.builtin = builtin

function builtin.log(fm,...) 
  local msg = ""
  if #{...} == 0 then if fm==nil then msg="" else msg=fm end else msg =string.format(fm,...) end
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
   return s == nil
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
    cb.env:setTimeout(function() cb(true) end, time*1000)
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

  var.QA = er.qa
  
end


