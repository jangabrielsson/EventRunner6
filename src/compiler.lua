fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags
local isHead,currentSrc = false,"" 

local fmt = string.format
local function idfun() end

local FUNCSTR = "funct".."ion"

local function docify(c)
  if type(c) ~= 'table' then return c end
  if c.__doc then 
    return docify(c.__doc)
  else
    local r = {}
    for k,v in pairs(c) do r[k] = docify(v) end
    return r
  end
end

local function CONTFUN(fun) 
  return setmetatable({ __continuationFun =true },{
    __call = function(t,...) return fun(...) end
  })
end

local function CONT(cont,doc) 
  return setmetatable({ __continuation = true, __doc = doc },{
    __call = function(t,...) return cont(...) end,
    __tostring = function(t) return (doc and json.encodeFast(docify(doc)) or "") end
  })
end

local function isContFun(obj) return type(obj) == 'table' and obj.__continuationFun end
local function isCont(obj) return type(obj) == 'table' and obj.__continuation end

local function IF(test, t, f)
  return CONT(function(cont,env)
    test(function(res)
      if res then
        t(cont, env)
      else
        if f then f(cont, env) else cont(false) end
      end
    end, env)
  end,{'if', test, t, f})
end

local function IFA(args)
  return CONT(function(cont,env)
    local function doTest(i)
      if i > #args then
        cont(true)
        return
      end
      local test = args[i]
      if not test.cond then test.body(cont, env)
      else
        test.cond(function(res)
          if res then
            test.body(cont, env)
          else
            doTest(i + 1)
          end
        end, env)
      end
      
    end
    doTest(1)
  end,{'ifa',args})
end

local function AND(...)
  local tests = {...}
  return CONT(function(cont, env)
    local function nextTest(index, res)
      if index > #tests then
        cont(res)
      else
        local test = tests[index]
        if isCont(test) or type(test) == FUNCSTR then
          test(function(res)
            if res then
              nextTest(index + 1, res)
            else
              cont(false)
            end
          end, env)
        elseif test then 
          nextTest(index + 1, test)
        else
          cont(test)
        end
      end
    end
    nextTest(1, false)
  end,{'and',tests})
end

local function OR(...)
  local tests = {...}
  return CONT(function(cont, env)
    local function nextTest(index, res)
      if index > #tests then
        cont(res)
      else
        local test = tests[index]
        if isCont(test) or type(test) == FUNCSTR then
          test(function(res)
            if res then 
              cont(res)
            else
              nextTest(index + 1, res)
            end
          end, env)
        elseif test then 
          cont(test) 
        else
          nextTest(index + 1, test)
        end
      end
    end
    nextTest(1, false)
  end,{'or',tests})
end

local function WHILE(cond,body)
  return CONT(function(cont, env)
    local function loop()
      cond(function(res)
        if res then 
          body(function() env:setTimeout(loop,0) end,env)
        else
          cont(true) -- Exit the loop
        end
      end, env)
    end
    loop()
  end,{'while',cond,body})
end

local function REPEAT(cond,body)
  return CONT(function(cont, env)
    local function loop()
      body(function()
        cond(function(res)
          if not res then env:setTimeout(loop, 0)
          else cont(true) end
        end, env)
      end,env)
    end
    loop()
  end,{'repeat',cond,body})
end

local function LOOP(body) -- loop forever - needs break/return
  return CONT(function(cont, env)
    local function loop()
      body(function() env:setTimeout(loop,0) end, env)
    end
    loop()
  end,{'loop',body})
end

local function FRAME(expr)
  return CONT(function(cont, env)
    local __cont = function(...) env:popEnv() cont(...) end
    env:pushEnv({__cont = {__cont}})
    expr(__cont, env)
  end,{'frame',expr})
end

--[[
local function mfor(vars, expr, body)
  local f,t,i = expr()
  kn ,vn = vars[1],vars[2]
  vars[kn] = i
  while true do
    vars[kn], vars[vn] = f(t,vars[kn])
    if vars[kn] == nil then break end
    body()
  end
end
--]]

