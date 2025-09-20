local VERSION = "0.0.41"

fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags
local sourceTrigger

local fmt  = string.format
local function printf(...) print(string.format(...)) end
local findTriggers, evalArg
local Rules,RuleEnv = {},{}
ER.ruleEnv = RuleEnv
local catch = math.huge
local idFun = function() end
ER.rules = Rules

local function safeFmt(fm,...) if #{...}==0 then return fm else return fmt(fm,...) end end
local function Event(ev) return setmetatable(ev, ER.EventMT) end
local function INFO(...) fibaro.debug(__TAG,safeFmt(...)) end
local function ERROR(...) fibaro.error(__TAG,safeFmt(...)) end
local function WARNING(...) fibaro.warning(__TAG,safeFmt(...)) end

local dfltPrefix = {
  warningPrefix = "⚠️",
  ruleDefPrefix = "✅",
  triggerListPrefix = "⚡",
  dailyListPrefix = "🕒",
  startPrefix = "🎬", 
  stopPrefix = "🛑",
  successPrefix = "👍", -- 😀
  failPrefix = "👎", -- 🙁
  resultPrefix = "📋", 
  errorPrefix = "❌",
  waitPrefix = "💤", -- 😴
  waitedPrefix = "⏰", -- 🤗
}

local T2020 = os.time{year=2020, month=1, day=1, hour=0, min=0, sec=0}
local function timeStr(t) 
  if t < T2020 then return fmt("%02d:%02d:%02d",t//3600,t%3600//60,t%60) else return os.date("%Y-%m-%d %H:%M:%S",t) end
end
ER.T2020 = T2020

local function mkEvent(ev) return setmetatable(ev, ER.EventMT) end

local RuleMT = {
  __tostring = function(r) return fmt("[Rule:%d]", r.id) end,
}

local function started_rule(rule, env, event) 
  local str = tostring(event) 
  INFO("%s %s: %s", rule.startPrefix, rule, str) 
end
local function check_rule(rule, env, arg, ...) 
  local str = tostring(rule)
  if arg then INFO("%s %s", rule.successPrefix, str) else INFO("%s %s", rule.failPrefix, str) end
end
local function result_rule(rule, ...) 
  local res = {ER.args2str(...)}
  local rstr = #res>0 and table.concat(res,", ") or "<nil>"
  INFO("%s %s: %s", rule.resultPrefix, rule, rstr)
end
local function waiting_rule(rule, env, time)
  if time < T2020 then time= time + ER.now() end
  INFO("%s %s: ⏰%s", rule.waitPrefix, rule, timeStr(time))
end
local function waited_rule(rule, ...)
  INFO("%s %s: awake", rule.waitedPrefix, rule)
end

local function flatten(t)
  if type(t) == 'table' then 
    local r = {}
    for _,v in ipairs(t) do
      local v = flatten(v)
      if type(v) == 'table' then
        for _,w in ipairs(v) do r[#r+1] = w end
      else
        r[#r+1] = v
      end
    end
    return r
  else
    return t
  end
end

local ruleGetVar = { id = true, src = true }
local ruleSetFun = { name = true, enable = true, disable = true, start = true }
local function ruleWrapper(rule)
  return setmetatable({_rule = rule},{
    __tostring = function(r) return tostring(rule) end,
    __index = function(r,k)
      if ruleGetVar[k] then return (rule or {})[k] elseif ruleSetFun[k] then return function(...) if rule then rule[k](rule,...) end return r end end
    end,
  })
end

local function createRule(expr, data, opts)
  local self = { id = data.id, triggers = data.triggers, daily = data.daily, interval = data.interval, src = opts.src }
  local timers = {}
  local opts = opts or {}
  opts = table.copyShallow(opts)
  opts.env = RuleEnv

  for k,v in pairs(dfltPrefix) do if opts[k] == nil then self[k] = v else self[k] = opts[k] end end
  if opts.started and type(opts.started) == 'boolean' then opts.started = started_rule end
  if opts.check and type(opts.check) == 'boolean' then opts.check = check_rule end
  if opts.result and type(opts.result) == 'boolean' then opts.result = result_rule end
  if opts.waiting and type(opts.waiting) == 'boolean' then opts.waiting = waiting_rule end
  if opts.waited and type(opts.waited) == 'boolean' then opts.waited = waited_rule end

  local function rsetTimeout(f,t)
    local ref
    local function fun(...) 
      local res = {pcall(f,...)} 
      timers[ref] = nil
      return table.unpack(res)
    end
    ref = setTimeout(fun,t)
    timers[ref] = true
    return ref
  end
  local function rclearTimeout(ref) if timers[ref] then clearTimeout(ref) timers[ref] = nil end end
  local function hook(ref) timers[ref] = nil end -- When posts are posted.
  local function rpost(event,time) local ref = sourceTrigger:post(event,time,nil,hook) timers[ref] = true; return ref end
  opts.setTimeout,opts.clearTimeout = rsetTimeout, rclearTimeout 

  opts.cont = function(...) if opts.result then opts.result(self,...) end end
  opts.err = opts.err or function(str,warning) 
    if warning then end
    local msg = fmt("%s: %s (disabling)", self, str) 
    ERROR(msg)
    ER.sourceTrigger:post({type='rule-error',rule=self,message=msg},0)
    self:disable()
  end
  self.env = ER.createEnv(opts.cont,opts.err,opts)
  self.env.check = opts.check
  self.env.waiting = opts.waiting
  self.env.waited = opts.waited
  self.env.rule = self

  local dailyEvent = mkEvent({ type = 'Daily', id = self.id })
  local intervalEvent = mkEvent({ type = 'Interval', id = self.id })
  
  local skipTrigger = false
  if self.daily and next(self.daily)~=nil then
    sourceTrigger:subscribe(dailyEvent,function(event) 
      self:start(event.event) 
    end)
    skipTrigger = data.seenDaily
  end
  
  if self.interval then
    sourceTrigger:subscribe(intervalEvent,function(event) 
      self:start(event.event)
    end)
    skipTrigger = true
  end
  
  for evid,t in pairs(self.triggers) do
    if t.type ~= 'Daily' and t.type ~= 'Interval' then
      if not skipTrigger then
        local eventId = evid
        sourceTrigger:subscribe(t,function(event)
          self:start(event.event,eventId,event.p)
        end)
      elseif t._df then
        t._df = nil
        sourceTrigger:subscribe(t,function(event)
          self:setupDaily(false)
        end)
      end
    end
  end
  
  function self:dumpTriggers()
    printf("Rule %d triggers:",self.id)
    for _,t in pairs(self.triggers) do print(fmt("⚡ %s", json.encodeFast(t))) end
    if self.daily then 
      evalArg(function(values)
        if type(values) ~= 'table' then values = {values} else values = flatten(values) end
        for i,t in ipairs(values) do 
          if t ~= catch then printf("🕒 %s",timeStr(t)) end
        end
      end, self.env, table.unpack(self.daily))
    end
  end
  
  if opts.triggers then self:dumpTriggers() end

  local dailyTimers = {}
  local function clearDailyTimers() for t,_ in ipairs(dailyTimers) do rclearTimeout(t) end; dailyTimers = {} end

  function self:setupDaily(start,skew)
    local skew = skew or 0
    clearDailyTimers()
    if self.daily then
      evalArg(function(values)
        local now = ER.now()
        if type(values) ~= 'table' then values = {values} else values = flatten(values) end
        if opts.log then INFO("Setting up daily trigger for rule %d at %s", self.id, json.encodeFast(values)) end
        local catchFlag,n = false,0
        for _,t in ipairs(values) do n=n+1 if t == catch then catchFlag = true; break end end
        for _,t in ipairs(values) do
          if t ~= catch then
            local torg = t
            if type(t) ~= 'number' then return self.env.error("Invalid daily time: "..tostring(t)) end
            if t < now+skew then 
              t = t + 24*3600
              if catchFlag and start then rsetTimeout(function() self:start(dailyEvent) end,0) end -- Catch up, run immediately
            end
            dailyTimers[rpost({type='Daily',id=self.id,time=timeStr(torg)},t-now)]=true
          end
        end
      end, self.env, table.unpack(self.daily))
    end
  end
  
  local intervalTimer
  function self:setupInterval()
    if intervalTimer then rclearTimeout(intervalTimer); intervalTimer = nil end
    if self.interval then
      self.interval(function(value)
        if type(value) ~= 'number' then return self.env.error("Invalid interval time: "..tostring(value)) end
        local delay = 0
        if value < 0 then value=-value delay = (os.time() // value + 1)*value - os.time() end
        local nextTime = os.time() + delay
        local function loop()
          self:start(intervalEvent)
          nextTime = nextTime + value
          intervalTimer = rsetTimeout(loop, (nextTime-os.time())*1000)
        end
        intervalTimer = rsetTimeout(loop, (nextTime-os.time())*1000)
      end, self.env)
    end
  end
  
  function self:clearTimers() for t,_ in pairs(timers) do rclearTimeout(t) end; timers = {} end

  function self:enable() self.disabled = nil; self:setupDaily(false) self:setupInterval() end
  function self:disable() self.disabled = true; self:clearTimers()end

  function self:start(event,id,matchvars)
    if self.disabled then return end
    local env = table.copyShallow(self.env)
    env.trigger = event or {type='_startRule'}
    env.eventId = id
    matchvars = matchvars or {}
    matchvars.env = {event = event, p = matchvars}
    env.locals = matchvars
    if opts.started then opts.started(self,env,event) end
    expr(opts.cont,env)
    if event and event._df then self:setupDaily(false) end
  end

  setmetatable(self, RuleMT)
  self.short = fmt("%s %s",self,self.src // 80):gsub("%s*\n%s*"," ")
  return ruleWrapper(self)
end

local function defRule(expr, opts)
  local head = expr.__doc[2]
  local src = opts.src
  local id = #Rules+1
  local env = ER.createEnv(idFun,idFun,opts)
  for k,v in pairs({
    id = id,
    triggers = {},
    daily = nil,
    interval = nil,
    error = function(str) ERROR("❌ Rule %s: %s '%s'", tostring(id), tostring(str), src:gsub("%s*\n%s*"," ") // 80) os.exit() end, -- Only used when checking triggers
  }) do env[k] = v end
  
  local function cont()
    --triggers = env.triggers
  end

  findTriggers(head, cont, env)

  if env.interval and env.seenDaily then return env.error("Only one @daily or @@interval per rule") end
  if env.daily then env.triggers["D"]=Event({type='Daily',id=env.id}) end
  
  if env.interval == nil and env.daily == nil and next(env.triggers)==nil then
    return env.error("Rule has no triggers")
  end

  local rule = createRule(expr, env, opts)
  rule._rule:setupDaily(true)
  rule._rule:setupInterval()
  Rules[#Rules+1] = rule._rule
  printf("%s %s",rule._rule.ruleDefPrefix,rule._rule.short)
  return rule
end

local function etype(c) return c.__doc[1] end
local function earg(c,i) return c.__doc[1+i] end
local function eargs(c) return table.unpack(c.__doc,2) end

local function scanArg(cont, env, df, arg, ...)
  local rest = {...}
  findTriggers(arg,function() 
    if #rest > 0 then scanArg(cont, env, df, table.unpack(rest)) else cont() end
  end, env, df)
end

local function evalArgAux(vals, cont, env, arg, ...)
  local rest = {...}
  arg(function(...) 
    for _,v in ipairs({...}) do vals[#vals+1] = v end
    if #rest > 0 then evalArgAux(vals, cont, env, table.unpack(rest)) else cont(vals) end
  end, env)
end
function evalArg(cont, env, ...) evalArgAux({}, cont, env, ...) end

local evid = 0
function findTriggers(c, cont, env, df)
  if c == nil then
    return
  end
  local typ = etype(c)
  if typ == 'unop' then
    local op,arg,df = earg(c,1), earg(c,2),nil
    if op == 'daily' then
      if env.seenDaily then env.error("Only one @daily per rule") end
      env.seenDaily = true
      env.daily = env.daily or {}
      table.insert(env.daily,arg) 
      df = true
    elseif op == 'interv' then
      if env.interval then env.error("Only one @interv per rule") end
      env.triggers["I"]=Event({type='Interval',id=env.id})
      env.interval = arg 
    end
    scanArg(cont, env, df, arg)
  elseif typ == 'and' or typ == 'or' then 
    scanArg(cont, env, df, table.unpack(eargs(c)))
  elseif typ == 'getprop' then
    local obj = earg(c,2)
    local prop = earg(c,1)
    if ER.propFilters[prop] then 
      return scanArg(cont, env, df, obj)
    end
    obj(function(values)
      if not(type(values) == 'table' and not values._isPropObject) then values = {values} end
      for _,o in ipairs(values) do
        local obj = ER.resolvePropObject(o)
        if not obj:isProp(prop) then
          env.error(fmt("Unknown property in getprop trigger: %s %s",prop,tostring(obj)))
        end
        if not obj:isTrigger(prop) then return cont() end
        local tr = obj:getTrigger(o,prop)
        env.triggers["DEV:"..tostring(o)..prop]=Event(tr)
      end
      cont()
    end,env)
  elseif typ == 'const' then
    local t = earg(c,1)
    if type(t) == 'table' and type(t.type) == 'string' then
      evid = evid+1
      local eventId = "EV:"..evid
      c.evalHook = function(c,cont,env) 
        if not env.trigger then cont(false)
        elseif env.trigger.type == '_startRule' then cont(true)
        elseif env.eventId ~= eventId then return cont(false) else
        cont(true) end
      end
      env.triggers[eventId]=Event(t)
    end
    cont()
  elseif typ == 'table' then
    local args = {}
    for _,v in ipairs(eargs(c)) do 
      args[#args+1] = v.value 
    end
    if next(args) then
      c(function(tab) 
        if type(tab)=='table' and type(tab.type)=='string' then
          evid = evid+1
          local eventId = "EV:"..evid
          c.evalHook = function(c,cont,env) 
            if not env.trigger then cont(false)
            elseif env.trigger.type == '_startRule' then cont(true)
            elseif env.eventId ~= eventId then return cont(false) else
              cont(true) end
            end
            env.triggers[eventId]=Event(tab)
          end
        end, env)
      end
    scanArg(cont, env, df, table.unpack(args))
  elseif typ == 'binop' then
    local op,a1,a2 = earg(c,1), earg(c,2), earg(c,3) -- ToDo: Add 1 to a2
    a2 = ER.COMPFUNS.UNOP('add',a2,1)
    if op == 'betw' then
      if env.daily == nil then env.daily = {a1,a2}
      else 
        for _,v in ipairs({a1,a2}) do table.insert(env.daily,v) end
      end
    end
    scanArg(cont, env ,df, a1, a2)
  elseif typ == 'rulecheck' then
    scanArg(cont, env, df, earg(c,1))
  elseif typ == 'call' then
    local args = earg(c,2)
    if #args > 0 then
      scanArg(cont, env, df, table.unpack(args)) -- fun, args
    else cont() end
  elseif typ == 'var' then
    local name = earg(c,1)
    if ER.triggerVars[name] then
      env.triggers['TV:'..name]=Event({type='trigger-variable',name=name, _df=df})
    end
    cont()
  elseif typ == 'gvar' then
    local name = earg(c,1)
    env.triggers['GV:'..name]=Event({type='global-variable',name=name, _df=df})
    cont()
  elseif typ == 'qvar' then
    local name = earg(c,1)
    env.triggers['QV:'..name]=Event({type='quickvar',id=quickApp.id,name=name, _df=df})
    cont()
  elseif typ == 'aref' then
    scanArg(cont, env, df, eargs(c))
  else
    print("Unsupported trigger type:", etype(c), json.encodeFast(c))
  end
end

ER.defRule = defRule
ER.computedVar = {}

local function setupVariables(er)
  local var = er.variables
  var.sunrise, var.sunset,var.dawn,var.dusk = ER.sunCalc()
  var.midnight, var.vnum = ER.midnight(), tonumber(os.date("%V"))
end

local _er

local function midnightLoop(er)
  local dt,var = os.date("*t"), er.variables
  local midnight = os.time{year=dt.year, month=dt.month, day=dt.day+1, hour=0, min=0, sec=0}
  local function loop()
   setupVariables(er)
    for _,r in pairs(Rules) do
      if r.daily then r:setupDaily(false) end
      r.once = nil -- clear once flag every midnight
    end
    local dt = os.date("*t")
    local midnight = os.time{year=dt.year, month=dt.month, day=dt.day+1, hour=0, min=0, sec=0}
   setTimeout(loop, (midnight-os.time())*1000)
  end
  setTimeout(loop, (midnight-os.time())*1000)
end

function createER(qa)
  quickApp = qa
  if _er then return _er end
  _er = { qa = qa }
  ER._er = _er
  sourceTrigger = SourceTrigger()
  sourceTrigger:run()
  ER.sourceTrigger = sourceTrigger
  
  local env = {catch = catch}
  for k,v in pairs(env) do RuleEnv[k] = {v} end
  for k,v in pairs(ER.builtin) do RuleEnv[k] = {v} end

  local async = setmetatable({},{
    __index = function(t,k) local v = RuleEnv[k] return v and v[1] or nil end,
    __newindex = function(t,k,f) local var = RuleEnv[k] if var then var[1] = ER.ASYNCFUN(f) else RuleEnv[k] = {ER.ASYNCFUN(f)} end end,
  })

  _er.variables = setmetatable({ async = async },{
    __index = function(t,k) local v = RuleEnv[k] return v and v[1] or nil end,
    __newindex = function(t,k,v) 
      local var = RuleEnv[k] 
      if var then
        if var[1] ~= v then 
          if ER.triggerVars[k] then 
            ER.sourceTrigger:post({type='trigger-variable',name=k},0) 
          end
        end
        var[1] = v 
      else RuleEnv[k] = {v} end 
    end,
  })

  ER.triggerVars = {}
  _er.triggerVariables = setmetatable({},{ 
    __index = function(t,k) return  _er.variables[k] end,
    __newindex = function(t,k,v) ER.triggerVars[k]=true _er.variables[k] = v end
  })
  function _er.rule(str,opts)
    opts = opts or {}
    for k,v in pairs(_er.opts or {}) do if opts[k] == nil then opts[k] = v end end 
    opts.env = opts.env or RuleEnv
    return ER.eval(str,opts)() 
  end
  function _er.start() 
    setTimeout(function()
      setupVariables(_er)
      midnightLoop(_er)
      ER.customDefs(_er)
      print("=========== Loading rules ================")
      local t0 = os.clock()
      local stat,err = pcall(function() _er.qa:main(_er) end)
      if not stat then fibaro.error(__TAG,err) end
      printf("=========== Load time: %.3fs ============",os.clock()-t0)
    end,1)
  end
  _er.definePropClass = ER.definePropClass
  function _er.speed(time) return ER.speedTime(time,_er.start) end
  function _er.post(event,time) return sourceTrigger:post(event,time) end
  function _er.cancel(ref) return sourceTrigger:cancel(ref) end
  function _er.postRemote(id,event) sourceTrigger:postRemote(id,event) end
  _er.loadSimDevice = ER.loadSimDev
  _er.createAsyncFun = ER.ASYNCFUN
  _er.base64encode = ER.base64encode
  _er.eval = _er.rule -- alias
  setmetatable(_er,{
    __tostring = function() return fmt("EventRunner6 v%s",VERSION) end,
  })
  return _er
end

setmetatable(ER,{
  __tostring = function() return fmt("EventRunner6 v%s",VERSION) end,
  __call = function(_,qa) return createER(qa) end
})

function fibaro.loadLibrary(lf) lf(fibaro.EventRunner._er) end 