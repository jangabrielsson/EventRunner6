fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags

local fmt = string.format

getmetatable("").__idiv = function(str,len) return (#str < len or #str < 4) and str or str:sub(1,len-2)..".." end -- truncate strings

local function copy(obj)
  if type(obj) == 'table' then
    local res = {} for k,v in pairs(obj) do res[k] = copy(v) end
    return res
  else return obj end
end

local function copyShallow(obj)
  if type(obj) == 'table' then
    local res = {} for k,v in pairs(obj) do res[k] = v end
    return res
  else return obj end
end

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

table.copy = copy
table.copyShallow = copyShallow
table.equal = equal

function string.split(str, sep)
    local fields, s = {}, sep or "%s"
    str:gsub("([^" .. s .. "]+)", function(c)
        fields[#fields + 1] = c
    end)
    return fields
end

if not table.maxn then 
  function table.maxn(tbl) local c=0 for i,_ in pairs(tbl) do c=i end return c end
end

function table.map(f,l,s) s = s or 1; local r,m={},table.maxn(l) for i=s,m do r[#r+1] = f(l[i]) end return r end
function table.mapf(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) end return e end
function table.mapAnd(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) if not e then return false end end return e end 
function table.mapOr(f,l,s) s = s or 1; for i=s,table.maxn(l) do local e = f(l[i]) if e then return e end end return false end
function table.reduce(f,l) local r = {}; for _,e in ipairs(l) do if f(e) then r[#r+1]=e end end; return r end
function table.mapk(f,l) local r={}; for k,v in pairs(l) do r[k]=f(v) end; return r end
function table.mapkv(f,l) local r={}; for k,v in pairs(l) do k,v=f(k,v) if k then r[k]=v end end; return r end
function table.mapkl(f,l) local r={} for i,j in pairs(l) do r[#r+1]=f(i,j) end return r end
function table.size(l) local n=0; for _,_ in pairs(l) do n=n+1 end return n end 

--------------- Time and Sun calc  functions -----------------------
local function toSeconds(str)
  __assert_type(str,"string" )
  local sun = str:match("(sun%a+)")
  if sun then return toSeconds(str:gsub(sun,fibaro.getValue(1,sun.."Hour"))) end
  local var = str:match("(%$[A-Za-z]+)")
  if var then return toSeconds(str:gsub(var,fibaro.getGlobalVariable(var:sub(2)))) end
  local h,m,s,op,off=str:match("(%d%d):(%d%d):?(%d*)([+%-]*)([%d:]*)")
  off = off~="" and (off:find(":") and toSeconds(off) or toSeconds("00:00:"..off)) or 0
  return 3600*h+60*m+(s~="" and s or 0)+((op=='-' or op =='+-') and -1 or 1)*off
end

---@diagnostic disable-next-line: param-type-mismatch
local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end
local function getWeekNumber(tm) return tonumber(os.date("%V",tm)) end
local function now() return os.time()-midnight() end

local function between(start,stop,optTime)
  __assert_type(start,"string" )
  __assert_type(stop,"string" )
  start,stop,optTime=toSeconds(start),toSeconds(stop),optTime and toSeconds(optTime) or toSeconds(os.date("%H:%M"))
  stop = stop>=start and stop or stop+24*3600
  optTime = optTime>=start and optTime or optTime+24*3600
  return start <= optTime and optTime <= stop
end
local function time2str(t) return fmt("%02d:%02d:%02d",math.floor(t/3600),math.floor((t%3600)/60),t%60) end

local sunCalc 

local function hm2sec(hmstr,ns)
  local offs,sun
  sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
  if sun and (sun == 'sunset' or sun == 'sunrise') then
    if ns then
      local sunrise,sunset = sunCalc(os.time()+24*3600)
      hmstr,offs = sun=='sunrise' and sunrise or sunset, tonumber(offs) or 0
    else
      hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
    end
  end
  local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
  if not (h and m) then error(fmt("Bad hm2sec string %s",hmstr)) end
  return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
end

-- toTime("10:00")     -> 10*3600+0*60 secs
-- toTime("10:00:05")  -> 10*3600+0*60+5*1 secs
-- toTime("t/10:00")    -> (t)oday at 10:00. midnight+10*3600+0*60 secs
-- toTime("n/10:00")    -> (n)ext time. today at 10.00AM if called before (or at) 10.00AM else 10:00AM next day
-- toTime("+/10:00")    -> Plus time. os.time() + 10 hours
-- toTime("+/00:01:22") -> Plus time. os.time() + 1min and 22sec
-- toTime("sunset")     -> todays sunset in relative secs since midnight, E.g. sunset="05:10", =>toTime("05:10")
-- toTime("sunrise")    -> todays sunrise
-- toTime("sunset+10")  -> todays sunset + 10min. E.g. sunset="05:10", =>toTime("05:10")+10*60
-- toTime("sunrise-5")  -> todays sunrise - 5min
-- toTime("t/sunset+10")-> (t)oday at sunset in 'absolute' time. E.g. midnight+toTime("sunset+10")

local function toTime(time)
  if type(time) == 'number' then return time end
  local p = time:sub(1,2)
  if p == '+/' then return hm2sec(time:sub(3))+os.time()
  elseif p == 'n/' then
    local t1,t2 = midnight()+hm2sec(time:sub(3),true),os.time()
    return t1 > t2 and t1 or t1+24*60*60
  elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
  else return hm2sec(time) end
end

local function sunturnTime(date, rising, latitude, longitude, zenith, local_offset)
  local rad,deg,floor = math.rad,math.deg,math.floor
  local frac = function(n) return n - floor(n) end
  local cos = function(d) return math.cos(rad(d)) end
  local acos = function(d) return deg(math.acos(d)) end
  local sin = function(d) return math.sin(rad(d)) end
  local asin = function(d) return deg(math.asin(d)) end
  local tan = function(d) return math.tan(rad(d)) end
  local atan = function(d) return deg(math.atan(d)) end
  
  local function day_of_year(date2)
    local n1 = floor(275 * date2.month / 9)
    local n2 = floor((date2.month + 9) / 12)
    local n3 = (1 + floor((date2.year - 4 * floor(date2.year / 4) + 2) / 3))
    return n1 - (n2 * n3) + date2.day - 30
  end
  
  local function fit_into_range(val, min, max)
    local range,count = max - min,nil
    if val < min then count = floor((min - val) / range) + 1; return val + count * range
    elseif val >= max then count = floor((val - max) / range) + 1; return val - count * range
    else return val end
  end
  
  -- Convert the longitude to hour value and calculate an approximate time
  local n,lng_hour,t =  day_of_year(date), longitude / 15,nil
  if rising then t = n + ((6 - lng_hour) / 24) -- Rising time is desired
  else t = n + ((18 - lng_hour) / 24) end -- Setting time is desired
  local M = (0.9856 * t) - 3.289 -- Calculate the Sun^s mean anomaly
  -- Calculate the Sun^s true longitude
  local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)
  -- Calculate the Sun^s right ascension
  local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)
  -- Right ascension value needs to be in the same quadrant as L
  local Lquadrant = floor(L / 90) * 90
  local RAquadrant = floor(RA / 90) * 90
  RA = RA + Lquadrant - RAquadrant; RA = RA / 15 -- Right ascension value needs to be converted into hours
  local sinDec = 0.39782 * sin(L) -- Calculate the Sun's declination
  local cosDec = cos(asin(sinDec))
  local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude)) -- Calculate the Sun^s local hour angle
  if rising and cosH > 1 then return -1 --"N/R" -- The sun never rises on this location on the specified date
  elseif cosH < -1 then return -1 end --"N/S" end -- The sun never sets on this location on the specified date
  
  local H -- Finish calculating H and convert into hours
  if rising then H = 360 - acos(cosH)
  else H = acos(cosH) end
  H = H / 15
  local T = H + RA - (0.06571 * t) - 6.622 -- Calculate local mean time of rising/setting
  local UT = fit_into_range(T - lng_hour, 0, 24) -- Adjust back to UTC
  local LT = UT + local_offset -- Convert UT value to local time zone of latitude/longitude
  ---@diagnostic disable-next-line: missing-fields
  return os.time({day = date.day,month = date.month,year = date.year,hour = floor(LT),min = math.modf(frac(LT) * 60)})
end

---@diagnostic disable-next-line: param-type-mismatch
local function getTimezone() local now = os.time() return os.difftime(now, os.time(os.date("!*t", now))) end

function sunCalc(time)
  local hc3Location = api.get("/settings/location")
  local lat = hc3Location.latitude or 0
  local lon = hc3Location.longitude or 0
  local utc = getTimezone() / 3600
  local zenith,zenith_twilight = 90.83, 96.0 -- sunset/sunrise 90°50′, civil twilight 96°0′
  
  local date = os.date("*t",time or os.time())
  if date.isdst then utc = utc + 1 end
  local rise_time = os.date("*t", sunturnTime(date, true, lat, lon, zenith, utc))
  local set_time = os.date("*t", sunturnTime(date, false, lat, lon, zenith, utc))
  local rise_time_t = os.date("*t", sunturnTime(date, true, lat, lon, zenith_twilight, utc))
  local set_time_t = os.date("*t", sunturnTime(date, false, lat, lon, zenith_twilight, utc))
  local sunrise = rise_time.hour*3600 + rise_time.min*60
  local sunset = set_time.hour*3600 + set_time.min*60
  local sunrise_t = rise_time_t.hour*3600 + rise_time_t.min*60
  local sunset_t = set_time_t.hour*3600 + set_time_t.min*60
  return sunrise, sunset, sunrise_t, sunset_t
end

local function dateTest(dateStr0)
  local days = {sun=1,mon=2,tue=3,wed=4,thu=5,fri=6,sat=7}
  local months = {jan=1,feb=2,mar=3,apr=4,may=5,jun=6,jul=7,aug=8,sep=9,oct=10,nov=11,dec=12}
  local last,month = {31,28,31,30,31,30,31,31,30,31,30,31},nil
  
  local function seq2map(seq) local s = {} for _,v in ipairs(seq) do s[v] = true end return s; end
  
  local function flatten(seq,res) -- flattens a table of tables
    res = res or {}
    if type(seq) == 'table' then for _,v1 in ipairs(seq) do flatten(v1,res) end else res[#res+1] = seq end
    return res
  end
  
  local function _assert(test,msg,...) if not test then error(fmt(msg,...),3) end end
  
  local function expandDate(w1,md)
    local function resolve(id)
      local res
      if id == 'last' then month = md res=last[md]
      elseif id == 'lastw' then month = md res=last[md]-6
      else res= type(id) == 'number' and id or days[id] or months[id] or tonumber(id) end
      _assert(res,"Bad date specifier '%s'",id) return res
    end
    local step = tonumber(1)
    local w,m = w1[1],w1[2]
    local start,stop = w:match("(%w+)%p(%w+)")
    if (start == nil) then return resolve(w) end
    start,stop = resolve(start), resolve(stop)
    local res,res2 = {},{}
    if w:find("/") then
      if not w:find("-") then -- 10/2
        step=stop; stop = m.max
      else step=(w:match("/(%d+)")) end
    end
    step = tonumber(step)
    _assert(start>=m.min and start<=m.max and stop>=m.min and stop<=m.max,"illegal date intervall")
    while (start ~= stop) do -- 10-2
      res[#res+1] = start
      start = start+1; if start>m.max then start=m.min end
    end
    res[#res+1] = stop
    if step > 1 then for i=1,#res,step do res2[#res2+1]=res[i] end; res=res2 end
    return res
  end
  
  local function parseDateStr(dateStr) --,last)
    local map = table.map
    local seq = string.split(dateStr," ")   -- min,hour,day,month,wday
    local lim = {{min=0,max=59},{min=0,max=23},{min=1,max=31},{min=1,max=12},{min=1,max=7},{min=2000,max=3000}}
    for i=1,6 do if seq[i]=='*' or seq[i]==nil then seq[i]=tostring(lim[i].min).."-"..lim[i].max end end
    seq = map(function(w) return string.split(w,",") end, seq)   -- split sequences "3,4"
    local month0 = os.date("*t",os.time()).month
    seq = map(function(t) 
      local m = table.remove(lim,1);
      return flatten(map(function (g) return expandDate({g,m},month0) end, t)) 
    end, seq) -- expand intervalls "3-5"
    return map(seq2map,seq)
  end
  local sun,offs,day,sunPatch = dateStr0:match("^(sun%a+) ([%+%-]?%d+)")
  if sun then
    sun = sun.."Hour"
    dateStr0=dateStr0:gsub("sun%a+ [%+%-]?%d+","0 0")
    sunPatch=function(dateSeq)
      local h,m = (fibaro.getValue(1,sun)):match("(%d%d):(%d%d)")
      dateSeq[1]={[(tonumber(h)*60+tonumber(m)+tonumber(offs))%60]=true}
      dateSeq[2]={[math.floor((tonumber(h)*60+tonumber(m)+tonumber(offs))/60)]=true}
    end
  end
  local dateSeq = parseDateStr(dateStr0)
  return function() -- Pretty efficient way of testing dates...
    local t = os.date("*t",os.time())
    if month and month~=t.month then dateSeq=parseDateStr(dateStr0) end -- Recalculate 'last' every month
    if sunPatch and (month and month~=t.month or day~=t.day) then sunPatch(dateSeq) day=t.day end -- Recalculate sunset/sunrise
    return
    dateSeq[1][t.min] and    -- min     0-59
    dateSeq[2][t.hour] and   -- hour    0-23
    dateSeq[3][t.day] and    -- day     1-31
    dateSeq[4][t.month] and  -- month   1-12
    dateSeq[5][t.wday] or false      -- weekday 1-7, 1=sun, 7=sat
  end
end

--------------- Event engine -------------------
local EventMT = { 
  __tostring = function(ev)
    local s = json.encodeFast(ev)
    if s:sub(1,1)=='#' then return s end
    local m = s:match("^.-,(.*)}$") or ""
    return fmt("#%s{%s}",ev.type,m) 
  end
}
ER.EventMT = EventMT

local function createEventEngine()
  local self = {}
  local HANDLER = '%EVENTHANDLER%'
  local BREAK = '%BREAK%'
  self.BREAK = BREAK
  local handlers = {}
  local function isEvent(e) return type(e) == 'table' and type(e.type)=='string' end
  
  local function coerce(x,y) local x1 = tonumber(x) if x1 then return x1,tonumber(y) else return x,y end end
  local constraints = {}
  constraints['=='] = function(val) return function(x) x,val=coerce(x,val) return x == val end end
  constraints['<>'] = function(val) return function(x) return tostring(x):match(val) end end
  constraints['>='] = function(val) return function(x) x,val=coerce(x,val) return x >= val end end
  constraints['<='] = function(val) return function(x) x,val=coerce(x,val) return x <= val end end
  constraints['>'] = function(val) return function(x) x,val=coerce(x,val) return x > val end end
  constraints['<'] = function(val) return function(x) x,val=coerce(x,val) return x < val end end
  constraints['~='] = function(val) return function(x) x,val=coerce(x,val) return x ~= val end end
  constraints[''] = function(_) return function(x) return x ~= nil end end
  
  local function compilePattern2(pattern)
    if type(pattern) == 'table' then
      if pattern._var_ then return end
      for k,v in pairs(pattern) do
        if type(v) == 'string' and v:sub(1,1) == '$' then
          local var,op,val = v:match("$([%w_]*)([<>=~]*)(.*)")
          var = var =="" and "_" or var
          local c = constraints[op](tonumber(val) or val)
          pattern[k] = {_var_=var, _constr=c, _str=v}
        else compilePattern2(v) end
      end
    end
    return pattern
  end
  
  local function compilePattern(pattern)
    pattern = compilePattern2(copy(pattern))
    assert(pattern)
    if pattern.type and type(pattern.id)=='table' and not pattern.id._constr then
      local m = {}; for _,id in ipairs(pattern.id) do m[id]=true end
      pattern.id = {_var_='_', _constr=function(val) return m[val] end, _str=pattern.id}
    end
    return pattern
  end
  self.compilePattern = compilePattern
  
  local function match(pattern0, expr0)
    local matches = {}
    local function unify(pattern,expr)
      if pattern == expr then return true
      elseif type(pattern) == 'table' then
        if pattern._var_ then
          local var, constr = pattern._var_, pattern._constr
          if var == '_' then return constr(expr)
          elseif matches[var] then return constr(expr) and unify(matches[var],expr) -- Hmm, equal?
          else matches[var] = expr return constr(expr) end
        end
        if type(expr) ~= "table" then return false end
        for k,v in pairs(pattern) do if not unify(v,expr[k]) then return false end end
        return true
      else return false end
    end
    return unify(pattern0,expr0) and matches or false
  end
  self.match = match
  
  local function invokeHandler(env)
    local t = os.time()
    env.last,env.rule.time = t-(env.rule.time or 0),t
    local status, res = pcall(env.rule.action,env) -- call the associated action
    if not status then
      --if type(res)=='string' and not debugFlags.extendedErrors then res = res:gsub("(%[.-%]:%d+:)","") end
      --fibaro.errorf(nil,"in %s: %s",env.rule.doc,res)
      env.rule._disabled = true -- disable rule to not generate more errors
      fibaro.error(__TAG,res)
      --em.stats.errors=(em.stats.errors or 0)+1
    else return res end
  end
  
  local toTime = self.toTime
  function self.post(ev,t,log,hook,customLog)
    local now,isEv = os.time(),isEvent(ev)
    t = type(t)=='string' and toTime(t) or t or 0
    if t < 0 then return elseif t < now then t = t+now end
    if debugFlags.post and (type(ev)=='function' or not ev._sh) then
      if isEv and not getmetatable(ev) then setmetatable(ev,EventMT) end
      (customLog or fibaro.trace)(__TAG,fmt("Posting %s at %s %s",tostring(ev),os.date("%c",t),type(log)=='string' and ("("..log..")") or ""))
    end
    if type(ev) == 'function' then
      return setTimeout(function() ev(ev) end,1000*(t-now)),t
    elseif isEv then
      if not getmetatable(ev) then setmetatable(ev,EventMT) end
      local ref; ref = setTimeout(function() if hook then hook(ref) end self.handleEvent(ev) end,1000*(t-now))
      return ref,t
    else
      error("post(...) not event or fun;"..tostring(ev))
    end
  end
  
  function self.cancel(id) clearTimeout(id) end
  
  local toHash,fromHash={},{}
  fromHash['device'] = function(e) return {"device"..e.id..e.property,"device"..e.id,"device"..e.property,"device"} end
  fromHash['global-variable'] = function(e) return {'global-variable'..e.name,'global-variable'} end
  fromHash['quickvar'] = function(e) return {"quickvar"..e.id..e.name,"quickvar"..e.id,"quickvar"..e.name,"quickvar"} end
  fromHash['profile'] = function(e) return {'profile'..e.property,'profile'} end
  fromHash['weather'] = function(e) return {'weather'..e.property,'weather'} end
  fromHash['custom-event'] = function(e) return {'custom-event'..e.name,'custom-event'} end
  fromHash['deviceEvent'] = function(e) return {"deviceEvent"..e.id..e.value,"deviceEvent"..e.id,"deviceEvent"..e.value,"deviceEvent"} end
  fromHash['sceneEvent'] = function(e) return {"sceneEvent"..e.id..e.value,"sceneEvent"..e.id,"sceneEvent"..e.value,"sceneEvent"} end
  toHash['device'] = function(e) return "device"..(e.id or "")..(e.property or "") end
  
  toHash['global-variable'] = function(e) return 'global-variable'..(e.name or "") end
  toHash['quickvar'] = function(e) return 'quickvar'..(e.id or "")..(e.name or "") end
  toHash['profile'] = function(e) return 'profile'..(e.property or "") end
  toHash['weather'] = function(e) return 'weather'..(e.property or "") end
  toHash['custom-event'] = function(e) return 'custom-event'..(e.name or "") end
  toHash['deviceEvent'] = function(e) return 'deviceEvent'..(e.id or "")..(e.value or "") end
  toHash['sceneEvent'] = function(e) return 'sceneEvent'..(e.id or "")..(e.value or "") end
  
  
  local MTrule = { __tostring = function(self) return fmt("SourceTriggerSub:%s",self.event.type) end }
  function self.addEventHandler(pattern,fun,doc)
    if not isEvent(pattern) then error("Bad event pattern, needs .type field") end
    assert(type(fun)=='func'..'tion', "Second argument must be Lua func")
    local cpattern = compilePattern(pattern)
    local rule,hashKeys = {[HANDLER]=cpattern, event=pattern, action=fun, doc=doc},{}
    if toHash[pattern.type] and pattern.id and type(pattern.id) == 'table' then
      local oldid=pattern.id
      for _,id in ipairs(pattern.id) do
        pattern.id = id
        hashKeys[#hashKeys+1] = toHash[pattern.type](pattern)
        pattern.id = oldid
      end
    else hashKeys = {toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type} end
    for _,hashKey in ipairs(hashKeys) do
      handlers[hashKey] = handlers[hashKey] or {}
      local rules,fn = handlers[hashKey],true
      for _,rs in ipairs(rules) do -- Collect handlers with identical patterns. {{e1,e2,e3},{e1,e2,e3}}
        if equal(cpattern,rs[1].event) then
          rs[#rs+1] = rule
          fn = false break
        end
      end
      if fn then rules[#rules+1] = {rule} end
    end
    rule.enable = function() rule._disabled = nil return rule end
    rule.disable = function() rule._disabled = true return rule end
    return rule
  end
  
  function self.removeEventHandler(rule)
    local pattern,fun = rule.event,rule.action
    local hashKey = toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type
    local rules,i,j= handlers[hashKey] or {},1,1
    while j <= #rules do
      local rs = rules[j]
      while i <= #rs do
        if rs[i].action==fun then
          table.remove(rs,i)
        else i=i+i end
      end
      if #rs==0 then table.remove(rules,j) else j=j+1 end
    end
  end
  
  local callbacks = {}
  function self.registerCallback(fun) callbacks[#callbacks+1] = fun end
  
  function self.handleEvent(ev,firingTime)
    for _,cb in ipairs(callbacks) do cb(ev) end
    
    local hasKeys = fromHash[ev.type] and fromHash[ev.type](ev) or {ev.type}
    for _,hashKey in ipairs(hasKeys) do
      for _,rules in ipairs(handlers[hashKey] or {}) do -- Check all rules of 'type'
        local i,m=1,nil
        for j=1,#rules do
          if not rules[j]._disabled then    -- find first enabled rule, among rules with same head
            m = match(rules[i][HANDLER],ev) -- and match against that rule
            break
          end
        end
        if m then                           -- we have a match
          for j=i,#rules do                 -- executes all rules with same head
            local rule=rules[j]
            if not rule._disabled then
              if invokeHandler({event = ev, time = firingTime, p=m, rule=rule}) == BREAK then return end
            end
          end
        end
      end
    end
  end
  
  -- This can be used to "post" an event into this QA... Ex. fibaro.call(ID,'RECIEVE_EVENT',{type='myEvent'})
  function QuickApp.RECIEVE_EVENT(_,ev)
    assert(isEvent(ev),"Bad argument to remote event")
    local time = ev.ev._time
    ev,ev.ev._time = ev.ev,nil
    setmetatable(ev,EventMT)
    if time and time+5 < os.time() then fibaro.warning(__TAG,fmt("Slow events %s, %ss",tostring(ev),os.time()-time)) end
    self.post(ev)
  end
  
  function self.postRemote(uuid,id,ev)
    if ev == nil then
      id,ev = uuid,id
      assert(tonumber(id) and isEvent(ev),"Bad argument to postRemote")
      ev._from,ev._time = plugin.mainDeviceId,os.time()
      fibaro.call(id,'RECIEVE_EVENT',{type='EVENT',ev=ev}) -- We need this as the system converts "99" to 99 and other "helpful" conversions
    else
      -- post to slave box in the future
    end
  end
  
  return self
end -- createEventEngine

local function quickVarEvent(d,_,post)
  local old={}; for _,v in ipairs(d.oldValue) do old[v.name] = v.value end
  for _,v in ipairs(d.newValue) do
    if not equal(v.value,old[v.name]) then
      post({type='quickvar', id=d.id, name=v.name, value=v.value, old=old[v.name]})
    end
  end
end

-- There are more, but these are what I seen so far...

local EventTypes = {
  AlarmPartitionArmedEvent = function(d,_,post) post({type='alarm', property='armed', id = d.partitionId, value=d.armed}) end,
  AlarmPartitionBreachedEvent = function(d,_,post) post({type='alarm', property='breached', id = d.partitionId, value=d.breached}) end,
  AlarmPartitionModifiedEvent = function(d,_,post) print(json.encode(d)) end,
  HomeArmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=d.newValue}) end,
  HomeDisarmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=not d.newValue}) end,
  HomeBreachedEvent = function(d,_,post) post({type='alarm', property='homeBreached', value=d.breached}) end,
  WeatherChangedEvent = function(d,_,post) post({type='weather',property=d.change, value=d.newValue, old=d.oldValue}) end,
  GlobalVariableChangedEvent = function(d,_,post) post({type='global-variable', name=d.variableName, value=d.newValue, old=d.oldValue}) end,
  GlobalVariableAddedEvent = function(d,_,post) post({type='global-variable', name=d.variableName, value=d.value, old=nil}) end,
  DevicePropertyUpdatedEvent = function(d,_,post)
    if d.property=='quickAppVariables' then quickVarEvent(d,_,post)
    else
      post({type='device', id=d.id or d.deviceId, property=d.property, value=d.newValue, old=d.oldValue})
    end
  end,
  CentralSceneEvent = function(d,_,post)
    d.id,d.icon = d.id or d.deviceId,nil
    post({type='device', property='centralSceneEvent', id=d.id, value={keyId=d.keyId, keyAttribute=d.keyAttribute}})
  end,
  SceneActivationEvent = function(d,_,post)
    d.id = d.id or d.deviceId
    post({type='device', property='sceneActivationEvent', id=d.id, value={sceneId=d.sceneId}})
  end,
  AccessControlEvent = function(d,_,post)
    post({type='device', property='accessControlEvent', id=d.id, value=d})
  end,
  CustomEvent = function(d,_,post)
    local value = api.get("/customEvents/"..d.name)
    post({type='custom-event', name=d.name, value=value and value.userDescription})
  end,
  PluginChangedViewEvent = function(d,_,post) post({type='PluginChangedViewEvent', value=d}) end,
  WizardStepStateChangedEvent = function(d,_,post) post({type='WizardStepStateChangedEvent', value=d})  end,
  UpdateReadyEvent = function(d,_,post) post({type='updateReadyEvent', value=d}) end,
  DeviceRemovedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='removed'}) end,
  DeviceChangedRoomEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='changedRoom'}) end,
  DeviceCreatedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='created'}) end,
  DeviceModifiedEvent = function(d,_,post) post({type='deviceEvent', id=d.id, value='modified'}) end,
  PluginProcessCrashedEvent = function(d,_,post) post({type='deviceEvent', id=d.deviceId, value='crashed', error=d.error}) end,
  SceneStartedEvent = function(d,_,post)   post({type='sceneEvent', id=d.id, value='started'}) end,
  SceneFinishedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='finished'})end,
  SceneRunningInstancesEvent = function(d,_,post) post({type='sceneEvent', id=d.id, value='instance', instance=d}) end,
  SceneRemovedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='removed'}) end,
  SceneModifiedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='modified'}) end,
  SceneCreatedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='created'}) end,
  OnlineStatusUpdatedEvent = function(d,_,post) post({type='onlineEvent', value=d.online}) end,
  ActiveProfileChangedEvent = function(d,_,post)
    post({type='profile',property='activeProfile',value=d.newActiveProfile, old=d.oldActiveProfile})
  end,
  ClimateZoneChangedEvent = function(d,_,post) --ClimateZoneChangedEvent
    if d.changes and type(d.changes)=='table' then
      for _,c in ipairs(d.changes) do
        c.type,c.id='ClimateZone',d.id
        post(c)
      end
    end
  end,
  ClimateZoneSetpointChangedEvent = function(d,_,post) d.type = 'ClimateZoneSetpoint' post(d,_,post) end,
  NotificationCreatedEvent = function(d,_,post) post({type='notification', id=d.id, value='created'}) end,
  NotificationRemovedEvent = function(d,_,post) post({type='notification', id=d.id, value='removed'}) end,
  NotificationUpdatedEvent = function(d,_,post) post({type='notification', id=d.id, value='updated'}) end,
  RoomCreatedEvent = function(d,_,post) post({type='room', id=d.id, value='created'}) end,
  RoomRemovedEvent = function(d,_,post) post({type='room', id=d.id, value='removed'}) end,
  RoomModifiedEvent = function(d,_,post) post({type='room', id=d.id, value='modified'}) end,
  SectionCreatedEvent = function(d,_,post) post({type='section', id=d.id, value='created'}) end,
  SectionRemovedEvent = function(d,_,post) post({type='section', id=d.id, value='removed'}) end,
  SectionModifiedEvent = function(d,_,post) post({type='section', id=d.id, value='modified'}) end,
  QuickAppFilesChangedEvent = function(_) end,
  ZwaveDeviceParametersChangedEvent = function(_) end,
  ZwaveNodeAddedEvent = function(_) end,
  RefreshRequiredEvent = function(_) end,
  DeviceFirmwareUpdateEvent = function(_) end,
  GeofenceEvent = function(d,_,post) post({type='location',id=d.userId,property=d.locationId,value=d.geofenceAction,timestamp=d.timestamp}) end,
  DeviceActionRanEvent = function(d,e,post)
    if e.sourceType=='user' then
      post({type='user',id=e.sourceId,value='action',data=d})
    elseif e.sourceType=='system' then
      post({type='system',value='action',data=d})
    end
  end,
}

