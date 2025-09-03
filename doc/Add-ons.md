
# EventRunner 6 Add-ons

Additional functions and utilities to extend EventRunner 6 functionality.

## Table of Contents

- [EventRunner 6 Add-ons](#eventrunner-6-add-ons)
  - [Table of Contents](#table-of-contents)
  - [Setup](#setup)
  - [System Information](#system-information)
    - [EventRunner QuickApp Self Reference](#eventrunner-quickapp-self-reference)
    - [System Uptime](#system-uptime)
    - [Memory Usage](#memory-usage)
  - [Time \& Scheduling](#time--scheduling)
  - [Weather Integration](#weather-integration)
    - [Advanced Weather Object](#advanced-weather-object)
  - [Notification Helpers](#notification-helpers)
  - [HTTP \& Network](#http--network)
    - [Synchronous HTTP calls](#synchronous-http-calls)
    - [Synchronous HC3 HTTP calls](#synchronous-hc3-http-calls)
  - [Debugging \& Logging](#debugging--logging)
  - [Module System](#module-system)
    - [Enhanced Module System](#enhanced-module-system)
  - [Math \& Calculations](#math--calculations)
    - [Statistical Functions](#statistical-functions)
    - [Trend Analysis](#trend-analysis)
  - [String Utilities](#string-utilities)
    - [String Helpers](#string-helpers)
  - [Variable Utilities](#variable-utilities)
    - [Variable Helpers](#variable-helpers)
  - [Example Complete Add-on File](#example-complete-add-on-file)

## Setup
Add a file to the EventRunner 6 QuickApp with a local `loadLibrary` function:

```lua
local function loadLibrary(er)
   -- Your add-on functions defined here
end

setTimeout(function() fibaro.loadLibrary(loadLibrary) end,0)
```

Alternatively, declare a global lua function and load the library manually from 'main'

```lua
function loadLibrary(er)
   -- Your add-on functions defined here
end
```
Then in the 'main' file do:

```lua
function QuickApp:main(er)
  loadLibrary(er) -- Load your library functions
  -- Rest of your rules go here
end
```


## System Information

### EventRunner QuickApp Self Reference
```lua
-- Access the QuickApp instance from rules
er.variables.QA = er.qa
```

### System Uptime
```lua
-- Get HC3 system uptime information
function er.variables._updateUptime()
  local uptime = os.time() - api.get("/settings/info").serverStatus
  local uptimeStr = string.format("%d days, %d hours, %d minutes", 
    uptime // (24*3600), 
    (uptime % (24*3600)) // 3600, 
    (uptime % 3600) // 60)
  
  er.variables.uptime = uptime
  er.variables.uptimeStr = uptimeStr
  er.variables.uptimeMinutes = uptime // 60
end

-- Update uptime every hour
er.rule("@@01:00 => _updateUptime()")

-- Log uptime when ER starts
rule("log('Uptime %s',uptimeStr)")
```

### Memory Usage
```lua
-- Monitor QuickApp memory usage
function r.variables.memoryKB()
  collectgarbage("collect")
  return collectgarbage("count")
end

-- Log memory usage every 6 hours
er.rule([[@@06:00 =>
  log('Memory usage: %.2fKB',memoryKB())
]])
```

## Time & Scheduling

## Weather Integration

### Advanced Weather Object
```lua
-- Enhanced weather integration with caching and triggers
Weather = {}
er.definePropClass("Weather") -- Define custom weather object

function Weather:__init() 
  PropObject.__init(self)
  self._cache = {}
  self._cacheTime = 0
  self._cacheTimeout = 300 -- 5 minutes
end

function Weather:_updateCache()
  local now = os.time()
  if now - self._cacheTime > self._cacheTimeout then
    self._cache = api.get("/weather")
    self._cacheTime = now
  end
  return self._cache
end

function Weather.getProp.temp(prop, env) 
  return prop.obj:_updateCache().Temperature 
end

function Weather.getProp.humidity(prop, env) 
  return prop.obj:_updateCache().Humidity 
end

function Weather.getProp.wind(prop, env) 
  return prop.obj:_updateCache().Wind 
end

function Weather.getProp.condition(prop, env) 
  return prop.obj:_updateCache().WeatherCondition 
end

function Weather.getProp.pressure(prop, env)
  return prop.obj:_updateCache().Pressure
end

function Weather.trigger.temp(prop) 
  return {type='weather', property='Temperature'} 
end

function Weather.trigger.humidity(prop) 
  return {type='weather', property='Humidity'} 
end

function Weather.trigger.wind(prop) 
  return {type='weather', property='Wind'} 
end

function Weather.trigger.condition(prop) 
  return {type='weather', property='WeatherCondition'} 
end

function Weather.trigger.pressure(prop)
  return {type='weather', property='Pressure'}
end

er.variables.weather = Weather()
```
## Notification Helpers


## HTTP & Network

### Synchronous HTTP calls
```lua

  local function httpCall(cb,url,options,data,dflt)
        local opts = table.copy(options)
        opts.headers = opts.headers or {}
        if opts.type then
            opts.headers["content-type"]=opts.type
            opts.type=nil
        end
        if not opts.headers["content-type"] then
            opts.headers["content-type"] = 'application/json'
        end
        if opts.user and opts.pwd then 
            opts.headers['Authorization']= "Basic "..er.base64encode((opts.user or "")..":"..(opts.pwd or ""))
            opts.user,opts.pwd=nil,nil
        end
        opts.data = data and json.encode(data)
        --opts.checkCertificate = false
        local basket = {}
        net.HTTPClient():request(url,{
            options=opts,
            success = function(res0)
                pcall(function()
                    res0.data = json.decode(res0.data)  
                end)
                cb(res0.data or dflt,res0.status)
            end,
            error = function(err) cb(dflt,err) end
        })
        return tonumber(opts.timeout) and opts.timeout*1000 or 30*1000
    end
    
    local http = {
        get = er.createAsyncFun(function(cb,url,options,dflt) options=options or {}; options.method="GET" return httpCall(cb,url,options,dflt) end),
        put = er.createAsyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="PUT" return httpCall(cb,url,options,data,dflt) end),
        post = er.createAsyncFun(function(cb,url,options,data,dflt) options=options or {}; options.method="POST" return httpCall(cb,url,options,data,dflt) end),
        delete = er.createAsyncFun(function(cb,url,options,dflt) options=options or {}; options.method="DELETE" return httpCall(cb,url,options,dflt) end),
    }
    
    var.http = http

    -- Usage: rule("res = http.get('http://google.com')")
end
```

### Synchronous HC3 HTTP calls

```lua
    
    local function hc3api(cb,method,api,data)
        local creds = er.variables._creds
        if not creds then setTimeout(function() cb(nil,404) end,0) end
        net.HTTPClient():request("http://localhost/api"..api,{
            options = {
                method = method or "GET",
                headers = {
                    ['Accept'] = 'application/json',
                    ["Authorization"] = creds,
                    ['X-Fibaro-Version'] = '2',
                   -- ["Content-Type"] = "application/json",
                },
                data = data and json.encode(data) or nil
            },
            success = function(resp)
                cb(json.decode(resp.data),200)
            end,
            error = function(err)
                cb(nil,err)
            end
        })
    end

    local api2 = {
        get = er.createAsyncFun(function(cb,path) return hc3api(cb,"GET",path,nil) end),
        put = er.createAsyncFun(function(cb,path,data) return hc3api(cb,"PUT",path,data) end),
        post = er.createAsyncFun(function(cb,path,data) return hc3api(cb,"POST",path,data) end),
        delete = er.createAsyncFun(function(cb,path) return hc3api(cb,"DELETE",path,nil) end),
    }
    var.hc3api = api2
    var._hc3api = hc3api
```

## Debugging & Logging

## Module System

### Enhanced Module System
```lua
-- Modular system for organizing rules and functionality
MODULES = MODULES or {}

-- Register a module
function er.registerModule(name, priority, loader)
  table.insert(MODULES, {
    name = name,
    prio = priority or 0,
    loader = loader,
    _inited = false
  })
end

local function loadModule(m, er)
  if not m._inited then
    m._inited = true
    er.log("INFO", "Loading module: " .. m.name, "modules")
    m.loader(er)
  end
end

function LoadModules(er) -- Global function called from main
  table.sort(MODULES, function(a, b) return a.prio < b.prio end)
  
  local afterModules = 0
  for i = 1, #MODULES do
    if MODULES[i].prio < 0 then 
      loadModule(MODULES[i], er)
    else 
      afterModules = i
      break 
    end
  end
  
  -- Load remaining modules after initialization
  setTimeout(function()
    for i = afterModules, #MODULES do 
      loadModule(MODULES[i], er) 
    end
  end, 0)
  
  return #MODULES >= 1
end

-- Usage:
-- er.registerModule("Lighting", -10, function(er)
--   er.rule("LivingRoomLights", er.timer("sunset"), function()
--     api.post("/devices/123/action/turnOn")
--   end)
-- end)
```

## Math & Calculations

### Statistical Functions
```lua
-- Mathematical utilities for sensor data analysis

function er.variance(values)
  local avg = er.average(values)
  local sum = 0
  for _, v in ipairs(values) do
    sum = sum + (v - avg) ^ 2
  end
  return sum / #values
end

function er.standardDeviation(values)
  return math.sqrt(er.variance(values))
end
```

### Trend Analysis
```lua
-- Analyze trends in sensor data
er.dataHistory = {}

function er.recordValue(sensor, value)
  if not er.dataHistory[sensor] then
    er.dataHistory[sensor] = {}
  end
  
  local history = er.dataHistory[sensor]
  table.insert(history, {value = value, timestamp = os.time()})
  
  -- Keep only last 100 readings
  if #history > 100 then
    table.remove(history, 1)
  end
end

function er.getTrend(sensor, periodMinutes)
  local history = er.dataHistory[sensor]
  if not history or #history < 2 then return "unknown" end
  
  local cutoff = os.time() - (periodMinutes * 60)
  local recent = {}
  
  for _, reading in ipairs(history) do
    if reading.timestamp >= cutoff then
      table.insert(recent, reading.value)
    end
  end
  
  if #recent < 2 then return "insufficient_data" end
  
  local first = recent[1]
  local last = recent[#recent]
  local change = last - first
  local threshold = 0.1 -- Adjust based on sensor type
  
  if math.abs(change) < threshold then
    return "stable"
  elseif change > 0 then
    return "increasing"
  else
    return "decreasing"
  end
end
```

## String Utilities

### String Helpers
```lua
-- String manipulation utilities
function er.trim(str)
  return str:match("^%s*(.-)%s*$")
end

function er.formatDuration(seconds)
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  
  if days > 0 then
    return string.format("%dd %dh %dm", days, hours, minutes)
  elseif hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  elseif minutes > 0 then
    return string.format("%dm %ds", minutes, secs)
  else
    return string.format("%ds", secs)
  end
end
```

## Variable Utilities
### Variable Helpers
```lua
-- Simplified variable management
function er.defVars(tab) 
  for k, v in pairs(tab) do 
    er.variables[k] = v 
  end
end

er.variables.defVars = er.defVars

-- Usage: er.defVars({temperature = 20, humidity = 45, lights_on = false})
```

---

## Example Complete Add-on File

Here's a complete example of how to structure your add-on file:

```lua
local function loadLibrary(er)
  -- System information
  er.variables.QA = er.qa
  
  -- Variable helpers
  function er.defVars(tab) 
    for k, v in pairs(tab) do 
      er.variables[k] = v 
    end
  end
  er.variables.defVars = er.defVars
  
  -- Add your custom functions here...
  
  print("Add-on library loaded successfully")
end

setTimeout(function() fibaro.loadLibrary(loadLibrary) end,0)
```

This add-on system provides a comprehensive set of utilities to extend EventRunner 6 with additional functionality while maintaining clean separation and modularity.