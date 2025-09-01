fibaro.EventRunner = fibaro.EventRunner or { debugFlags = {} }
local ER = fibaro.EventRunner
local debugFlags = ER.debugFlags
ER.propFilters = {}

-------------- builtin props -------------------------
-- getProps helpers
local function BN(x) if type(x)=='boolean' then return x and 1 or 0 else return tonumber(x) or 0 end end
local function get(id,prop) return fibaro.get(id,prop) end
local function getnum(id,prop) return tonumber((fibaro.get(id,prop))) or nil end
local function on(id,prop) return BN(fibaro.get(id,prop)) > 0 end
local function off(id,prop) return BN(fibaro.get(id,prop)) == 0 end
local function call(id,cmd) fibaro.call(id,cmd); return true end
local function toggle(id,prop) if on(id,prop) then fibaro.call(id,'turnOff') else fibaro.call(id,'turnOn') end return true end
local function profile(id,_) return api.get("/profiles/"..id) end
local function child(id,_) return quickApp.childDevices[id] end
local function last(id,prop) local _,t=fibaro.get(id,prop); local r = t and os.time()-t or 0; return r end
local function cce(id,_,e) 
  if e==nil then return {} end
  return e.type=='device' and e.property=='centralSceneEvent'and e.id==id and e.value or {} 
end
local function ace(id,_,e) if e==nil then return {} end return e.type=='device' and e.property=='accessControlEvent' and e.id==id and e.value or {} end
local function sae(id,_,e) if e==nil then return nil end return e.type=='device' and e.property=='sceneActivationEvent' and e.id==id and e.value.sceneId end
local mapOr,mapAnd,mapF=table.mapOr,table.mapAnd,function(f,l,s) table.mapf(f,l,s); return true end
local function partition(id) return api.get("/alarms/v1/partitions/" .. id) or {} end
local function armState(id) return id==0 and fibaro.getHomeArmState() or fibaro.getPartitionArmState(id) end
local function arm(id,action)
  if action=='arm' then 
    local _,res = ER.alarmFuns.armPartition(id); return res == 200
  else
    local _,res = ER.alarmFuns.unarmPartition(id); return res == 200
  end
end
local function tryArm(id)
  local data,res = ER.alarmFuns.tryArmPartition(id)
  if res ~= 200 then return false end
  if type(data) == 'table' then
    ER.sourceTrigger:post({type='alarm',id=id,action='tryArm',property='delayed',value=data})
  end
  return true
end
local helpers = { BN=BN, get=get, on=on, off=off, call=call, profile=profile, child=child, last=last, cce=cce, ace=ace, sae=sae, mapOr=mapOr, mapAnd=mapAnd, mapF=mapF }

local getProps={}
ER.getProps = getProps
-- { type, function to get prop, property name in sourceTrigger, reduce function, if props is a rule trigger }
getProps.value={'device',get,'value',nil,true}
getProps.state={'device',get,'state',nil,true}
getProps.bat={'device',getnum,'batteryLevel',nil,true}
getProps.power={'device',getnum,'power',nil,true}
getProps.isDead={'device',get,'dead',mapOr,true}
getProps.isOn={'device',on,'value',mapOr,true}
getProps.isOff={'device',off,'value',mapAnd,true}
getProps.isAllOn={'device',on,'value',mapAnd,true}
getProps.isAnyOff={'device',off,'value',mapOr,true}
getProps.last={'device',last,'value',nil,true}

