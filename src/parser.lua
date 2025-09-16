
fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner 
local debugFlags = ER.debugFlags

local fmt = string.format
local patterns = {}

ER._opers = {
  ['%neg']={op=false, prio=14, unop=true, trans='neg'},        -- unary minus
  ['t/']  ={op=true,  prio=14, unop=true, trans='today'},      -- today time constant, t/10:00
  ['n/']  ={op=true,  prio=14, unop=true, trans='next'},       -- next today time constant, n/10:00
  ['+/']  ={op=true,  prio=14, unop=true, trans='plus'},       -- from today time constant, +/10:00
  ['$']   ={op=true,  prio=14, unop=true, trans='gv'},         -- global variable, $var
  ['$$']  ={op=true,  prio=14, unop=true, trans='qv'},         -- quickApp variable, $var
  ['$$$']  ={op=true,  prio=14,unop=true, trans='pv'},         -- Persistent variable, $var
  ['..']  ={op=true,  prio=9,             trans='betw'},       -- between operator, 10:00..11:00
  ['...'] ={op=true,  prio=9,             trans='betwo'},  
  ['@']   ={op=true,  prio=9,  unop=true, trans='daily'},      -- day rule, @10:00
  ['@@']  ={op=true,  prio=9,  unop=true, trans='interv'},     -- interval rule, @@00:05
  ['+']   ={op=true, prio=11,             trans='add'},
  ['-']   ={op=true, prio=11,             trans='sub'},
  ['*']   ={op=true, prio=12,             trans='mul'},
  ['/']   ={op=true, prio=12,             trans='div'},
  ['++']  ={op=true, prio=10,             trans='conc'},         -- string concatenation
  ['==='] ={op=true, prio=9,              trans='match'},        -- string match
  ['%']   ={op=true, prio=12,             trans='mod'},          -- modulo
  ['^']   ={op=true, prio=12,             trans='pow'},          -- power
  ['==']  ={op=true, prio=6,              trans='eq'},           -- equal
  ['<=']  ={op=true, prio=6,              trans='lte'},
  ['>=']  ={op=true, prio=6,              trans='gte'},
  ['~=']  ={op=true, prio=6,              trans='neq'},          -- not equal
  ['>']   ={op=true, prio=6,              trans='gt'},
  ['<']   ={op=true, prio=6,              trans='lt'},
  ['&']   ={op=true, prio=5,              trans='and'},        -- logical and
  ['|']   ={op=true, prio=4,              trans='or'},         -- logical or
  ['??']  ={op=true, prio=4,              trans='nilco'},      -- nil coalescing
  ['!']   ={op=true, prio=5.1, unop=true, trans='not'},        -- logical not
--  ['in']  ={op=true, prio=0.1,            trans='in'},
  ['=']   ={op=true, prio=0,              trans='assign'},       -- assignment
}
local keyword={
  ['if']='t_if',['then']='t_then',['else']='t_else',['elseif']='t_elseif',['end']='t_end',['while']='t_while',
  ['repeat']='t_repeat',['do']='t_do',['until']='t_until',['return']='t_return',['for']='t_for',['fun'..'ction']='t_function',
  ['local']='t_local',['break']='t_break',['in']='t_in',['||']='t_||', ['>>']='t_>>',['case']='t_case',
  ['+=']='t_addinc',['-=']='t_subinc',['*=']='t_mulinc',['/=']='t_divinc',
  ['=>']='t_rule',
  ['true']='t_true',['false']='t_false',['nil']='t_nil',
  [';'] = 't_semi',[',']='t_comma',['.']='t_dot',[':']='t_ddot',
  [')'] = 't_rpar',['(']='t_lpar',['}']='t_rcur',['{']='t_lcur',['[']='t_lbra',[']']='t_rbra',
}
local opers0 = ER._opers
local opers1 = {} for k,v in pairs(opers0) do opers1[v.trans] = v end
ER._opers1 = opers1

local function calcLineOffs(lines, pos)
  local line,offs,llength = 1,0,0
  for i, l in ipairs(lines) do
    local len = #l + 1
    if pos <= offs + len then
      line = i; llength = #l
      break
    end
    offs = offs + len
  end
  return line, pos - offs, llength
end