local function FORIN(vars,expr,body)
  return FRAME(function(cont,env)
    local kn,vn = table.unpack(vars)
    env:pushVariable(kn,nil)
    env:pushVariable(vn,nil)
    expr(function(f,t,i)
      local k,v = i,nil
      local function loop()
        k,v = f(t,k)
        env:setVariable(kn,k)
        env:setVariable(vn,v)
        if not k then return cont(true) end
        body(function() env:setTimeout(loop,0) end, env)
      end
      loop()
    end,env)
  end),{'forin',vars,expr,body}
end

local function evalArgs(args, cont, env)
  if #args == 0 then
    cont({})
  else
    local results = {}
    local function nextArg(index)
      local arg = args[index]
      if type(arg) == FUNCSTR or isCont(arg) then
        arg(function(arg1,...)
          if index == #args then
            results[index] = arg1
            for _,a in ipairs({...}) do 
              results[#results+1] = a
            end
            cont(results)
          else
            results[index] = arg1
            nextArg(index + 1)
          end
        end, env)
      else
        results[index] = arg
        nextArg(index + 1)
      end
    end

    nextArg(1)
  end
end

local function BREAK()
  return CONT(function(cont, env)
    local frameCont = env:getVariable('__cont')
    env:setTimeout(function() frameCont(true) end, 0)
  end, {'break'})
end

local function PROGN(...)
  local statements = {...}
  return CONT(function(cont,env)
    evalArgs(statements, function(values)
      local val = true
      if #values > 0 then val = values[#statements] end
      cont(val)
    end,env)
  end,{'progn',statements})
end

local function TABLE(args)
  return CONT(function(cont, env)
    local tbl = {}
    local function nextVal(i)
      if i > #args then
        cont(tbl)
      else
        args[i].expr(function(key)
          args[i].value(function(val)
            tbl[key]=val
            nextVal(i + 1)
          end,env)
        end,env)
      end
    end
    nextVal(1)
  end, {'table', args})
end

local function checkArgs(a,t1,b,t2,env,e1,e2)
  if type(a) ~= t1 then env.error(fmt("%s: Expected %s, got: %s",e1,t1,a))  end
  if type(b) ~= t2 then env.error(fmt("%s: Expected %s, got: %s",e2,t2,b))  end
end

local T2020 = os.time{year=2020, month=1, day=1, hour=0}
local function coerce(a) if type(a) == 'table' then local mt=getmetatable(a) if mt and mt.__tostring then return mt.__tostring(a) end end return a end

local opFuns = {
  ['add'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 + arg2 end,
  ['sub'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 - arg2 end,
  ['mul'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 * arg2 end,
  ['div'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 / arg2 end,
  ['mod'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 % arg2 end,
  ['pow'] = function(arg1,arg2,env,e1,e2) checkArgs(arg1,'number',arg2,'number',env,e1,e2) return arg1 ^ arg2 end,
  ['eq'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 == arg2 end,
  ['neq'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 ~= arg2 end,
  ['lt'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 < arg2 end,
  ['lte'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 <= arg2 end,
  ['gt'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 > arg2 end,
  ['gte'] = function(arg1,arg2,env,e1,e2) arg1,arg2 = coerce(arg1),coerce(arg2) return arg1 >= arg2 end,
  ['betw'] = function(arg1,arg2,env,e1,e2)
    checkArgs(arg1,'number',arg2,'number',env,e1,e2)
    if arg1 > T2020 then
      local tn = os.time()
      return arg1 <= tn and tn <= arg2
    else
      local ts = os.date("*t")
      local t = ts.hour*3600 + ts.min*60 + ts.sec
      arg2 = arg2 >= arg1 and arg2 or arg2 + 24*3600
      t = t >= arg1 and t or t + 24*3600
      return arg1 <= t and t <= arg2
    end
  end,
  ['nilco'] = function(arg1,arg2,env,e1,e2) if arg1 ~= nil then return arg1 else return arg2 end end,
}

local function BINOP(op,exp1,exp2)
  return CONT(function(cont, env)
    exp1(function(v1)
      exp2(function(v2)
        if opFuns[op] then
          local stat,err = pcall(function()
            local res = opFuns[op](v1, v2, env, exp1, exp2)
            cont(res)
          end)
          if not stat then
            env.error(fmt("%s: %s %s %s",(err or ""):match("%d+:%s*(.*)") or err, op, exp1, exp2))
          end
        else
          env.error("Unknown operator: " .. tostring(op))
        end
      end, env)
    end, env)
  end, {'binop', op, exp1, exp2})
end

local unOpFuns = {
  plus = function(v,a,b,env) return ER.toTime("+/"..v) end,
  next = function(v,a,b,env) return ER.toTime("n/"..v) end,
  today = function(v,a,b,env) return ER.toTime("t/"..v) end,
  add = function(v,a,b,env) return v+(a or b) end,
  neg = function(v,a,b,env) return - v end,
  sub = function(v,a,b,env) return a and a-v or v-b end,
  mul = function(v,a,b,env) return v*(a or b) end,
  div = function(v,a,b,env) return a and a/v or v/b  end,
  ['not'] = function(v,a,b,env) return not v  end,
  daily = function(v,a,b,env)
    local e = env.trigger
    if not e then return env.error("No trigger in environment") end
    return e.type == 'Daily'  -- False if not a daily event triggering
  end,
  interv = function(v,a,b,env)
    local e = env.trigger
    if not e then return env.error("No trigger in environment") end
    return e.type == 'Interval'  -- False if not a daily event triggering
  end,
}


local function UNOP(op, expr, v1, v2) --UNOP('add', expr, 1) end
  return CONT(function(cont, env)
    expr(function(val)
      if unOpFuns[op] then
        local res = unOpFuns[op](val,v1,v2,env)
        cont(res)
      else
        env.error("Unknown operator: " .. tostring(op))
      end
    end, env)
  end, {'unop', op, expr, v1, v2})
end

local function CONST(n) 
  local c
  c = CONT(function(cont,env) 
    if c.evalHook then c.evalHook(c,cont,env)
    else cont(n) end
  end, {'const', n})
  return c
end

local function CALL(fun,...)
  local args = {...}
  return CONT(function(cont,env) -- Return value out of expr
    fun(function(fval)
      local isCont = isContFun(fval)
      if isCont or type(fval) == FUNCSTR then
        evalArgs(args, function(exprs)
          if isCont then -- continuation
            fval(cont,env,table.unpack(exprs)) 
          else
            local res = {fval(table.unpack(exprs))}
            cont(table.unpack(res))
          end
        end,env)
      else env.error(fmt("%s: Expected function, got: %s", tostring(fun), tostring(fval))) end
    end, env)
  end, {'call', fun, args})
end

local function CALLOBJ(obj, fun, ...)
  local args = {...}
  return CONT(function(cont,env) -- Return value out of expr
    obj(function(objval)
      if type(objval) ~= 'table' then
        return env.error(fmt("%s: Expected table for :call, got: %s - %s", tostring(fun), tostring(objval), tostring(obj)))
      end
      local fval = objval[fun]
      local isCont = isContFun(fval)
      if isCont or type(fval) == FUNCSTR then
        evalArgs(args, function(exprs)
          if isCont then -- continuation
            fval(cont,env,objval,table.unpack(exprs)) 
          else
            local res = {fval(objval,table.unpack(exprs))}
            cont(table.unpack(res))
          end
        end,env)
      else env.error(fmt("%s: Expected function, got: %s - %s", tostring(fun), tostring(fval), tostring(fun))) end
    end, env)
  end, {'call', fun, args})
end

local function GETPROP(prop,obj)
  return CONT(function(cont,env)
    obj(function(o)
      local res = ER.executeGetProp(o,prop,env)
      cont(res)
    end,env)
  end, {'getprop', prop, obj})
end

local function AREF(tab,key)
  return CONT(function(cont,env) -- Return value out of expr
    tab(function(t)
      if type(t) == 'table' then
        key(function(k)
          cont(t[k])
        end,env)
      else env.error(fmt("Expected table, got: %s - %s.%s",tostring(t),tostring(tab),tostring(key))) end
    end,env)
  end, {'aref', tab, key})
end

local function VAR(name,cvar) 
  return CONT(function(cont,env) 
    if cvar then cont(ER.computedVar[name]()) else cont(env:getVariable(name)) end
  end, {'var', name})
end

local function GVAR(name) return CONT(function(cont,env) cont(ER.marshallFrom(fibaro.getGlobalVariable(name))) end, {'gvar', name}) end
local function QVAR(name) return CONT(function(cont,env) cont(quickApp:getVariable(name)) end, {'qvar', name}) end
local function IVAR(name) return CONT(function(cont,env) cont(quickApp:internalStorageGet(name)) end, {'ivar', name}) end

local function ASSIGNM(vars,exprs)
  return CONT(function(cont,env) -- Return value out of expr
    evalArgs(exprs, function(values)
      local function nextAssign(i)
        if i > #vars then cont(true)
        else 
          vars[i](env,values[i],nextAssign,i+1)
        end
      end
      nextAssign(1)
    end,env)
  end,{'assignm',vars,exprs})
end

local function LOCAL(vars,exprs)
  return CONT(function(cont,env)
    evalArgs(exprs, function(values)
      for i,var in ipairs(vars) do
        env:pushVariable(var, values[i])
      end
      cont(true)
    end,env)
  end, {'local', vars, exprs})
end

local function INCVAR(name, op, value)
  return CONT(function(cont, env)
    value(function(val)
      local var = env:getVariable(name)
      if tonumber(var)==nil then return env.error("Not a number: "..tostring(name)) end
      local newValue = opFuns[op](var,val)
      env:setVariable(name, newValue)
      cont(newValue)
    end,env)
  end, {'incvar', name, op, value})
end

local function VARARGSTABLE(name)
  return CONT(function(cont, env)
    local var = env:getVariable('...')
    if type(var) == 'table' then
      cont(var)
    else
      env.error("Expected table for varargs, got: " .. tostring(var))
    end
  end, {'varargs', name})
end

local function ASYNCFUN(fun) --- fun(cb,...)
  return CONTFUN(function(cont, env, ...)
    local timedout,ref = false,nil
    local cb = function(...) if ref then env:clearTimeout(ref) end; if not timedout then cont(...) end end
    local acb = setmetatable({env = env} , { __call = function(t,...) return cb(...) end })
    local timeout = fun(acb,...)
    timeout = tonumber(timeout) or 3000
    if timeout >= 0 then
      ref = env:setTimeout(function() 
        timedout = true
        env.error(fmt("%s: Async function timeout after %s ms", tostring(fun), tostring(timeout)))
      end, timeout)
    end
  end)
end

local function FUNC(params, body)
  return CONT(function(cont,env) -- Return value out of expr
    cont(CONTFUN(function(cont,env,...)
      local __cont = function(...) 
         env:popEnv() cont(...)
      end
      env:pushEnv({__cont = {__cont}, __return = {__cont}})
      local args = {...}
      for i=1,#params-1 do
        local param = params[i]
        local value = args[i]
        env:pushVariable(param,value)
      end
      local param = params[#params]
      if param == '...' then
        local vararg = {}
        for i=#params,#args do vararg[#vararg+1] = args[i] end
        env:pushVariable(param, vararg)
      else
        local value = args[#params]
        env:pushVariable(param,value)
      end
      --print(json.encode(args),json.encodeFast(cleanVars(env.vars)))
      body(__cont,env)
    end))
  end,{'func',params,body})
end

local function RETURN(...)
  local args = {...}
  return CONT(function(cont,env) -- Return value out of expr
    local ret = env:getVariable('__return') or env.cont or cont
    evalArgs(args, function(exprs)
      --print("RET", ret==cont, json.encodeFast(exprs),tostring(ret))
      ret(table.unpack(exprs))
    end, env)
  end, {'return', args})
end

local function args2str(...) local r = {} for i,v in ipairs({...}) do r[i] =type(v)=='table' and json.encodeFast(v) or tostring(v) end return table.unpack(r) end
ER.args2str = args2str

local function findVar(name,vars)
  local lastEnv = vars
  while vars do
    local v = vars[name]
    if v then return v else lastEnv = vars; vars = vars.__parent end
  end
  return nil,lastEnv
end
local function createEnv(cont,err,opts)
  local env = { vars = opts.env or {}, error = err, cont = cont }
  local globalEnv = opts.env
  function env:pushVariable(name,value) local v = self.vars[name] if v then v[1]=value else self.vars[name] = {value} end end
  function env:setVariable(name,val,global)
    if global then 
      local v = globalEnv[name]
      if v then v[1]=val else globalEnv[name] = {val} end
    end
    local v,last = findVar(name,self.vars) 
    if v then v[1]=val else last[name] = {val} end 
  end
  function env:getVariable(name) 
    local v = findVar(name,self.vars)  
    if v then return v[1] else return _G[name] end 
  end
  function env:pushEnv(e) e = e or {} e.__parent = self.vars; self.vars = e end
  function env:popEnv() self.vars = self.vars.__parent or {} end
  local cst,cct = opts.setTimeout or setTimeout,opts.clearTimeout or clearTimeout
  function env:setTimeout(f,t) return cst(f,t) end
  function env:clearTimeout(ref) return cct(ref) end
  return env
end
ER.createEnv = createEnv

local function RULE(expr,opts) return function() return ER.defRule(expr,opts) end end
local function RULECHECK(rule) return 
  CONT(function(cont,env) 
    if env.locals then
      for k,v in pairs(env.locals) do env:pushVariable(k,v) end
    end
    rule(function(...)
      if env.check then env.check(env.rule,...) end
      cont(...)
    end,env) 
  end,{'rulecheck',rule}) 
end

local function EXPR(expr,opts)
  return function()
    opts = opts or {}
    local res = {}
    local cont = opts.cont or function(...) 
      res = {...} 
      if not opts.nolog then print(args2str(...)) end 
    end
    local src = opts.src or "<expr>"
    local err = opts.err or function(str) print(fmt("❌ '%s': %s", src // 80,str)) end
    local env = createEnv(cont, err, opts)
    env.src = src
    env.env = opts.env or ER.ruleEnv
    expr(cont, env)
    return table.unpack(res)
  end
end

local funs = {
  IF = IF,
  IFA = IFA,
  AND = AND,
  OR = OR,
  WHILE = WHILE,
  REPEAT = REPEAT,
  FORIN = FORIN,
  LOOP = LOOP,
  PROGN = PROGN,
  CONST = CONST,
  AREF = AREF,
  BINOP = BINOP,
  UNOP = UNOP,
  CALL = CALL,
  CALLOBJ = CALLOBJ,
  GETPROP = GETPROP,
  FUNC = FUNC,
  EXPR = EXPR,
  RULE = RULE
}


local function compError(str,expr) 
  local dbg = expr._dbg or { to = 1, from = 1}
  local from,to = dbg.from,dbg.to
  ER.perror('Compiler',str,from,to,currentSrc,nil)
end

local compa, comp = function(_) end, {}

local function compileList(list) local r = {} for _,e in ipairs(list) do r[#r+1] = compa(e) end return r end

function comp.table(expr)
  if expr.const then return CONST(expr.value) end
  local args = {}
  for _,v in ipairs(expr.value) do
    local key = v.key and {type='const',value=v.key} or v.expr
    args[#args+1] = { expr = compa(key), value = compa(v.value) }
  end
  return TABLE(args)
end

locals = {}
local function pushLocals(ls) ls.__parent = locals; locals = ls end
local function popLocals() locals = locals.__parent end
local function isLocal(name) return locals and locals[name] end

function comp.block(expr,noframe)
  if expr.locals then pushLocals(expr.locals) end
  local args = compileList(expr.statements)
  if expr.locals then popLocals() end
  noframe = noframe or not expr.scope
  if #args == 1 then return noframe and args[1] or FRAME(args[1]) end
  return noframe and PROGN(table.unpack(args)) or FRAME(PROGN(table.unpack(args)))
end

function comp.binop(expr)
  if expr.op == 'assign' then compError(fmt("'assign' not allowed in%s expression",(isHead and " trigger" or "")),expr) end
  local exp1 = compa(expr.exp1)
  local exp2 = compa(expr.exp2)
  return BINOP(expr.op, exp1, exp2)
end

function comp.seqop(expr)
  local args = compileList(expr.exprs)
  if expr.op == 'or' then return OR(table.unpack(args))
  elseif expr.op == 'and' then return AND(table.unpack(args))
  else error("Unknown seqop: "..tostring(expr.op)) 
  end
end

function comp.unop(expr)
  return UNOP(expr.op, compa(expr.exp), expr.a, expr.b)
end

local builtin = {}
local BUILTIN = function(name)
  if builtin[name] then return funs[builtin[name]] end
  return nil
end

comp['break'] = function(expr)
  if isHead then compError("'break' not allowed in trigger expression",expr) end
  return BREAK()
end

comp['breakif'] = function(expr)
  return IF(compa(expr.cond), BREAK())
end

function comp.call(expr)
  local args = compileList(expr.args)
  local fun = expr.fun.type == 'name' and BUILTIN(expr.fun.value) 
  if fun then return fun(table.unpack(args))
  else
    fun = compa(expr.fun)
    return CALL(fun, table.unpack(args))
  end
end

function comp.objcall(expr)
  local args = compileList(expr.args)
  local obj = compa(expr.obj)
  local fun = expr.fun
  return CALLOBJ(obj, fun, table.unpack(args))
end

function comp.name(expr) 
  if expr.vt == 'ev' then
    local cvar = ER.computedVar[expr.value]
    return VAR(expr.value,cvar) 
  elseif expr.vt == 'gv' then return GVAR(expr.value:sub(2)) 
  elseif expr.vt == 'qv' then return QVAR(expr.value:sub(3)) 
  elseif expr.vt == 'sv' then return IVAR(expr.value:sub(4)) 
  else error("Not implemented:"..tostring(expr.vt)) end
end

comp['return'] = function(expr)
  if isHead then compError("'return' not allowed in trigger expression",expr) end
  local args = compileList(expr.exp)
  return RETURN(table.unpack(args))
end


comp['if'] = function(expr)
  if isHead then compError("'if/case' not allowed in trigger expression",expr) end
  local args = {}
  for _,c in ipairs(expr.args) do
    args[#args+1] = { cond = c.cond and compa(c.cond) or nil, body = compa(c.body) }
  end
  return IFA(args)
end

local function condFRAME(frame,expr) return frame and FRAME(expr) or expr end

comp['while'] = function(expr)
  if isHead then compError("'while' not allowed in trigger expression",expr) end
  local frame,locals = expr.body.scope,expr.body.locals; expr.body.scope = nil
  return condFRAME(frame,WHILE(compa(expr.cond), compa(expr.body)))
end
comp['repeat'] = function(expr)
  if isHead then compError("'repeat' not allowed in trigger expression",expr) end
  local frame,locals = expr.body.scope,expr.body.locals; expr.body.scope = nil
  return condFRAME(frame,REPEAT(compa(expr.cond), compa(expr.body)))
end

comp['loop'] = function(expr)
  if isHead then compError("'loop' not allowed in trigger expression",expr) end
  local args = compileList(expr.statements)
  if #args == 1 then return LOOP(args[1]) end
  return LOOP(PROGN(table.unpack(args)))
end

comp['forin'] = function(expr)
  if isHead then compError("'for' not allowed in trigger expression",expr) end
  return FORIN(expr.names,compa(expr.exp[1]),compa(expr.body))
end

function comp.num(expr) return CONST(expr.value) end
function comp.const(expr) return CONST(expr.value) end
function comp.str(expr) return CONST(expr.value) end

function comp.aref(expr)
  local table = compa(expr.tab)
  local key = compa({type='num',value=expr.idx})
  return AREF(table, key)
end

comp['local'] = function(expr)
  return LOCAL(expr.names,compileList(expr.exprs or {}))
end

function comp.assign(expr)
  if isHead then compError("'assign' not allowed in trigger expression",expr) end
  local exprs = compileList(expr.exprs)
  local vars = {}
  for _,v in ipairs(expr.vars) do
    if v.type == 'name' then
      if v.vt == 'ev' then
      local var = v.value
      vars[#vars+1] = function(env,val,cont,i)
        if ER.triggerVars[var] then
          local oldValue = env:getVariable(var)
          if oldValue ~= val then
            ER.sourceTrigger:post({type='trigger-variable',name=var},0)
          end
        end
        env:setVariable(var,val,not isLocal(var)) 
        cont(i)
      end
    elseif v.vt == 'gv' then
      local var = v.value:sub(2)
      vars[#vars+1] = function(env,val,cont,i) 
        fibaro.setGlobalVariable(var,type(val)=='string' and val or json.encodeFast(val))
        cont(i)
      end
    elseif v.vt == 'qv' then
      local var = v.value:sub(3)
      vars[#vars+1] = function(env,val,cont,i) 
        quickApp:setVariable(var,val)
        cont(i)
      end
    elseif v.vt == 'sv' then
      local var = v.value:sub(4)
      vars[#vars+1] = function(env,val,cont,i) 
        quickApp:internalStorageSet(var,val)
        cont(i)
      end
    else
      error("Not implemented: "..tostring(v.vt))
    end
    elseif v.type == 'aref' then
      local var = {tab=compa(v.tab), idx=v.idx}
      vars[#vars+1] = function(env,val,cont,i) --{type='aref',tab=compa(v.tab), idx=v.idx}
        var.tab(function(tab)
          tab[v.idx] = val
          cont(i)
        end,env)
      end
    elseif v.type == 'getprop' then
      local var = {obj=compa(v.obj), prop=v.prop}
      vars[#vars+1] = function(env,val,cont,i)
        var.obj(function(obj)
          ER.executeSetProp(obj,var.prop,val,env)
          cont(i)
        end,env)
      end
    else
      error("Not supported assignment: "..tostring(v.type))
    end
  end
  return ASSIGNM(vars, exprs)
end

function comp.incvar(expr) 
  if isHead then compError("'var incremental' not allowed in trigger expression",expr) end
  return INCVAR(expr.name,expr.op,compa(expr.value)) 
end

function comp.getprop(expr) return GETPROP(expr.prop,compa(expr.obj)) end

local function makeVarAssign(var) return function(env,val,cont,i) env:setVariable(var,val) cont(i) end end

function comp.functiondef(expr)
  if isHead then compError("'function definition' not allowed in trigger expression",expr) end
  local fun = compa(expr.fun)
  return ASSIGNM({makeVarAssign(expr.name[1])},{fun})
end

comp['function'] = function(expr)
  local fun = compa(expr.body)
  return FRAME(FUNC(expr.params, fun))
end

comp['functionexpr'] = function(expr) return compa(expr.fun) end

comp['varargstable'] = function(expr) return VARARGSTABLE() end

function compa(expr)
  if comp[expr.type] then return comp[expr.type](expr)
  else error("Not implemented:"..tostring(expr.type)) end
end

function compile(ast)
  if ast.type == 'block' then
    return comp.block(ast,false)
  elseif ast.type == 'ruledef' then
    local head = ast.head
    local body = ast.body
    isHead = true
    local h = compa(head)
    isHead = false
    local b = compa(body)
    return IF(RULECHECK(h),b)
  else error("Not implemented:"..tostring(ast.type)) end
end

local function eval(str,opts)
  assert(type(str) == "string","Expected string")
  currentSrc = str
  opts = opts or {}
  local isRule = false
  local stat,ast = xpcall(function()
    local tkns = ER.tokenize(str)
    if opts.tokens then tkns.dump() end
    if tkns.containsType('t_rule') then
      table.insert(tkns.stream,1,{type='t_rulebegin',dbg={from=0,to=0}})
      table.insert(tkns.stream,{type='t_ruleend',dbg={from=0,to=0}})
      isRule = true
    end
    ast,j,k = ER.parse(tkns)
    return ast
  end,function(e)
    if fibaro.plua then 
      local info = debug.getinfo(2)
       dbg = debug.traceback()
    end
    return e
  end)
  if not stat then print(ast) return idfun end
  if opts.tree then print(json.encodeFormated(ast)) end
  locals = nil
    local cstat,res = pcall(function()
    local cont = compile(ast)
    opts.src = ast._src
    return isRule and RULE(cont,opts) or EXPR(cont,opts)
  end)
  if not cstat then print(res) return idfun else return res end
end

ER.compile = compile
ER.eval = eval
ER.ASYNCFUN = ASYNCFUN
ER.COMPFUNS = funs