getProps.armed={'alarm',function(id) return  armState(id)=='armed' end,'armed',mapOr,true}
getProps.tryArm={'alarm',tryArm,nil,'alarm',false}
getProps.isArmed={'alarm',function(id) return partition(id).armed end,'armed',mapOr,true}
getProps.isAllArmed={'alarm',function(id) return partition(id).armed end,'armed',mapAnd,true,true}
getProps.isDisarmed={'alarm',function(id) return partition(id).armed==false end,'armed',mapAnd,true}
getProps.isAnyDisarmed={'alarm',function(id) return partition(id).armed==false end,'armed',mapOr,true,false}
getProps.isAlarmBreached={'alarm',function(id) return partition(id).breached end,'breached',mapOr,true}
getProps.isAlarmSafe={'alarm',function(id) return partition(id).breached==false end,'breached',mapAnd,true}
getProps.isAllAlarmBreached={'alarm',function(id) return partition(id).breached end,'breached',mapAnd,true}
getProps.isAnyAlarmSafe={'alarm',function(id) return partition(id).breached==false end,'breached',mapOr,true,false}

getProps.child={'device',child,nil,nil,false}
getProps.parent={'device',function(id) return api.get("/devices/"..id).parentId end,nil,nil,false}
getProps.profile={'device',profile,nil,nil,false}
getProps.scene={'device',sae,'sceneActivationEvent',nil,true}
getProps.access={'device',ace,'accessControlEvent',nil,true}
getProps.central={'device',cce,'centralSceneEvent',nil,true}
getProps.safe={'device',off,'value',mapAnd,true}
getProps.breached={'device',on,'value',mapOr,true}
getProps.isOpen={'device',on,'value',mapOr,true}
getProps.isClosed={'device',off,'value',mapAnd,true}
getProps.lux={'device',getnum,'value',nil,true}
getProps.volume={'device',get,'volume',nil,true}
getProps.position={'device',get,'position',nil,true}
getProps.temp={'device',get,'value',nil,true}
getProps.coolingThermostatSetpoint={'device',get,'coolingThermostatSetpoint',nil,true}
getProps.coolingThermostatSetpointCapabilitiesMax={'device',get,'coolingThermostatSetpointCapabilitiesMax',nil,true}
getProps.coolingThermostatSetpointCapabilitiesMin={'device',get,'coolingThermostatSetpointCapabilitiesMin',nil,true}
getProps.coolingThermostatSetpointFuture={'device',get,'coolingThermostatSetpointFuture',nil,true}
getProps.coolingThermostatSetpointStep={'device',get,'coolingThermostatSetpointStep',nil,true}
getProps.heatingThermostatSetpoint={'device',get,'heatingThermostatSetpoint',nil,true}
getProps.heatingThermostatSetpointCapabilitiesMax={'device',get,'heatingThermostatSetpointCapabilitiesMax',nil,true}
getProps.heatingThermostatSetpointCapabilitiesMin={'device',get,'heatingThermostatSetpointCapabilitiesMin',nil,true}
getProps.heatingThermostatSetpointFuture={'device',get,'heatingThermostatSetpointFuture',nil,true}
getProps.heatingThermostatSetpointStep={'device',get,'heatingThermostatSetpointStep',nil,true}
getProps.thermostatFanMode={'device',get,'thermostatFanMode',nil,true}
getProps.thermostatFanOff={'device',get,'thermostatFanOff',nil,true}
getProps.thermostatMode={'device',get,'thermostatMode',nil,true}
getProps.thermostatModeFuture={'device',get,'thermostatModeFuture',nil,true}
getProps.on={'device',call,'turnOn',mapF,true}
getProps.off={'device',call,'turnOff',mapF,true}
getProps.play={'device',call,'play',mapF,nil}
getProps.pause={'device',call,'pause',mapF,nil}
getProps.open={'device',call,'open',mapF,true}
getProps.close={'device',call,'close',mapF,true}
getProps.stop={'device',call,'stop',mapF,true}
getProps.secure={'device',call,'secure',mapF,false}
getProps.unsecure={'device',call,'unsecure',mapF,false}
getProps.isSecure={'device',on,'secured',mapAnd,true}
getProps.isUnsecure={'device',off,'secured',mapOr,true}
getProps.name={'device',function(id) return fibaro.getName(id) end,nil,nil,false}
getProps.partition={'alarm',function(id) return partition(id) end,nil,nil,false}
getProps.HTname={'device',function(id) return ER.reverseVar(id) end,nil,nil,false}
getProps.roomName={'device',function(id) return fibaro.getRoomNameByDeviceID(id) end,nil,nil,false}
getProps.trigger={'device',function() return true end,'value',nil,true}
getProps.time={'device',get,'time',nil,true}
getProps.manual={'device',function(id) return quickApp:lastManual(id) end,'value',nil,true}
getProps.start={'device',function(id) return fibaro.scene("execute",{id}) end,"",mapF,false}
getProps.kill={'device',function(id) return fibaro.scene("kill",{id}) end,"",mapF,false}
getProps.toggle={'device',toggle,'value',mapF,true}
getProps.wake={'device',call,'wakeUpDeadDevice',mapF,true}
getProps.removeSchedule={'device',call,'removeSchedule',mapF,true}
getProps.retryScheduleSynchronization={'device',call,'retryScheduleSynchronization',mapF,true}
getProps.setAllSchedules={'device',call,'setAllSchedules',mapF,true}
getProps.levelIncrease={'device',call,'startLevelIncrease',mapF,nil}
getProps.levelDecrease={'device',call,'startLevelDecrease',mapF,nil}
getProps.levelStop={'device',call,'stopLevelChange',mapF,nil}
getProps.type={'device',function(id) return ER.getDeviceInfo(id).type end,'type',mapF,nil}

