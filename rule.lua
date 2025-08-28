local version = "1.0.0"

fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags
local sourceTrigger

local fmt  = string.format
local function printf(...) print(string.format(...)) end
local findTriggers, evalArg
local Rules,RuleEnv = {},{}
local catch = math.huge
local idFun = function() end
ER.rules = Rules

local function INFO(...) fibaro.debug(__TAG,fmt(...)) end
local function ERROR(...) fibaro.error(__TAG,fmt(...)) end
local function WARNING(...) fibaro.warning(__TAG,fmt(...)) end

local emoji = {
  high_voltage = "⚡",
  clock = "🕒",
  check = "✅",
  clip_board = "📋",
  clapper_board = "🎬",
  start_flag = "🚦",
  stop_flag = "🛑",
  checkered_flag = "🏁",
  no_entry = "⛔",
  thumbs_up = "👍",
  thumbs_down = "👎"
}

local function mkEvent(ev) return setmetatable(ev, ER.EventMT) end

local RuleMT = {
  __tostring = function(r) return fmt("[Rule:%d]", r.id) end,
}

local function started_rule(self, event) INFO("🎬 %s: %s", self, tostring(event)) end
local function check_rule(rule, arg, ...) 
  if arg then INFO("👍 %s", rule) else INFO("👎 %s", rule) end
end
local function result_rule(rule, ...) 
  local res = {ER.args2str(...)}
  local rstr = #res>0 and table.concat(res,", ") or "<nil>"
  INFO("📋 %s: %s", rule, rstr) 
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