local aEventEngine = nil

SourceTrigger = {}
class 'SourceTrigger'
function SourceTrigger:__init()
  self.refresh = RefreshStateSubscriber()
  self.eventEngine = createEventEngine()
  aEventEngine = self.eventEngine
  local function post(event,firingTime)
    setmetatable(event,EventMT)
    if debugFlags.sourceTrigger then fibaro.trace(__TAG,fmt("SourceTrigger: %s",tostring(event) // (debugFlags.truncLog or 80))) end
    self.eventEngine.handleEvent(event,firingTime)
  end
  local function filter(ev)
    if debugFlags.refreshEvents then
      fibaro.trace(__TAG,fmt("RefreshEvent: %s:%s",ev.type,json.encodeFast(ev.data)) // (debugFlags.truncLog or 80))
    end
    return true
  end
  local function handler(ev)
    if EventTypes[ev.type] then
      EventTypes[ev.type](ev.data,ev,post)
    end
  end
  self.refresh:subscribe(filter,handler)
end
function SourceTrigger:run() self.refresh:run() end
function SourceTrigger:subscribe(event,handler) --> subscription
  return self.eventEngine.addEventHandler(event,handler)
end
function SourceTrigger:unsubscribe(subscription)
  self.eventEngine.removeEventHandler(subscription)
end
function SourceTrigger:enableSubscription(subscription)
  subscription.enable()
end
function SourceTrigger:disableSubscription(subscription)
  subscription.disable()
end
function SourceTrigger:post(event,time,log,hook,customLog)
  return self.eventEngine.post(event,time,log,hook,customLog)
end
function SourceTrigger:registerCallback(fun)
  return self.eventEngine.registerCallback(fun)
end
function SourceTrigger:cancel(ref)
  return self.eventEngine.cancel(ref)
end
function SourceTrigger:postRemote(id,event)
  return self.eventEngine.postRemote(id,event)
end

local _marshalBool={['true']=true,['True']=true,['TRUE']=true,['false']=false,['False']=false,['FALSE']=false}

local function marshallFrom(v) 
  local fc = v:sub(1,1)
  if fc == '[' or fc == '{' then local s,t = pcall(json.decode,v); if s then return t end end
  if tonumber(v) then return tonumber(v)
  elseif _marshalBool[v ]~=nil then return _marshalBool[v ] end
  if v=='nil' then 
    return nil 
  end
  local test = v:match("^[0-9%$s]")
  if not test then return v end
  local s,t = pcall(toTime,v,true); return s and t or v 
end

local fmt = string.format
local escTab = {["\\"]="\\\\",['"']='\\"'}
local sortKeys = {"type","device","deviceID","id","name","properties","value","oldValue","val","key","arg","event","events","msg","res"}
local sortOrder={}
for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
local function keyCompare(a,b)
  local av,bv = sortOrder[a] or a, sortOrder[b] or b
  return av < bv
end

--gsub("[\\\"]",{["\\"]="\\\\",['"']='\\"'})
-- our own json encode, as we don't have 'pure' json structs, and sorts keys in order (i.e. "stable" output)

local function quote(s)
  local t = type(s)
  if t == 'string' then return s end
  return "["..tostring(s).."]"
end

local function prettyJsonFlat(e0) 
  local res,seen = {},{}
  local function pretty(e)
    local t = type(e)
    if t == 'string' then res[#res+1] = '"' res[#res+1] = e:gsub("[\\\"]",escTab) res[#res+1] = '"'
    elseif t == 'number' then res[#res+1] = e
    elseif t == 'boolean' or t == 'function' or t=='thread' or t=='userdata' then
      if e == json.null then res[#res+1]='null'
      else res[#res+1] = tostring(e) end
    elseif t == 'table' then
      local mt = getmetatable(e)
      if seen[e] then res[#res+1]="..rec.."
      elseif mt and mt.__tostring then
        local tstr = mt.__tostring
        mt.__tostring = nil
        res[#res+1] = tstr(e)
        mt.__tostring = tstr
      elseif next(e)==nil then
        if mt and mt.__isArray then
          res[#res+1]='[]'
        else
          res[#res+1]='{}'
        end
      elseif e[1] or #e>0 then
        seen[e]=true
        res[#res+1] = "[" pretty(e[1])
        for i=2,#e do res[#res+1] = "," pretty(e[i]) end
        res[#res+1] = "]"
        seen[e]=nil
      else
        seen[e]=true
        if e._var_  then res[#res+1] = fmt('"%s"',e._str) return end
        local k,kmap = {},{} for key,_ in pairs(e) do local ks = tostring(key) k[#k+1] = ks; kmap[ks]=key end
        table.sort(k,keyCompare)
        if #k == 0 then res[#res+1] = "[]" return end
        res[#res+1] = '{'; res[#res+1] = '"' t = k[1] res[#res+1] = t; res[#res+1] = '":' pretty(e[kmap[t]])
        for i=2,#k do
          res[#res+1] = ',"' t = k[i] res[#res+1] = t; res[#res+1] = '":' pretty(e[kmap[t]])
        end
        res[#res+1] = '}'
        seen[e]=nil
      end
    elseif e == nil then res[#res+1]='null'
    else error("bad json expr:"..tostring(e)) end
  end
  pretty(e0)
  return table.concat(res)
end

local alarmFuns = {}
function alarmFuns.armPartition(id)
  if id == 0 then
    return api.post("/alarms/v1/partitions/actions/arm",{})
  else
    return api.post("/alarms/v1/partitions/"..id.."/actions/arm",{})
  end
end

function alarmFuns.unarmPartition(id)
  if id == 0 then
    return api.delete("/alarms/v1/partitions/actions/arm")
  else
    return api.delete("/alarms/v1/partitions/"..id.."/actions/arm")
  end
end

function alarmFuns.tryArmPartition(id)
  local res,code
  if id == 0 then
    res,code = api.post("/alarms/v1/partitions/actions/tryArm",{})
    if type(res) == 'table' then
      local r = {}
      for _,p in ipairs(res) do r[p.id]=p.breachedDevices end
      return next(r) and r or nil
    else
      return nil
    end
  else
    local res,code = api.post("/alarms/v1/partitions/"..id.."/actions/tryArm",{})
    if res.armDelayed and #res.armDelayed > 0 then return {[id]=res.breachedDevices} else return nil end
  end
end

json.encodeFast = prettyJsonFlat

ER.alarmFuns = alarmFuns
ER.toSeconds = toSeconds
ER.midnight = midnight
ER.getWeekNumber = getWeekNumber
ER.now = now
ER.between = between
ER.hm2sec = hm2sec
ER.toTime = toTime
ER.sunCalc = sunCalc
ER.dateTest = dateTest
ER.marshallFrom = marshallFrom