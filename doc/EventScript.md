# EventScript Language Documentation

EventScript is the rule-based automation language used by EventRunner6 for creating home automation rules on Fibaro HC3 controllers. It provides an intuitive syntax for defining triggers, conditions, and actions in automation scenarios.

## Table of Contents

1. [Language Overview](#language-overview)
2. [Basic Syntax](#basic-syntax)
3. [Triggers](#triggers)
   - [Daily Triggers](#daily-triggers)
   - [Interval Triggers](#interval-triggers)
   - [Event Triggers](#event-triggers)
   - [Device Triggers](#device-triggers)
   - [Trigger Variables](#trigger-variables)
4. [Functions](#functions)
   - [trueFor Function](#truefor-function)
5. [Property Functions](#property-functions)
   - [Device Properties](#device-properties)
   - [Device Control Actions](#device-control-actions)
   - [Device Assignment Properties](#device-assignment-properties)
   - [Partition Properties](#partition-properties)
   - [Thermostat Properties](#thermostat-properties)
   - [Scene Properties](#scene-properties)
   - [Information Properties](#information-properties)
   - [List Operations](#list-operations)
6. [Examples](#examples)
7. [Best Practices](#best-practices)

## Language Overview

EventScript uses a simple `trigger => action` syntax where:
- **Triggers** define when a rule should execute
- **Actions** define what should happen when triggered
- **Properties** provide access to device states and controls

## Basic Syntax

```lua
rule("trigger => action")
```

Rules are defined using the `rule()` function with a string containing the trigger-action pattern.

## Triggers

Triggers define the conditions under which rules should execute.

### Daily Triggers

Execute rules at specific times during the day:

```lua
rule("@time => action")                    -- Trigger at specific time
rule("@{time1,time2,...} => action")      -- Trigger at multiple times
rule("@{time,catch} => action")           -- Catchup: Run if deployed after time
rule("12:00..sunset => action")           -- Time interval guard, mostly part of more complex triggers
```

**Examples:**
```lua
rule("@08:00 => lights:on")               -- Turn on lights at 8 AM
rule("@{07:00,19:00} => securityCheck()")   -- Check security at 7 AM and 7 PM
rule("@sunset => outdoorLights:on")       -- Turn on outdoor lights at sunset
rule("sensor:breached & sunset..sunrise => outdoorLights:on") -- Turn on outdoor lights after sunset when sensor is breached
```

### Interval Triggers

Execute rules at regular intervals:

```lua
rule("@@00:05 => action")     -- Every 5 minutes
rule("@@-00:05 => action")    -- Every 5 minutes, aligned to clock
```

**Examples:**
```lua
rule("@@00:15 => temperatureCheck()")       -- Check temperature every 15 minutes
rule("@@-01:00 => hourlyReport()")          -- Generate report on the hour
```

### Event Triggers

Respond to custom events:

```lua
rule("#myEvent => action")                -- Trigger on custom event
rule("#myEvent{param=value} => action")   -- Trigger on event with parameters
```

**Examples:**
```lua
rule("#myEvent => temperatureCheck()")       -- Check temperature when getting #MyEvent
rule("@sunset => post(#myEvent)")            --POst #MyEvent at sunset
```

> **Note:** `#event` is shorthand for `{type='event'}`, and `#event{k1=v1,...}` expands to `{type='event', k1=v1, ...}`

### Device Triggers

React to device state changes:

```lua
rule("device:property => action")         -- Single device trigger
rule("{dev1,dev2,...}:property => action") -- Multiple device trigger
```

**Examples:**
```lua
rule("motionSensor:value => hallLight:on")
rule("{door1,door2,window1}:breached => alarm:on")
```

### Trigger Variables

Use custom variables as triggers:

```lua
er.triggerVariables.x = 9    -- Define trigger variable
rule("x => action")          -- Trigger when x changes
rule("x = 42")              -- Change x to trigger above rule
```

## Functions

### trueFor Function

Execute actions when conditions remain true for a specified duration:

```lua
rule("trueFor(duration, condition) => action")
```

**Examples:**
```lua
rule("trueFor(00:05, sensor:safe) => light:off")
-- Turn off light when sensor has been safe for 5 minutes

rule("trueFor(00:10, door:open) => log('Door open for %d minutes', 10*again(5))")
-- Log message with again(n) re-enabling the condition n times
```

## Property Functions

Property functions use the syntax `<ID>:<property>` for reading and `<ID>:<property> = <value>` for writing.

### Device Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | Trigger | Device value property |
| `state` | Trigger | Device state property |
| `bat` | Trigger | Battery level (0-100) |
| `power` | Trigger | Power consumption |
| `isDead` | Trigger | Device dead status |
| `isOn` | Trigger | True if device/any in list is on |
| `isOff` | Trigger | True if device is off/all in list are off |
| `isAllOn` | Trigger | True if all devices in list are on |
| `isAnyOff` | Trigger | True if any device in list is off |
| `last` | Trigger | Time since last breach/trigger |
| `safe` | Trigger | True if device is safe |
| `breached` | Trigger | True if device is breached |
| `isOpen` | Trigger | True if device is open |
| `isClosed` | Trigger | True if device is closed |
| `lux` | Trigger | Light sensor value |
| `volume` | Trigger | Audio volume level |
| `position` | Trigger | Device position (blinds, etc.) |
| `temp` | Trigger | Temperature value |

### Device Control Actions

| Property | Type | Description |
|----------|------|-------------|
| `on` | Action | Turn device on |
| `off` | Action | Turn device off |
| `toggle` | Action | Toggle device state |
| `play` | Action | Start media playback |
| `pause` | Action | Pause media playback |
| `open` | Action | Open device (blinds, locks) |
| `close` | Action | Close device |
| `stop` | Action | Stop device operation |
| `secure` | Action | Secure device (locks) |
| `unsecure` | Action | Unsecure device |
| `wake` | Action | Wake up dead Z-Wave device |
| `levelIncrease` | Action | Start level increase |
| `levelDecrease` | Action | Start level decrease |
| `levelStop` | Action | Stop level change |

### Device Assignment Properties

| Property | Description |
|----------|-------------|
| `value = <val>` | Set device value |
| `state = <val>` | Set device state |
| `R = <val>` | Set red color component |
| `G = <val>` | Set green color component |
| `B = <val>` | Set blue color component |
| `W = <val>` | Set white color component |
| `color = <rgb>` | Set RGB color values |
| `volume = <val>` | Set audio volume |
| `position = <val>` | Set device position |
| `power = <val>` | Set power level |
| `targetLevel = <val>` | Set target dimmer level |
| `interval = <val>` | Set interval value |
| `mode = <val>` | Set device mode |
| `mute = <bool>` | Set mute state |
| `dim = <table>` | Set dimming parameters |
| `msg = <text>` | Send push message |
| `email = <text>` | Send email notification |

### Partition Properties

| Property | Type | Description |
|----------|------|-------------|
| `armed` | Trigger | True if partition is armed |
| `isArmed` | Trigger | True if partition is armed |
| `isDisarmed` | Trigger | True if partition is disarmed |
| `isAllArmed` | Trigger | True if all partitions are armed |
| `isAnyDisarmed` | Trigger | True if any partition is disarmed |
| `isAlarmBreached` | Trigger | True if partition is breached |
| `isAlarmSafe` | Trigger | True if partition is safe |
| `isAllAlarmBreached` | Trigger | True if all partitions breached |
| `isAnyAlarmSafe` | Trigger | True if any partition is safe |
| `tryArm` | Action | Attempt to arm partition |
| `armed = <bool>` | Action | Arm or disarm partition |

### Thermostat Properties

| Property | Type | Description |
|----------|------|-------------|
| `thermostatMode` | Trigger/Action | Thermostat operating mode |
| `thermostatModeFuture` | Trigger | Future thermostat mode |
| `thermostatFanMode` | Trigger/Action | Fan operating mode |
| `thermostatFanOff` | Trigger | Fan off status |
| `heatingThermostatSetpoint` | Trigger/Action | Heating setpoint |
| `coolingThermostatSetpoint` | Trigger/Action | Cooling setpoint |
| `heatingThermostatSetpointCapabilitiesMax` | Trigger | Max heating setpoint |
| `heatingThermostatSetpointCapabilitiesMin` | Trigger | Min heating setpoint |
| `coolingThermostatSetpointCapabilitiesMax` | Trigger | Max cooling setpoint |
| `coolingThermostatSetpointCapabilitiesMin` | Trigger | Min cooling setpoint |
| `thermostatSetpoint = <val>` | Action | Set thermostat setpoint |

### Scene Properties

| Property | Type | Description |
|----------|------|-------------|
| `scene` | Trigger | Scene activation event |
| `start` | Action | Start/execute scene |
| `kill` | Action | Stop scene execution |

### Information Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | Info | Device name |
| `roomName` | Info | Room name containing device |
| `HTname` | Info | HomeTable variable name |
| `profile` | Info | Current active profile |
| `access` | Trigger | Access control event |
| `central` | Trigger | Central scene event |
| `time` | Trigger/Action | Device time property |
| `manual` | Trigger | Manual operation status |
| `trigger` | Trigger | Generic trigger property |

### List Operations

| Operation | Description |
|-----------|-------------|
| `average` | Average of numbers in list |
| `sum` | Sum of values in list |
| `allTrue` | True if all values are true |
| `someTrue` | True if at least one value is true |
| `allFalse` | True if all values are false |
| `someFalse` | True if at least one value is false |
| `mostlyTrue` | True if majority of values are true |
| `mostlyFalse` | True if majority of values are false |
| `bin` | Convert to binary (1 for truthy, 0 for falsy) |
| `leaf` | Extract leaf nodes from nested table |

## Examples

### Basic Device Control
```lua
rule("@08:00 => livingRoomLights:on")           -- Morning lights
rule("motionSensor:breached => hallwayLight:on") -- Motion activation
rule("@sunset => {porch,garden,driveway}:on")   -- Evening outdoor lights
```

### Conditional Logic
```lua
rule("door:isOpen & @sunset => securityLight:on")      -- Security at sunset
rule("trueFor(00:10, house:isAllOff) => alarm:arm")    -- Auto-arm when quiet
rule("luxSensor:value < 100 & motion:breached => lights:on") -- Smart lighting
```

### Time-based Automation
```lua
rule("@{07:00,19:00} => thermostat:mode='auto'")        -- Twice daily schedule
rule("22:00..06:00 & motion:breached => nightLight:on") -- Night mode
rule("@@00:30 => hvac:refresh")                         -- Regular maintenance
```

### List Operations
```lua
rule("temperatureSensors:average > 25 => fan:on")       -- Climate control
rule("{sensor1,sensor2,sensor3}:someTrue => alert:on")  -- Multi-sensor alert
rule("allLights:isAnyOff => log('Some lights are off')") -- Status monitoring
```

### Advanced Scenarios
```lua
-- Vacation mode
rule("$vacationMode == true & motion:breached => securityAlert")

-- Energy saving
rule("trueFor(01:00, room:isAllOff) => hvac:targetLevel=18")

-- Weather-based automation
rule("weatherStation:temp < 0 & @06:00 => carHeater:on")
```

## Best Practices

1. **Use meaningful device names** in your HomeTable variables
2. **Group related devices** in lists for easier management
3. **Combine time guards** with device triggers for smarter automation
4. **Use trueFor()** to avoid false triggers from brief state changes
5. **Test rules thoroughly** before deploying to production
6. **Document complex rules** with comments in your main function
7. **Use trigger variables** for inter-rule communication
8. **Leverage list operations** for aggregated device control