local TKMT = {__tostring = function (err) 
  if type(err) == 'string' then return err end
  local src = err.src or ""
  local lines,buff = {},{}
  for line in src:gmatch("([^\n]*)\n?") do lines[#lines+1]=line end
  local startline,startoffs,startLength = calcLineOffs(lines, err.from)
  local endline,endoffs,endLength = calcLineOffs(lines, err.to)
  if startline == endline then
    local line = lines[startline] or ""
    local ptr = string.rep('&nbsp;',startoffs-1)..fmt("<font color='orange'>%s</font>",string.rep('^',endoffs-startoffs+1))
    buff[#buff+1] = fmt("%s: %s at pos %d",err.type,err.msg,err.from)
    if startline > 1 then buff[#buff+1] = lines[1] end
    buff[#buff+1] = line
    buff[#buff+1] = ptr
    return table.concat(buff,"<br>")
  end
end}

local function createError(typ,msg,from,to,src,mt)
  return setmetatable({type=typ, msg=msg, from=from, to=to, src=src, _err=true},mt or TKMT)
end
local function perror(typ,msg,from,to,src,mt) error(createError(typ,msg,from,to,src,mt)) end
ER.createParseError = createError
ER.perror = perror

local function stream(tab,src)
  local p,self=0,{ stream=tab, eof={type='t_eof', value='', dbg={from=tab[#tab].dbg.from, to=tab[#tab].dbg.to}} }
  self.src = src
  function self.getP() return p end
  function self.setP(np) p=np end
  function self.next() p=p+1 local r = p<=#tab and tab[p] or self.eof; return r end
  function self.last() return tab[p] or self.eof end
  function self.prev() return tab[p-1] or self.eof end
  function self.matchp(t,v) 
    local t2 = self.peek()
    if t2[t]==v then self.next() return t2 end 
  end
  function self.pushBack() p=p-1 end
  function self.matchpt(v) return self.matchp('type',v) end
  function self.match(t,v,m)
    local r = self.matchp(t,v)
    if r then return r end
    if self.error then self.error(self,self.peek(),m or fmt('expected %s (got %s)',v,self.peek().type)) end
    error(m or fmt('expected %s (got %s)',v,self.peek()[t]),2) 
  end 
  function self.matcht(v,m) return self.match('type',v,m) end 
  function self.peek(n) return tab[p+(n or 1)] or self.eof end
  function self.containsOp(op) for _,t in ipairs(tab) do if t.opval == op then return true end end end
  function self.containsType(typ) for _,t in ipairs(tab) do if t.type == typ then return true end end end
  function self.dump(env) 
    local pr = env and env.print or print 
    for _,t in ipairs(tab) do pr(json.encode(t)) end 
  end
  return self
end

local GCTX
local function toTimeDate(str)
  local y,m,d,h,min,s=str:match("(%d?%d?%d?%d?)/?(%d+)/(%d+)/(%d%d):(%d%d):?(%d?%d?)")
  local stat,res = pcall(function()
    local t = os.date("*t")
    return os.time{year=y~="" and y or t.year,month=m,day=d,hour=h,min=min,sec=s~="" and s or 0}
  end)
  if stat then return res else perror('Tokenizer',"Bad long time format",GCTX.from,GCTX.to,GCTX.source) end
end
local function toTime(str)
  local h,m,s = str:match("(%d%d):(%d%d):?(%d*)")
  return 3600*h+60*m+(s and s~="" and s or 0)
end

local tokenMetatable = {
  __tostring = function (t) return fmt("%s:%s/%s/%s",t.type,t.value or t.opval,t.dbg.from,t.dbg.to) end
}

local function token(prefix, pattern, createFn)
  pattern = "^(" .. pattern .. ")"
  local function fn(ctx)
    local sta, len, res, group = string.find(ctx.source, pattern)
    if len then
      if createFn then
        ctx.to = ctx.cursor + len
        ctx.from = ctx.cursor + sta
        local tokenv,t2,len2 = createFn(group or res, ctx.source)
        if tokenv == '%break' then return end
        if tokenv == '%extend%' then
          tokenv = t2
          len = len2
        end
        tokenv.dbg = {from=ctx.cursor+1, to=ctx.cursor+len}
        table.insert(ctx.tokens, tokenv)
        setmetatable(tokenv, tokenMetatable)
      end
      ctx.source = string.sub(ctx.source, len+1)
      ctx.cursor = ctx.cursor + len
      return true
    end
  end
  for c in prefix:gmatch"." do
    patterns[c] = patterns[c] or {}
    table.insert(patterns[c], fn)
  end
end

local function trans(op) return opers0[op] and opers0[op].trans or op end

local function tknError(msg) error(msg) end
token(" \t\n\r","[%s%c]+")
--2019/3/30/20:30
token("/0123456789","%d?%d?%d?%d?/?%d+/%d+/%d%d:%d%d:?%d?%d?",function (t) return {type="num", const=true, value=toTimeDate(t)} end)
token("0123456789","%d%d:%d%d:?%d?%d?",function (t) 
  return {type='num', const=true, value=toTime(t)} 
end)
token("0123456789","%d+:%d+",function (w) 
  if #w>5 then tknError('Bad time constant '..w) else return "%break" end 
end)
token("t+n","[t+n][/]", function (op) return {type="op", opval=trans(op)} end)
token("#","#[A-Za-z_][%w_%-]*",function (w) return {type="event", value=w:sub(2)} end)
token("$","%$+[_0-9a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96]*",
function (w) return {type='t_name', value=w} end)
token("_abcdefghijklmnopqrstuvwxyzåäöABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖ\xC3\xA5\xA4\xB6\x85\x84\x96","[_a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96][_0-9a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96]*", 
function (w) return opers0[w] and {type='op', opval=trans(w)} or keyword[w] and {type=keyword[w], keyw=true} or {type='t_name', value=w} end)
token("0123456789","%d+%.%d+", function (d) return {type="num", const=true, value=tonumber(d)} end)
token("0123456789","%d+", function (d) return {type="num", const=true, value=tonumber(d)} end)
local cmap = {['n']='\n',['r']='\r',['t']='\t'}
local function getString(s,e)
  local i,n = 2,s:len()
  local r = {}
  while i <= n do
    local c = s:sub(i,i)
    if c == '\\' then
      i = i + 1
      c = s:sub(i,i)
      r[#r+1]=cmap[c] or c
    elseif c == e then
      return table.concat(r),i
    else r[#r+1]=c end
    i=i+1
  end
end
token('"','"', function (s,src)
  local str,i = getString(src,'"')
  if not str then tknError('unfinished string starting with "...') end
  return '%extend%', {type="str", const=true, value=str}, i
end)
token("'","'", function (s,src)
  local str,i = getString(src,"'")
  if not str then tknError("unfinished string starting with '...") end
  return '%extend%', {type="str", const=true, value=str}, i
end)
token("-","%-%-.-\n")
token("-","%-%-.*")
token("=","===",function (op) return {type="op", opval=trans(op)} end)    
token(".","%.%.%.",function (op) return {type="t_name", value='...'} end)
token(".","%.%.",function (op) return {type="op", opval=trans('..')} end)
token("$","%$%$%$?", function (op) return {type="op", opval=trans(op)} end)
token("@$=<>!+-*&|/^~:?","[@%$=<>!+%-*&|/%^~;:%?][%+@=<>&|:%.%?]?", 
function (w) return 
  keyword[w] and {type=keyword[w], keyw=true} or 
  opers0[w] and {type='op', opval=trans(w)} 
  or tknError("Bad token '"..w.."'")
end)
token("{}(),[]#%;.","[%.{}%(%),%[%]#%%;]", 
function (w) return 
  keyword[w] and {type=keyword[w], keyw=true} or 
  opers0[w] and {type='op', opval=trans(w)} 
  or tknError("Bad token '"..w.."'") 
end)

local function dispatch(c,ctx) 
  for _,m in ipairs(patterns[c] or {}) do
    if m(ctx) then return true end
  end
end

local function tokenize(src)
  local ctx = { source = src, tokens = {}, cursor = 0 }
  GCTX = ctx
  local stat,res = pcall(function()
    while #ctx.source>0 and dispatch(ctx.source:sub(1,1),ctx) do end
    if #ctx.source > 0 then 
      tknError(fmt("tokenizer failed at %s in %s",ctx.source,src))
    end
  end)
  if not stat then
    if type(res) == 'table' and res._err then 
      return error(res)
    else 
      perror('Tokenizer',res or "",ctx.from,ctx.to,src)
    end
  end
  return ctx.tokens
end

function ER.tokenize(str)
  return stream(tokenize(str),str)
end


----------------------------- Parser ------------------------------------------------------------
--[[
chunk ::= block
block ::= {stat} [retstat]
stat ::=  ‘;’ | 
varlist ‘=’ exprlist | 
functioncall | 
label |          -- NOT IMPLEMENTED
break | 
goto Name |      -- NOT IMPLEMENTED
do block end | 
while exp do block end | 
repeat block until exp | 
if exp then block {elseif exp then block} [else block] end | 
for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end | 
for namelist in exprlist do block end | 
function funcname funcbody | 
  local function Name funcbody | 
    local namelist [‘=’ exprlist] 
    -- start: ;, name, break, do, while, repeat, if, for, function, local
    
    retstat ::= return [exprlist] [‘;’]
    label ::= ‘::’ Name ‘::’
    funcname ::= Name {‘.’ Name} [‘:’ Name]
    varlist ::= var {‘,’ var}
    var ::=  Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
    namelist ::= Name {‘,’ Name}
    exprlist ::= exp {‘,’ exp}
    exp ::=  nil | false | true | Numeral | LiteralString | ‘...’ | functiondef | 
    prefixexp | tableconstructor | exp binop exp | unop exp 
    -- start: nil, false, true, num, string, ..., function, name,
    --        {, (, -, not, #, ~
    
    prefixexp ::= var | functioncall | ‘(’ exp ‘)’
    functioncall ::=  prefixexp args | prefixexp ‘:’ Name args 
    args ::=  ‘(’ [exprlist] ‘)’ | tableconstructor | LiteralString 
    functiondef ::= function funcbody
      funcbody ::= ‘(’ [parlist] ‘)’ block end
      parlist ::= namelist [‘,’ ‘...’] | ‘...’
      tableconstructor ::= ‘{’ [fieldlist] ‘}’ 
      fieldlist ::= field {fieldsep field} [fieldsep]
      field ::= ‘[’ exp ‘]’ ‘=’ exp | Name ‘=’ exp | exp
      fieldsep ::= ‘,’ | ‘;’
      binop ::=  ‘+’ | ‘-’ | ‘*’ | ‘/’ | ‘//’ | ‘^’ | ‘%’ | 
      ‘&’ | ‘~’ | ‘|’ | ‘>>’ | ‘<<’ | ‘..’ | 
      ‘<’ | ‘<=’ | ‘>’ | ‘>=’ | ‘==’ | ‘~=’ | 
      and | or
      unop ::= ‘-’ | not | ‘#’ | ‘~’
      
      -- My rewrite of the rules...
      afterpref ::= '.' prefixexp
      afterpref ::= '[' exp ']' afterpref
      afterpref ::= '(' args ')' afterpref
      afterpref ::= null
      
      prefixexp ::= Name
      prefixexp ::= Name . prefixexp
      prefixexp ::= Name [ exp ] [ afterpref ]
      prefixexp ::= Name ( args ) [ afterpref ]
      prefixexp ::= Name : Obj ( args ) [ afterpref ]
      prefixexp ::= ( exp ) [ afterpref ]
    end
  end
end
¨--]]

function ER.Stack()
  local p,px,st,self=0,0,{},{}
  function self.push(v) p=p+1 st[p]=v px=p end
  function self.pushx(v) px=px+1 st[px]=v end
  function self.getx(i) if px>p then return st[p+i] end end
  function self.pop(n) n = n or 1; p=p-n; px=p local r= st[p+n] st[p+n]=nil return r end
  function self.pushMultiRes(res)
    if #res == 0 then self.push(nil) return end
    self.push(res[1])
    for i=2,#res do self.pushx(res[i]) end 
  end
  function self.popm(n)
    local pxx = px
    p = p-n; px = p
    return table.unpack(st,p+1,pxx)
  end
  function self.popmpack(n)
    p = p-n
    local res = {table.unpack(st,p+1,px)}
    px = p
    return res
  end
  function self.peek(n) return st[p-(n or 0)] end
  function self.size() return p end
  function self.isEmpty() return p <= 0 end
  function self.dump(env) 
    local pr = env and env.print or print 
    for i=1,p do pr(string.format("S%02d: %s",i,json.encode(st[i]))) end 
  end
  function self.clear() p,px,st=0,0,{} end
  return self
end

local chunk,block,stat,retstat,label,funcname,varlist,var,namelist,exprlist,expr
local prefixexpr,functioncall,args,functiondef,funcbody,parlist,tablevalue
local function mapT(args) local r={} for _,v in ipairs(args) do r[v]=true end return r end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local function merge(t1,t2) local t0 = copy(t1) for k,v in pairs(t2) do t0[k] = v end return t0 end
local Stack,Opers
local fmt = string.format

local _perror,_source
local function perror(msg,tkn)
  _perror('Parser',msg,tkn.dbg.from,tkn.dbg.to,_source)
end

local function matchError(tkns,t,msg)
  perror(msg,t)
end

local function mergeDbg(...)
  local dbg = {...}
  return {from=(dbg[1]._dbg or dbg[1].dbg).from,to=(dbg[#dbg]._dbg or dbg[#dbg].dbg).to}
end

local function Scope()
  local self,frame = {},{}
  function self.push() local f = {_next=frame} frame = f end
  function self.pop() frame=frame._next end
  function self.setBreak() frame.breaks = true end
  function self.addLocal(name) frame.locals = frame.locals or {} frame.locals[name] = true end
  function self.hasBreaks() return frame.breaks end
  function self.hasLocals(name) return frame.locals end
  return self
end

local scope = Scope()
local inExpr = false 

local blockEnd = mapT{'t_return','t_eof','t_ruleend'}
function block(tkns,ends) -- OK
  scope.push()
  local stats,ends = {},ends or blockEnd
  local t = tkns.peek()
  local fp = t
  while not (ends[t.type] or t.type=='t_return') do
    local saveP = tkns.getP()
    local stat,err = pcall(function()
      local s = stat(tkns,ends)
      if s then stats[#stats+1] = s end
      t = tkns.peek()
    end)
    if not stat then -- We got an error
      tkns.setP(saveP)
      local ep = tkns.peek()
      local stat2,err2 = pcall(expr,tkns,ends) -- Try to parse expression
      if stat2 then perror("Expected statement but got expression",ep) -- If so, give better error
      else error(err) end -- No an expression either, just error
    end
  end
  local ep = tkns.peek()
  if ep.type == 't_return' then
    local r = retstat(tkns,ends)
    if r then stats[#stats+1] = r end
    ep = tkns.peek()
  end
  local bs = scope.hasBreaks() or scope.hasLocals()
  local locals = scope.hasLocals()
  scope.pop()
  return {type='block', statements=stats, scope = bs, locals = locals, dbg=mergeDbg(fp,ep)}
end

local varTypes={[""]='ev',["$"]='gv',["$$"]='qv',["$$$"]='sv'}
local function varType(name) return varTypes[name:match("^[%$]*")] end

local doEnd = mapT{'t_end','t_eof','t_ruleend'}
local whileEnd = mapT{'t_do','t_eof','t_ruleend'}
local untilEnd = mapT{'t_until','t_eof','t_ruleend'}
local exprEnd = mapT{'t_semi','t_comma','t_eof','t_if','t_do','t_while','t_repeat','t_return','t_break','t_ruleend'}
local thenEnd = mapT{'t_end','t_else','t_elseif','t_eof','t_ruleend'}
local endEnd = mapT{'t_end','t_eof','t_ruleend'}
local braEnd = merge(mapT{'t_rbra','t_eof','t_ruleend'},exprEnd)
local incsMap = mapT{'t_addinc','t_subinc','t_mulinc','t_divinc'}
local caseExpr = mapT{'t_>>'}
local caseEnd = mapT{'t_end','t_||','t_eof','t_ruleend'}

function stat(tkns,ends)
  ends = ends or {}
  local pt = tkns.peek().type
  if tkns.matchpt('t_semi') or ends[pt] then return end
  local stp = tkns.peek()
  
  if tkns.peek().type == 't_name' then 
    local stp = tkns.peek()
    local n = tkns.matcht('t_name')
    local v = prefixexpr(tkns,{type='name',value=n.value,_dbg=n.dbg,vt=varType(n.value)})
    if v.type=='call' or v.type == 'objcall' then 
      return v   -- OK. functioncall
    elseif incsMap[tkns.peek().type]  then -- OK. var += exp
      --local v = tkns.matcht('t_name',"Expected variable name").value
      local op = tkns.next()
      local val = expr(tkns,exprEnd)
      return {type='incvar',name=v.value,op=op.type:sub(3,-4),value=val,_dbg=op.dbg}
    elseif v.type=='getprop' and not (tkns.peek().opval=='assign' or tkns.matchpt('t_comma')) then
      return v
    else -- OK. varlist ‘=’ exprlist
      local vl = varlist(tkns,v)
      --local t = tkns.match('opval','assign',"Expected '=' in assignment")
      local t = tkns.peek()
      if not tkns.matchp('opval','assign') then 
        perror("Expected '=' in assignment",stp) 
      end
      local e = exprlist(tkns)
      return {type='assign',vars=vl,exprs=e,_dbg=t.dbg}
    end
  end
  --label |          -- NOT IMPLEMENTED
  if tkns.matchpt('t_break') then -- OK.
    scope.setBreak()
    return {type='break',_dbg=pt.dbg}
  end
  -- go to Name |      -- NOT IMPLEMENTED
  if tkns.matchpt('t_do') then  -- OK. _do_block_end
    local bl = block(tkns,doEnd)
    tkns.matcht('t_end',"Expected END for DO block")
    return bl
  end
  if tkns.matchpt('t_while') then -- OK. _while_exp_do_block_end
    local e = expr(tkns,whileEnd)
    tkns.matcht('t_do',"Expected DO in WHILE loop")
    local b = block(tkns,doEnd)
    tkns.matcht('t_end',"Expected END in WHILE loop")
    return {type='while',cond=e,body=b,_dbg=pt.dbg}
  end 
  if tkns.matchpt('t_repeat') then -- OK. _repeat_block_until_exp_
    local b = block(tkns,untilEnd)
    tkns.matcht('t_until',"Expected UNTIL in REPEAT block")
    local e = expr(tkns,exprEnd)
    return {type='rep'..'eat',body=b,cond=e,_dbg=pt.dbg}
  end
  
  if tkns.matchpt('t_if') then -- OK. _if_exp_then_block_{elseif_exp_then_block} [else_block]_end 
    local e = expr(tkns)
    tkns.matcht('t_then',"Expected THEN in IF statement")
    local b = block(tkns,thenEnd)
    local ifs = {{cond=e,body=b}}
    while tkns.matchpt('t_elseif') do
      local e = expr(tkns,thenEnd)
      tkns.matcht('t_then',"Expected THEN in ELSEIF statement")
      local b = block(tkns,thenEnd)
      ifs[#ifs+1] = {cond=e,body=b}
    end
    if tkns.matchpt('t_else') then
      local b = block(tkns,endEnd)
      ifs[#ifs+1] = {body=b}
    end
    tkns.matcht('t_end',"Expected END in IF statement")
    return {type='if', args=ifs,_dbg=pt.dbg}
  end
  
  -- OK. case ... end
  if tkns.matchpt('t_case') then 
    local args = {}
    while tkns.matchpt('t_||') do
      local e = expr(tkns,caseExpr)
      tkns.matcht('t_>>',"Expected >> after expression in CASE statement")
      local b = block(tkns,caseEnd)
      args[#args+1] = {cond=e,body=b}
    end
    tkns.matcht('t_end',"Expected END in CASE statement")
    return {type='if', args=args,_dbg=pt.dbg}
  end
  
  if tkns.matchpt('t_for') then
    -- OK. for Name ‘=’ exp ‘,’ exp [‘,’ exp] do block end
    if tkns.peek(2).opval == 'assign' then 
      local name = tkns.matcht('t_name',"Expected loop variable name")
      local var = {type='name',value=name.value,_dbg=name.dbg,vt=varType(name.value)}
      tkns.match('opval','assign',"Expected '=' in FOR loop")
      local start = expr(tkns)
      tkns.matcht('t_comma',"Expected ',' in FOR loop")
      local stop = expr(tkns,{'t_comma','t_do','t_eof'})
      local step
      if tkns.matchpt('t_comma') then
        step = expr(tkns,{'t_comma','t_do','t_eof'})
      else 
        step = {type='num',value=1,const=true,_dbg=tkns.peek().dbg} 
      end
      tkns.matcht('t_do',"Expected DO in FOR loop")
      local body = block(tkns,endEnd)
      tkns.matcht('t_end',"Expected END in FOR loop")
      body.scope = nil -- we always have outer scope for loop var...
      local d = {type='block',scope=true,statements={
        {type='assign',vars={var},exprs={start},_dbg=name.dbg},
        {type='loop',statements={
          {type='breakif',
          cond={type='binop',op='gt',exp1=var,exp2=stop,_dbg=name.dbg},
          _dbg=body._dbg
        },
        body,
        {type='incvar',name=name.value,op='add',value=step,_dbg=step._dbg}
      }}}}
      return d
    else -- for namelist in exprlist do block_end
      local n = namelist(tkns)
      if #n < 1 or #n > 2 then perror("Expected 1 or 2 variables in FOR in loop",tkns.peek()) end
      if #n == 1 then n[2] = '_' end
      tkns.matcht('t_in',"Expected 'in' in FOR loop")
      local e = exprlist(tkns)
      tkns.matcht('t_do',"Expected DO in FOR loop")
      local b = block(tkns,endEnd)
      tkns.matcht('t_end',"Expected END in FOR loop")
      return {type='forin',names=n,exp=e,body=b,_dbg=pt.dbg} 
    end
  end
  
  if tkns.matchpt('t_function') then -- OK. function funcname funcbody
    local n = funcname(tkns)
    local b = funcbody(tkns)
    return {type='functiondef',name=n,fun={type='func'..'tion',params=b.params,body=b.block,_dbg=pt.dbg}}
  end
  if tkns.matchpt('t_local') then
    if tkns.matchpt('t_function') then -- local function Name funcbody
      local n = tkns.matcht('t_name',"Expected FUNCTION name")
      scope.addLocal(n.value)
      local b = funcbody(tkns)
      return {type='localfunction',name=n,body=b,_dbg=pt.dbg}
    else -- OK. local namelist [‘=’ exprlist]
      local n = namelist(tkns)
      for _,name in ipairs(n) do scope.addLocal(name) end
      local e
      if tkns.matchp('opval','assign') then
        e = exprlist(tkns)
      end
      return {type='local',names=n,exprs=e,_dbg=pt.dbg}
    end
  end
  if tkns.matchpt('t_lcur') then -- OK. tableconstructor
    local tab = tablevalue(tkns)
    tkns.matcht('t_ddot',": expected for table property call")
    local n = tkns.matcht('t_name',"Expected property name after ':'").value
    local pt = tkns.peek()
    if tkns.peek().opval == 'assign' then
      tkns.next()
      local val = expr(tkns,exprEnd)
      return {type='assign',vars={{type='getprop',prop=n,obj=tab,_dbg=pt.dbg}},exprs={val},_dbg=pt.dbg}
    end
    return {type='getprop',prop=n,obj=tab,_dbg=pt.dbg}
  end
  if tkns.peek().type=='num' then
    local pt = tkns.peek()
    local num = tkns.matcht('num')
    if tkns.peek().type ~= 't_ddot' then 
      perror("Expected ':' for number property call",pt) 
    end
    local v = prefixexpr(tkns,{type='num',value=num.value,_dbg=num.dbg,const=true})
    if v.type=='call' or v.type == 'objcall' then 
      perror("Expected ':' for number property call",pt)
    elseif v.type=='getprop' and not (tkns.peek().opval=='assign' or tkns.matchpt('t_comma')) then
      return v
    else -- OK. varlist ‘=’ exprlist
      local vl = varlist(tkns,v)
      --local t = tkns.match('opval','assign',"Expected '=' in assignment")
      local t = tkns.peek()
      if not tkns.matchp('opval','assign') then 
        perror("Expected '=' in assignment",stp) 
      end
      local e = exprlist(tkns)
      return {type='assign',vars=vl,exprs=e,_dbg=t.dbg}
    end
  end
  local tp = tkns.peek()
  perror(fmt("unexpected token '%s'",tp.opval or tp.value or tp.type),tkns.peek())
end

function namelist(tkns)
  local names = {tkns.matcht('t_name',"Expected variable name").value}
  while tkns.matchpt('t_comma') do
    names[#names+1] = tkns.matcht('t_name',"Expected variable name").value
  end
  return names
end

function funcname(tkns)
  local n = {tkns.matcht('t_name',"Expected FUNCTION name").value}
  while tkns.matchpt('t_dot') do
    n[#n+1] = tkns.matcht('t_name',"Expected FUNCTION name").value
  end
  if tkns.matchpt('t_ddot') then
    n[#n+1] = tkns.matcht('t_name').value
  end
  return n
end

function funcbody(tkns)
  tkns.matcht('t_lpar',"Expected '(' in FUNCTION definition")
  local p = parlist(tkns)
  tkns.matcht('t_rpar',"Expected ')' in FUNCTION definition")
  local b = block(tkns,endEnd)
  tkns.matcht('t_end',"Expected 'end' in FUNCTION definition")
  return {params=p,block=b}
end

local function args(tkns)
  tkns.matcht('t_lpar',"Expected '(' in FUNCTION call")
  local exprs = exprlist(tkns)
  tkns.matcht('t_rpar',"Expected ')' in FUNCTION call")
  return exprs
end

function prefixexpr(tkns,r)
  local t = tkns.peek()
  if t.type == 't_dot' then
    tkns.next()
    local n = tkns.matcht('t_name',"Expected name after '.'")
    return prefixexpr(tkns,{type='aref',tab=r,idx=n.value,_dbg=t.dbg})
  elseif t.type == 't_lbra' then
    tkns.next()
    local e = expr(tkns,braEnd)
    if e.const then e = e.value end
    tkns.matcht('t_rbra',"Expected ']' to end table access")
    return prefixexpr(tkns,{type='aref',tab=r,idx=e,_dbg=t.dbg})
  elseif t.type == 't_lcur' then -- ToDo
    error("Not implemented yet")
  elseif t.type == 't_lpar' then
    local isExpr = inExpr
    local args = args(tkns)
    return prefixexpr(tkns,{type='call',fun=r,args=args,expr=isExpr,_dbg=t.dbg}) 
  elseif t.type == 't_ddot' then
    tkns.next()
    local n = tkns.matcht('t_name',"Expected name after ':'").value
    local pt = tkns.peek()
    if tkns.peek().type == 't_lpar' then -- method call
      local isExpr = inExpr
      local args = args(tkns)
      return prefixexpr(tkns,{type='objcall',obj=r,fun=n,args=args,expr=isExpr,_dbg=t.dbg})
    else
      if tkns.peek().type == 't_dot' or tkns.peek().type =='t_ddot' then
        return prefixexpr(tkns,{type='getprop',obj=r,prop=n,_dbg=t.dbg}) -- property access
      end 
      return {type='getprop',obj=r,prop=n,expr=inExpr,_dbg=t.dbg} -- property access
    end
  else return r end
end

function parlist(tkns)
  local n = namelist(tkns)
  if tkns.matchpt('...') then
    n[#n+1] = '...'
  end
  return n
end

function varlist(tkns,var)
  local v = {var}
  while tkns.matchpt('t_comma') do
    local p = tkns.peek()
    local n = tkns.matcht('t_name',"Expected variable name")
    v[#v+1] = prefixexpr(tkns,{type='name',value=n.value,_dbg=p.dbg,vt=varType(n.value)})
    local e = v[#v]
    if not(e.type == 'name' or e.type == 'aref' or e.type == 'getprop') then 
      perror(fmt("expected variable or table assignment"),p)
    end
  end
  return v
end

function exprlist(tkns)
  local e = {expr(tkns,exprEnd)}
  while tkns.matchpt('t_comma') do
    e[#e+1] = expr(tkns,exprEnd)
  end
  return e
end

local curlEnd = merge(mapT{'t_rbra','t_rcurl,t_comma'},exprEnd)
function tablevalue(tkns)
  local tab,idx,n = {},1,0
  local t0 = tkns.peek()
  while tkns.peek().type ~= 't_rcur' do
    local t = tkns.peek()
    if t.type == 't_lbra' then --[expr] = ...
      tkns.next()
      local k = expr(tkns,curlEnd)
      tkns.matcht('t_rbra',"Expected ']' in table constructor")
      tkns.match('opval','assign',"Expected '=' in table constructor")
      local v = expr(tkns,curlEnd)
      if k.const then k = k.value 
        tab[#tab+1] = {key=k.value,value=v}; n = n + (v.const and 1 or 0)
      else tab[#tab+1] = {expr=k,value=v} end
    elseif t.type == 't_name' and tkns.peek(2).opval == 'assign' then  -- name = expr
      local name = t.value
      tkns.next()
      tkns.match('opval','assign',"Expected '=' in table constructor")
      local v = expr(tkns,curlEnd)
      tab[#tab+1] = {key=name,value=v}; n = n + (v.const and 1 or 0)
    else
      local v = expr(tkns,curlEnd)
      tab[#tab+1] = {key=idx,value=v}; idx=idx+1; n = n + (v.const and 1 or 0)
    end
    if not tkns.matchpt('t_comma') then break end
  end 
  tkns.matcht('t_rcur')
  if next(tab)==nil or n == #tab then
    local res = {}
    for i,k in ipairs(tab) do res[k.key] = k.value.value end
    return {type='table',value=res,const=true,_dbg=t0.dbg}
  elseif #tab == 1 and tab[1].value and tab[1].value.value == '...' then
    return {type='varargstable',_dbg=t0.dbg}
  else return {type='table',value=tab,_dbg=t0.dbg} end
end

local function isConst(t) return t.const and t.type or t.type=='t_name' and 'name' end
local function isNum(t) return t.type=='num' end

local foldConst = {}
local ops = {
  ['add']=function(a,b) return a+b end,
  ['sub']=function(a,b) return a-b end,
  ['mul']=function(a,b) return a*b end,
  ['div']=function(a,b) return a/b end,
}
local foldConsts = mapT{'add','sub','mul','div'}

local function foldConst(op,a,b)
  if isNum(a) then
    if isNum(b) then
      return {type='num',value=ops[op](a.value,b.value),const=true,_dbg=mergeDbg(a,b)}
    end
    return {type='unop',op=op,a=a.value,exp=b,_dbg=b._dbg}
  elseif isNum(b) then
    --if op == 'div' then op,b.value = 'mul',1/b.value end
    --if op == 'sub' then op,b.value = 'sub',-b.value end
    return {type='unop',op=op,b=b.value,exp=a,_dbg=a._dbg}
  end
  return {type='binop',op=op,exp1=a,exp2=b,_dbg=mergeDbg(a,b)}
end

local simpBinops = mapT{'and','or'}
local function simpBinop(op,a,b)
  if b.type == 'binop' and b.op == op then
    return {type='seqop',op=op,exprs={a,b.expr1,b.expr2},_dbg=mergeDbg(b.expr1,b.expr2)}
  elseif b.type == 'seqop' and b.op == op then
    table.insert(b.exprs,1,a)
    return {type='seqop',op=op,exprs=b.exprs,_dbg=b._dbg}
  end
  return {type='seqop',op=op,exprs={a,b},_dbg=mergeDbg(a,b)}
end

local function isOperator(t) return t.opval end
local function prio(op) return Opers[op].prio end
local function applyOp(op,vals)
  if Opers[op].unop then
    local a = vals.pop()
    if op == 'neg' and isNum(a) then 
      return {type='num',value=-a.value,const=true,_dbg=a._dbg} 
    else return {type='unop',op=op,exp=a,_dbg=a._dbg} end
  else
    local b,a = vals.pop(),vals.pop()
    if foldConsts[op] then return foldConst(op,a,b)
    elseif simpBinops[op] then return simpBinop(op,a,b)
    else return {type='binop',op=op,exp1=a,exp2=b,_dbg=mergeDbg(a,b)} end
  end
end

local function CMT(t)
  return setmetatable(t,{__tostring=function(t) return fmt("%s:%s",t.type,t.value) end})
end
local specOp = {}
local parEnd = mapT{'t_rpar','t_eof'}
local braEnd = mapT{'t_rbra','t_eof'}
function specOp.t_lpar(t,vals,ops,tkns)
  local e = expr(tkns,parEnd)
  tkns.matcht('t_rpar',"Expcted ) to close (...")
  e = prefixexpr(tkns,e)
  vals.push(e)
end
function specOp.t_lbra(t,vals,ops,tkns)
  local e = expr(tkns,braEnd)
  tkns.matcht('t_rbra',"Expected ]")
  ops.push(e) -- table index
  vals.push(e)
end
function specOp.t_lcur(t,vals,ops,tkns)
  local isExpr = inExpr
  local tab = tablevalue(tkns)
  if tkns.matchpt('t_ddot') then
    local nt = tkns.peek()
    local n = tkns.matcht('t_name',"Expected property name after :").value
    if tkns.peek().type=='t_ddot' then
      vals.push(prefixexpr(tkns,{type='getprop',obj=tab,prop=n,_dbg=t.dbg})) -- property access
    else
      vals.push({type='getprop',obj=tab,prop=n,expr=isExpr,_dbg=nt.dbg})
    end
  else
    vals.push(tab)
  end
end
function specOp.t_nil(t,vals,ops,tkns) vals.push(CMT{type='const',value=nil,const=true,_dbg=t.dbg}) end
function specOp.t_true(t,vals,ops,tkns) vals.push(CMT{type='const',value=true,const=true,_dbg=t.dbg}) end
function specOp.t_false(t,vals,ops,tkns) vals.push(CMT{type='const',value=false,const=true,_dbg=t.dbg}) end
function specOp.num(t,vals,ops,tkns)
  if tkns.matchpt('t_ddot') then
    local n = tkns.matcht('t_name',"Expected property name after :").value
    vals.push({type='getprop',obj=t,prop=n,expr=inExpr,_dbg=t.dbg})
  else
    vals.push(CMT{type='num',value=t.value,const=true,_dbg=t.dbg})
  end
end
function specOp.event(t,vals,ops,tkns)
  local tab
  if tkns.peek().type == 't_lcur' then
    tkns.next()
    local val = tablevalue(tkns)
    if val.const then
      val.value.type=t.value
    elseif val.type == 'table' then
      table.insert(val.value,1,{key='type',value={type='const',value=t.value}})
    else perror("Expected table constructor or ... after event{",tkns.peek()) end
    tab = val
  else tab = {type='table',value={type=t.value},const=true,_dbg=t.dbg} end
  vals.push(tab)
end
function specOp.str(t,vals,ops,tkns) vals.push(CMT{type='str',value=t.value,const=true,_dbg=t.dbg}) end
function specOp.t_name(t,vals,ops,tkns)
  local v = prefixexpr(tkns,CMT{type='name',value=t.value,_dbg=t.dbg,vt=varType(t.value)})
  vals.push(v) 
end
function specOp.t_function(t,vals,ops,tkns)
  local isExpr = inExpr
  local f = funcbody(tkns)
  local fun = {type='functionexpr',fun={type='func'..'tion',expr=isExpr,params=f.params,body=f.block},_dbg=t.dbg}
  local v = prefixexpr(tkns,fun)
  vals.push(v)
end

local unminBeg = mapT{
  't_rpar','t_rbra','t_name','num','t_str','t_nil','t_true','t_false'
}
local exprEnd = mapT(merge(blockEnd,{}))
function expr(tkns,ends)
  local oldExpr = inExpr
  inExpr = true
  local ops,vals = Stack(),Stack()
  while true do
    local t = tkns.peek()
    if (ends or exprEnd)[t.type] then break end
    if specOp[t.type] then
      tkns.next()
      specOp[t.type](t,vals,ops,tkns)
    elseif isOperator(t) then
      if t.opval == 'sub' then
        local last = tkns.last()
        if not last or not unminBeg[last.type] then t.opval = 'neg' end
      end
      tkns.next()
      local tprio = prio(t.opval)
      while not ops.isEmpty() and prio(ops.peek().opval) > tprio do
        vals.push(applyOp(ops.pop().opval,vals))
      end
      ops.push(t)
    else
      break -- end of expr?
    end
  end
  while not ops.isEmpty() do
    vals.push(applyOp(ops.pop().opval,vals))
  end
  inExpr=oldExpr
  return vals.pop()
end

function retstat(tkns,ends)
  local t = tkns.matcht('t_return')
  local e
  if not ends[tkns.peek().type] then
    e = exprlist(tkns)
  end
  if tkns.matchpt('t_semi') then --[[ ignore --]] end
  return {type='return',exp=e,_dbg=t.dbg}
end

local ruleEnd = mapT{'t_ruleend','t_eof'}
function ER.parse(tkns)
  Stack,Opers = ER.Stack,ER._opers1
  scope,inExpr = Scope(),false
  _perror,_source = ER.perror,tkns.src
  tkns.error = matchError
  local res
  if tkns.matchpt('t_rulebegin') then
    local head = expr(tkns,ruleEnd)
    tkns.matcht('t_rule',"Expected rule")
    local body = block(tkns,ruleEnd)
    tkns.matcht('t_ruleend',"Expected rule end")
    res = {type='ruledef',head=head,body=body,_dbg=head._dbg}             
  else res = block(tkns,blockEnd) end
  local rest = tkns.peek()
  if rest.type ~= 't_eof' then
    perror("Expected end of file but got "..rest.type,tkns.peek())
  end
  res._src = tkns.src
  return res
end