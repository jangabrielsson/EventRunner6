
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
    - [HTTP Client with Retry](#http-client-with-retry)
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
Add a file to the EventRunner 6 QuickApp with a global `loadLibrary` function:

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

### HTTP Client with Retry
```lua
-- HTTP client with automatic retry logic
function er.httpRequest(url, options, maxRetries)
  maxRetries = maxRetries or 3
  options = options or {}
  
  local function attempt(retryCount)
    net.HTTPClient():request(url, {
      options = options,
      success = function(response)
        if options.success then options.success(response) end
      end,
      error = function(error)
        if retryCount < maxRetries then
          er.debug("HTTP request failed, retrying... (" .. retryCount .. "/" .. maxRetries .. ")")
          setTimeout(function() attempt(retryCount + 1) end, 1000 * retryCount)
        else
          er.error("HTTP request failed after " .. maxRetries .. " attempts: " .. tostring(error))
          if options.error then options.error(error) end
        end
      end
    })
  end
  
  attempt(1)
end
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
function loadLibrary(er)
  -- System information
  er.variables.QA = er.qa
  
  -- Enhanced logging
  er.logLevel = "INFO"
  er.logLevels = {DEBUG = 1, INFO = 2, WARNING = 3, ERROR = 4}
  
  function er.log(level, message, category)
    if er.logLevels[level] >= er.logLevels[er.logLevel] then
      local timestamp = os.date("%Y-%m-%d %H:%M:%S")
      local prefix = string.format("[%s] [%s]", timestamp, level)
      if category then prefix = prefix .. " [" .. category .. "]" end
      
      local logFunc = er.debug
      if level == "INFO" then logFunc = er.info
      elseif level == "WARNING" then logFunc = er.warning
      elseif level == "ERROR" then logFunc = er.error
      end
      
      logFunc(prefix .. " " .. message)
    end
  end
  
  -- Variable helpers
  function er.defVars(tab) 
    for k, v in pairs(tab) do 
      er.variables[k] = v 
    end
  end
  er.variables.defVars = er.defVars
  
  -- Smart notifications
  er.notificationLimits = {}
  function er.smartNotify(message, category, limitMinutes)
    category = category or "general"
    limitMinutes = limitMinutes or 60
    
    local now = os.time()
    local lastSent = er.notificationLimits[category] or 0
    
    if now - lastSent > (limitMinutes * 60) then
      er.info(message)
      er.notificationLimits[category] = now
      return true
    end
    return false
  end
  
  -- Add your custom functions here...
  
  er.log("INFO", "Add-on library loaded successfully", "system")
end
```

This add-on system provides a comprehensive set of utilities to extend EventRunner 6 with additional functionality while maintaining clean separation and modularity.