fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags

local args = {}
local builtin = {}
ER.builtin = builtin

function builtin.log(fm,...) if #{...} == 0 then if fm==nil then print() else print(fm) end else print(string.format(fm,...)) end end

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
function builtin.osdate(t) return os.date(t) end
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

function builtin.once() end
function builtin.trueFor() end
function builtin.again() end