local function createRule(expr, data, opts)
  local self = { id = data.id, triggers = data.triggers, daily = data.daily, interval = data.interval, src = opts.src }
  local opts = opts or {}
  opts = table.copyShallow(opts)
  opts.env = RuleEnv

  if opts.started and type(opts.started) == 'boolean' then opts.started = started_rule end
  if opts.check and type(opts.check) == 'boolean' then opts.check = check_rule end
  if opts.result and type(opts.result) == 'boolean' then opts.result = result_rule end

  opts.cont = function(...) if opts.result then opts.result(self,...) end end
  opts.err = opts.err or function(str) ERROR("%s: %s", self, str) end
  self.env = ER.createEnv(opts.cont,opts.err,opts)
  self.env.check = opts.check
  self.env.rule = self

  local dailyEvent = mkEvent({ type = 'Daily', id = self.id })
  local intervalEvent = mkEvent({ type = 'Interval', id = self.id })
  
  local skipTrigger = false
  if self.daily then
    sourceTrigger:subscribe(dailyEvent,function(event) 
      self:start(event.event) 
    end)
    skipTrigger = true
  end
  
  if self.interval then
    sourceTrigger:subscribe(intervalEvent,function(event) 
      self:start(event.event)
    end)
    skipTrigger = true
  end
  
  for _,t in ipairs(self.triggers) do
    if t.type ~= 'Daily' and t.type ~= 'Interval' then
      if not skipTrigger then
        sourceTrigger:subscribe(t,function(event)
          self:start(event.event)
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
    for i,t in ipairs(self.triggers) do print(fmt("⚡ %s", json.encodeFast(t))) end
    if self.daily then 
      evalArg(function(values)
        if type(values) ~= 'table' then values = {values} else values = flatten(values) end
        for i,t in ipairs(values) do printf("🕒 %02d:%02d",t//3600,t%3600//60) end
      end, self.env, table.unpack(self.daily))
    end
  end
  
  if opts.listTriggers then self:dumpTriggers() end

  local dailyTimers = {}
  local function clearDailyTimers() for t,_ in ipairs(dailyTimers) do sourceTrigger:cancel(t) end; dailyTimers = {} end
  
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
              if catchFlag and start then setTimeout(function() self:start(dailyEvent) end,0) end -- Catch up, run immediately
            end
            dailyTimers[(sourceTrigger:post({type='Daily',id=self.id,time=fmt("%02d:%02d",torg//3600,torg%3600//60)},t-now))]=true
          end
        end
      end, self.env, table.unpack(self.daily))
    end
  end
  
  local intervalTimer
  function self:setupInterval()
    if intervalTimer then sourceTrigger:cancel(intervalTimer); intervalTimer = nil end
    if self.interval then
      self.interval(function(value)
        if type(value) ~= 'number' then return self.env.error("Invalid interval time: "..tostring(value)) end
        local delay = 0
        if value < 0 then value=-value delay = (os.time() // value + 1)*value - os.time() end
        local nextTime = os.time() + delay
        local function loop()
          self:start(intervalEvent)
          nextTime = nextTime + value
          intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
        end
        intervalTimer = setTimeout(loop, (nextTime-os.time())*1000)
      end, self.env)
    end
  end
  
  function self:start(event)
    if opts.started then opts.started(self,event) end
    local env = table.copyShallow(self.env)
    env.trigger = event
    expr(opts.cont,env)
    if event and event._df then self:setupDaily(false) end
  end

  setmetatable(self, RuleMT)
  self.short = fmt("%s %s",self,self.src // 80):gsub("%s*\n%s*"," ")
  return self
end

local function defRule(expr, opts)
  local head = expr.__doc[2]
  
  local id = #Rules+1
  local env = ER.createEnv(idFun,idFun,opts)
  for k,v in pairs({
    id = id,
    triggers = {},
    daily = nil,
    interval = nil,
    error = function(str) print(fmt("Error in rule %d: %s", id, str)) os.exit() end,
  }) do env[k] = v end
  
  local function cont()
    triggers = env.triggers
  end

  findTriggers(head, cont, env)

  if env.interval and env.daily then return env.error("Only one @daily or @@interval per rule") end
  if env.daily then table.insert(env.triggers,{type='Daily',id=env.id}) end
  
  if env.interval == nil and env.daily == nil and #env.triggers == 0 then
    return env.error("Rule has no triggers")
  end

  local rule = createRule(expr, env, opts)
  rule:setupDaily(true)
  rule:setupInterval()
  Rules[#Rules+1] = rule
  printf("✅ %s",rule.short)
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

function findTriggers(c, cont, env, df)
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
      table.insert(env.triggers,{type='Interval',id=env.id})
      env.interval = arg 
    end
    scanArg(cont, env, df, arg)
  elseif typ == 'and' or typ == 'or' then 
    scanArg(cont, env, df, table.unpack(eargs(c)))
  elseif typ == 'getprop' then
    local prop = earg(c,1)
    local pv = ER.getProps[prop]
    assert(pv, "Unknown property in getprop trigger: "..prop)
    if not pv[5] then return cont() end
    local obj = earg(c,2)
    obj(function(value)
      if tonumber(value) then
        table.insert(env.triggers,{type=pv[1],id=value,property=pv[3]})
      elseif type(value) == 'table' then
        for _,id in ipairs(value) do
          table.insert(env.triggers,{type=pv[1],id=id,property=pv[3]})
        end
      else
        env.error("Invalid object in getprop trigger: "..json.encodeFast(value))
      end
      cont()
    end,env)
  elseif typ == 'const' then
    local t = earg(c,1)
    if type(t) == 'table' and type(t.type) == 'string' then
      c.evalHook = function(c,cont,env) 
        if not env.trigger then return cont(false) end
        cont(table.equal(env.trigger,t))
      end
      table.insert(env.triggers,t)
    end
    cont()
  elseif typ == 'table' then
    local args = {}
    for _,v in ipairs(eargs(c)) do args[#args+1] = v.value end
    scanArg(cont, env, df, table.unpack(args))
  elseif typ == 'binop' then
    local op,a1,a2 = earg(c,1), earg(c,2), earg(c,3) -- ToDo: Add 1 to a2
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
      table.insert(env.triggers,{type='trigger-variable',name=name, _df=df})
    end
  elseif typ == 'gvar' then
    local name = earg(c,1)
    table.insert(env.triggers,{type='global-variable',name=name, _df=df})
  elseif typ == 'qvar' then
    local name = earg(c,1)
    table.insert(env.triggers,{type='quickvar',id=quickApp.id,name=name, _df=df})
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
    opts = opts or _er.opts or {} 
    opts.env = opts.env or RuleEnv
    return ER.eval(str,opts)() 
  end
  function _er.start() 
    setupVariables(_er)
    midnightLoop(_er)
    ER.customDefs(_er)
    print("=========== Loading rules ================")
    local t0 = os.clock()
    _er.qa:main(_er) 
    printf("=========== Load time: %.3fs ============",os.clock()-t0)
  end
  function _er.speed(time) return ER.speedTime(time,_er.start) end
  function _er.post(event,time) return sourceTrigger:post(event,time) end
  function _er.cancel(ref) return sourceTrigger:cancel(ref) end
  _er.loadSimDevice = ER.loadSimDev
  _er.eval = _er.rule -- alias
  setmetatable(_er,{
    __tostring = function() return fmt("EventRunner6 v%s",version) end,
  })
  return _er
end

setmetatable(ER,{
  __tostring = function() return fmt("EventRunner6 v%s",version) end,
  __call = function(_,qa) return createER(qa) end
})