-- setProps helpers
local function set(id,cmd,val) fibaro.call(id,cmd,val); return val end
local function set2(id,cmd,val)
  assert(type(val)=='table' and #val>=3,"setColor expects a table with 3 values")
  fibaro.call(id,cmd,table.unpack(val)); 
  return val 
end
local function setProfile(id,_,val) if val then fibaro.profile("activateProfile",id) end return val end
local function setState(id,_,val) fibaro.call(id,"updateProperty","state",val); return val end
local function setProps(id,cmd,val) fibaro.call(id,"updateProperty",cmd,val); return val end
local function dim2(id,_,val) ER.utilities.dimLight(id,table.unpack(val)) end
local function pushMsg(id,cmd,val) fibaro.alert(fibaro._pushMethod,{id},val); return val end
local function setAlarm(id,cmd,val) arm(id,val and 'arm' or 'disarm') return val end
helpers.set, helpers.set2, helpers.setProfile, helpers.setState, helpers.setProps, helpers.dim2, helpers.pushMsg = set, set2, setProfile, setState, setProps, dim2, pushMsg

local setProps = {}
ER.setProps = setProps
-- { function to get prop, property name }
setProps.R={set,'setR'} -- Don't think the RGBs are valid anymore...
setProps.G={set,'setG'}
setProps.B={set,'setB'}
setProps.W={set,'setW'}
setProps.value={set,'setValue'}
setProps.state={setState,'setState'}
setProps.prop={function(id,_,val) fibaro.call(id,"updateProperty",table.unpack(val)) end,'upDateProp'}

setProps.armed={setAlarm,'setAlarm'}

setProps.profile={setProfile,'setProfile'}
setProps.time={set,'setTime'}
setProps.power={set,'setPower'}
setProps.targetLevel={set,'setTargetLevel'}
setProps.interval={set,'setInterval'}
setProps.mode={set,'setMode'}
setProps.setpointMode={set,'setSetpointMode'}
setProps.defaultPartyTime={set,'setDefaultPartyTime'}
setProps.scheduleState={set,'setScheduleState'}
setProps.color={set2,'setColor'}
setProps.volume={set,'setVolume'}
setProps.position={set,'setPosition'}
setProps.positions={setProps,'availablePositions'}
setProps.mute={set,'setMute'}
setProps.thermostatSetpoint={set2,'setThermostatSetpoint'}
setProps.thermostatMode={set,'setThermostatMode'}
setProps.heatingThermostatSetpoint={set,'setHeatingThermostatSetpoint'}
setProps.coolingThermostatSetpoint={set,'setCoolingThermostatSetpoint'}
setProps.thermostatFanMode={set,'setThermostatFanMode'}
setProps.schedule={set2,'setSchedule'}
setProps.dim={dim2,'dim'}
fibaro._pushMethod = 'push'
setProps.msg={pushMsg,"push"}
setProps.defemail={set,'sendDefinedEmailNotification'}
setProps.btn={set,'pressButton'} -- ToDo: click button on QA?
setProps.email={function(id,_,val) local _,_ = val:match("(.-):(.*)"); fibaro.alert('email',{id},val) return val end,""}
setProps.start={function(id,_,val) 
  if type(val)=='table' and val.type then 
    ER.sourceTrigger:postRemote(id,val) return true
  else 
    fibaro.scene("execute",{id}) return true
  end
end,""}
setProps.sim_pressed={function(id,_,val) ER.sourceTrigger:post({type='device',id=id,property='centralSceneEvent',value={keyId=val,keyAttribute='Pressed'}}) end,"push"} -- For simulated button presses
setProps.sim_helddown={function(id,_,val) ER.sourceTrigger:post({type='device',id=id,property='centralSceneEvent',value={keyId=val,keyAttribute='HeldDown'}}) end,"push"}
setProps.sim_released={function(id,_,val) ER.sourceTrigger:post({type='device',id=id,property='centralSceneEvent',value={keyId=val,keyAttribute='Released'}}) end,"push"}

local filters = ER.propFilters
ER.propFilterTriggers = {}
local function NB(x) if type(x)=='number' then return x~=0 and true or false else return x end end
local function mapAnd(l) for _,v in ipairs(l) do if not NB(v) then return false end end return true end
local function mapOr(l) for _,v in ipairs(l) do if NB(v) then return true end end return false end
function filters.average(list) local s = 0; for _,v in ipairs(list) do s=s+BN(v) end return s/#list end
function filters.sum(list) local s = 0; for _,v in ipairs(list) do s=s+BN(v) end return s end
function filters.allFalse(list) return not mapOr(list) end
function filters.someFalse(list) return not mapAnd(list)  end
function filters.allTrue(list) return mapAnd(list) end
function filters.someTrue(list) return mapOr(list)  end
function filters.mostlyTrue(list) local s = 0; for _,v in ipairs(list) do s=s+(NB(v) and 1 or 0) end return s>#list/2 end
function filters.mostlyFalse(list) local s = 0; for _,v in ipairs(list) do s=s+(NB(v) and 0 or 1) end return s>#list/2 end
function filters.bin(list) local s={}; for _,v in ipairs(list) do s[#s+1]=NB(v) and 1 or 0 end return s end
function filters.id(list,ev) return next(ev) and ev.id or list end -- If we called from rule trigger collector we return whole list
local function collect(t,m)
  if type(t)=='table' then
    for _,v in pairs(t) do collect(v,m) end
  else m[t]=true end
end
function filters.leaf(tree)
  local map,res = {},{}
  collect(tree,map)
  for e,_ in pairs(map) do res[#res+1]=e end
  return res 
end

----------------------------------------- PropObject handling --------------------------------------

PropObject = {}
class 'PropObject'
function PropObject:__init()
  self._isPropObject = true
  self.__str="PObj:"..tostring({}):match("(%d.*)")
end
function PropObject:isProp(prop) return self.getProp[prop] or self.setProp[prop] end
function PropObject:isTrigger(prop) return self.trigger[prop] end
function PropObject:hasReduce(prop) return self.map[prop] end
function PropObject:_setProp(prop,value)
  local sp = self.setProp[prop]
  if not sp then return nil,"Unknown property: "..tostring(prop) end
  sp(self,prop,value)
  return true
end
function PropObject:_getProp(prop,env)
  local gp = self.getProp[prop]
  if not gp then return nil,"Unknown property: "..tostring(prop) end
  return gp(self,prop)
end
function PropObject:getTrigger(id,prop)
  local t = self.trigger[prop]
  return t and type(t) == "func".."tion" and t(self,id,prop) or type(t) == 'table' and t or nil
end
function PropObject:reduce(prop,value)
  local red = self.map[prop]
  return red(value)
end
function PropObject:__tostring() return self.__str end

ER.PropObject = PropObject
function ER.definePropClass(name)
  class(name)(PropObject)
  local cl = _G[name]
  cl.getProp,cl.setProp,cl.trigger,cl.map={},{},{},{}
end

NumberPropObject = {}
class 'NumberPropObject'(PropObject)
function NumberPropObject:__init(num)  PropObject.__init(self) self.id = num end
function NumberPropObject:_getProp(prop,env)
  local gp = getProps[prop]
  if not gp then env.error("Unknown property: "..tostring(prop)) os.exit() end
  local fun = gp[2]
  local prop = gp[3]
  local value = fun(self.id,prop,env.trigger)
  return value
end
function NumberPropObject:_setProp(prop,value)
  local sp = setProps[prop]
  if not sp then return nil,"Unknown property: "..tostring(prop) end
  local fun = sp[1]
  local cmd = sp[2]
  local r = fun(self.id,cmd,value)
  return true
end
function NumberPropObject:reduce(prop,value,env)
  local gp = getProps[prop]
  if not gp then return env.error("Unknown property: "..tostring(prop)) end
  local red = gp[4]
  if red == nil then return value end
  return red(value)
end
function NumberPropObject:isProp(prop) return getProps[prop] or setProps[prop] end
function NumberPropObject:isTrigger(prop) return (getProps[prop] or {})[5] end
function NumberPropObject:getTrigger(id, prop) return {type='device', id = self.id, property =  getProps[prop][3]} end

local numObjects = {}
local function resolvePropObject(obj)
  if type(obj) == 'userdata' and obj._isPropObject then return obj
  elseif type(obj) == 'number' then 
    local po = numObjects[obj] or NumberPropObject(obj)
    numObjects[obj] = po
    return po
  else return nil end
end

local function executeGetProp(obj,prop,env)
  if type(obj) == 'table' then
    if next(obj) == nil then return env.error("Expected non-empty table, got empty table") end
    if ER.propFilters[prop] then
      local filter = ER.propFilters[prop]
      if not filter then env.error("Unknown filter: "..tostring(prop)) os.exit() end
      return filter(obj, env.trigger)
    end
    if #obj == 0 then return env.error("Expected non-empty table, got empty table") end
    local r,fo = {},nil
    for k,v in pairs(obj) do
      local v = resolvePropObject(v)
      fo = fo or v
      if not v then return env.error("Not a prop object: "..tostring(v)) end
      r[k] = v:_getProp(prop,env)
    end
    if fo then r = fo:reduce(prop,r) end
    return r
  else
    local v = resolvePropObject(obj)
    if not v then return env.error("Not a prop object: "..tostring(v)) end
    return v:_getProp(prop,env)
  end
end

local function executeSetProp(obj,prop,value,env)
  if type(obj) == 'table' then
    if #obj == 0 then return env.error("Expected non-empty table, got empty table") end
    for _,v in pairs(obj) do
      local v = resolvePropObject(v)
      if not v then return env.error("Not a prop object: "..tostring(v)) end
      v:_setProp(prop,value)
    end
  else
    local v = resolvePropObject(obj)
    if not v then return env.error("Not a prop object: "..tostring(v)) end
    v:_setProp(prop,value)
  end
end

ER.executeGetProp = executeGetProp
ER.executeSetProp = executeSetProp
ER.resolvePropObject = resolvePropObject