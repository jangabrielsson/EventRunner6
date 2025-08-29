--%%name:ER6
--%%offline:true
--%%headers:include.txt
--%%time:2025/08/28 10:00:00

function QuickApp:main(er)
  
  function log(...) print(...) return ... end
  
  local function printf(fmt,...) print(string.format(fmt,...)) end
  local YES = "✅"
  local NO = "❌"
  
  local function testExpr(str,expected, opts)
    local function cont(...)
      local results = {...}
      if #results ~= #expected then
        printf("%s %s = %s", NO, str // 80, json.encodeFast(results):sub(2,-2))
        return  
      end
      for i=1,#expected do
        if not table.equal(results[i], expected[i]) then
          printf("%s %s = %s", NO, str // 80, json.encodeFast(results):sub(2,-2))
          return
        end
      end
      printf("%s %s = %s", YES, str // 80, json.encodeFast(results):sub(2,-2))
    end
    local copts = table.copyShallow(opts or {})
    copts.cont = cont
    er.eval(str,copts)
  end
  
  local function testExprs(tests, mopts) 
    local mopts = mopts or {}
    for i=1,#tests,3 do
      local str = tests[i]
      local expected = tests[i+1]
      local lopts = tests[i+2] or {}
      local opts = {}
      for k,v in pairs(lopts) do opts[k] = v end
      for k,v in pairs(mopts) do opts[k] = v end
      if opts.newEnv then opts.env = {} end
      testExpr(str, expected, opts)
    end
  end
  
  local function testRule(str, check, opts)
    expected = expected or {}
    local rule = er.eval(str,opts)
    if opts.dumpTriggers then rule:dumpTriggers() end
    local function succ(res)
      if res then 
        printf("%s %s", YES, str:gsub("\n%s*"," ") // 80)
      else
        printf("%s %s", NO, str:gsub("\n%s*"," ") // 80)
      end
    end
    check(rule,succ)
  end
  
  local function testRules(rules, mopts) 
    local mopts = mopts or {}
    for i=1,#rules,3 do
      local str = rules[i]
      local check = rules[i+1]
      local lopts = rules[i+2] or {}
      local opts = {}
      for k,v in pairs(lopts) do opts[k] = v end
      for k,v in pairs(mopts) do opts[k] = v end
      if opts.newEnv then opts.env = {} end
      testRule(str, check, opts)
    end
  end
  
  T1 = {a={b=42}}
  T2 = {2,3,4,5}
  C2,C3,C4,C5,C6,C7 = 2,3,4,5,6,7
  function MV3() return 5,6,7 end
  
  PropObject = PropObject or {}
  MyObject = {}
  class 'MyObject'(PropObject)
  function MyObject:__init() PropObject.__init(self) self.props = {} end
  function MyObject:getProp(prop) return self.props[prop] end
  function MyObject:setProp(prop,value) self.props[prop]=value; return value end
  
  O1 = MyObject()
  Obj3 = {}
  function Obj3:foo(n) return n end
  
  local stdTests = {
    -- "return nil==nil",{true},nil,
    -- "return nil~=nil",{false},nil,
    -- "return false==false",{true},nil,
    -- "return true==true",{true},nil,
    -- "return 42==42",{true},nil,
    -- "return '42'=='42'",{true},nil,
    -- "return -77",{-77},{},
    -- "return 0- -77",{77},{},
    -- "return false | true",{true},nil,
    -- "return false & true",{false},nil,
    -- "return !(7 == 7)",{false},nil,
    -- "return 6 > 5",{true},{},
    -- "return 5 > 6",{false},{},
    -- "return 6 >= 5",{true},{},
    -- "return 5 <= 6",{true},{},
    -- "return T2[1]",{2},{},
    -- "return T2[5]",{nil},{},
    -- "a=2;return a+-1",{1},{},
    -- "a=2;return -a+3",{1},{},
    -- "a=2;return a-1",{1},{},
    -- "a=2;return 1-a",{-1},{},
    -- "a=2;return 4/a",{2},{},
    -- "a=4;return a/2",{2},{},
    -- "a=4;return a*2",{8},{},
    -- "a=4;return 2*a",{8},{},
    -- "a=2;return a+1+1",{4},nil,
    -- "a=2;return (a+1)+1",{4},nil,
    -- "a=2;return (a+1)+1,9",{4,9},{newEnv=true},
    -- "a=8;return (a+1)*6",{54},nil,
    -- "a=8;return a % 3",{2},nil,
    -- "a=2;return a ^ 3",{8},nil,
    -- "return 7,8",{7,8},nil,
    -- "return MV3()",{5,6,7},nil,
    -- "return 5+6*2",{17},nil,
    -- "a=99; return a",{99},nil,  -- Surving toplevel environment
    -- "return a",{99},nil,
    -- "function foo(a,b) return a+b,6 end; return foo(8,9)",{17,6},nil,
    -- "return T1.a.b",{42},nil,
    -- "return T1['a'].b",{42},nil,
    -- "b = {}; return b",{{}},{},
    -- "a=1; b = {[a+1]=9}; return b",{{[2]=9}},{},
    -- "a=1; return {[a+1]=9}",{{[2]=9}},{},
    -- "return {a=9,b=8}",{{a=9,b=8}},{},
    -- "return 4+6",{10},{},
    -- "if true then return 42 end",{42},{},
    -- "if false then return 17 else return 42 end",{42},{},
    -- "if false then return 17 elseif true then return 42 end",{42},{},
    -- "b=1; while b<=3 do b=b+1; end; return b",{4},{newEnv=true},
    -- "b=1; while b<=3 do b=b+1; break end; return b",{2},{newEnv=true},
    -- "b=0; repeat b=b+1 until b>3; return b",{4},{newEnv=true},
    -- "b=0 do b=1; break; b=2 end; return b",{1},{tree=false,newEnv=true},
    -- "c=0; for a=1,3 do c+=1 end; return c",{3},{newEnv=true},
    -- "a=1; a+=4; return a",{5},{},
    -- "a=1; a-=4; return a",{-3},{},
    -- "T1.a.b = 5; return T1.a.b",{5},{},
    -- "a=1;return a",{1},{},
    -- "a,b=C2+1,C2+2;return a+b",{7},{},
    -- "T1.a.b=88;return T1",{{a={b=88}}},{},
    -- "T1.a.b=C2;return T1",{{a={b=2}}},{},
    -- "a,T1.a.b=C2+1,C2;return T1.a.b+a",{5},{},
    -- "a,b,c=C5,C6,C7;return a+b+c",{18},{},
    -- "a,b,c=MV3();return a+b+c",{18},{},
    -- "a,b,c=C5,MV3();return a+b+c",{16},{},
    -- "local a,b,c = 2,3,4; return a+b+c",{9},{},
    -- "local a,b,c = 5,MV3(); return a+b+c",{16},{},
    -- "function bar(a,b) return a+b end; return 5",{5},{},
    -- "return bar(2,3)",{5},{},
    -- "return (function(a,b) return a*b end)(2,3)",{6},{},
    -- "return (function(...) a = {...} return a end)(2,3)",{{2,3}},{},
    -- "return (function(a,...) b = ({...})[1] return a+b end)(2,3)",{5},{},
    -- "do local a=7; return a+3 end",{10},{},
    -- "do local a=8; return a+3 end",{11},{},
    -- "do local a=7; wait(2); return a+3 end",{10},{},
    -- "do local a=8; wait(2); return a+3 end",{11},{},
    -- "function gg(x) if x==0 then return 1 else  return x*gg(x-1) end end return 55",{55},{},
    -- "return gg(5)",{120},{},
    -- "return {399,399}:value",{{true,true}},nil,
    -- "O1:bar=42; return O1:bar",{42},{},
    -- "$Bar={d=8}; return $Bar.d",{8},{},
    -- "$$Bar=42; return $$Bar",{42},{},
    -- "$$$Bar=42; return $$$Bar",{42},{},
    -- "return Foo()",{5},{},
    -- "return #foo",{{type='foo'}},{},
    -- "return 1 & true & 3",{3},{},
    -- "return 1 & 2 & false",{false},{},
    -- "return A1(5,6)",{11},{},
    -- "return wday('wed-thu')",{true},nil,
    -- "return wday('fri')",{false},nil,
    -- "return day('28')",{true},nil,
    -- "return day('lastw-last')",{true},nil, -- lastw is last day-6 in month, last is last day
    -- "return month('jul-sep')",{true},nil,
    -- "return date('* 10-12 * 8 *')",{true},nil, --min,hour,days,month,wday
    -- "local a=9; case || false >> a=18 || true >> a=19 end; return a",{19},nil,
    -- "log(a); return true",{true},nil,
    "return Obj3:foo(8)",{8},nil,
    
    -- "do local a = 0; for k,v in pairs(T2) do a += v end; return a end",{14},nil,
    -- "local a = 0; for k,v in ipairs(T2) do a += k end; return a",{10},nil
  }
  
  local function checkTriggers(rule,triggers)
    local rt = rule.triggers
    for i=1,#rt do
      if not table.equal(rt[i], triggers[i]) then return false end
    end
    return true
  end
  
  local RuleTrigs1 = {
    {type="device",id=66,property="value"},
    {type="device",id=67,property="state"},
    {type="device",id=68,property="batteryLevel"},
    {type="device",id=69,property="power"},
    {type="device",id=70,property="dead"},
    {type="device",id=71,property="value"},
    {type="device",id=72,property="value"},
    {type="device",id=73,property="value"},
    {type="device",id=74,property="value"},
    {type="device",id=75,property="value"},
    {type="alarm",id=76,property="armed"},
    {type="alarm",id=77,property="armed"},
    {type="device",id=78,property="sceneActivationEvent"},
    {type="device",id=79,property="accessControlEvent"},
    {type="device",id=80,property="centralSceneEvent"},
    {type="device",id=81,property="value"},
    {type="device",id=82,property="value"},
    {type="device",id=83,property="value"},
    {type="device",id=84,property="value"},
    {type="device",id=85,property="value"},
    {type="device",id=86,property="volume"},
    {type="device",id=87,property="position"},
    {type="device",id=88,property="value"},
  }
  
  local stdRules = {
    -- [[66:value &
    -- 67:state &
    -- 68:bat &
    -- 69:power &
    -- 70:isDead &
    -- 71:isOn &
    -- 72:isOff &
    -- 73:isAllOn &
    -- 74:isAnyOff &
    -- 75:last &
    -- 76:armed &
    -- 77:isArmed &
    -- 78:scene &
    -- 79:access &
    -- 80:central &
    -- 81:safe &
    -- 82:breached &
    -- 83:isOpen &
    -- 84:isClosed &
    -- 85:lux &
    -- 86:volume &
    -- 87:position &
    -- 88:temp 
    -- => log('Morning')]],function(r,succ) succ(checkTriggers(r,RuleTrigs1)) end,{dumpTriggers=true},
    --"@{07:00,catch} => return 'ok'",function(r,succ) succ(checkTriggers(r,  {{type='Daily', id=1}})) end,{dumpTriggers=true},
    "@@-01:00 => return 42",function(r,succ) succ(checkTriggers(r,  {{type='Interval', id=1}})) end,{dumpTriggers=true},
    --"200:value => return 200",function(r) return checkTriggers(r,firstRuleTrigs) end,nil,
  }
   testExprs(stdTests,{})
  --testRules(stdRules,{})

end

function QuickApp:onInit()
  local er = fibaro.EventRunner(self)
  self:debug(er)
  er.speed(1*24)
end