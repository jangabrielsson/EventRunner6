<p align="center">
    <img src="https://raw.githubusercontent.com/jangabrielsson/EventRunner6/main/assets/logo.png" alt="EventRunner6 Logo" width="320"/>
</p>

# EventRunner6

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

EventRunner6 is a powerful rule-based automation framework for Fibaro Home Center 3 (HC3) home automation systems. It provides an intuitive domain-specific language for creating complex automation rules with advanced event handling, scheduling, and device control capabilities.

## Features

- **Intuitive Rule Syntax**: Write automation rules using a simple, readable syntax
- **Advanced Event Handling**: Comprehensive event system for device states, global variables, scenes, and custom events
- **Flexible Scheduling**: Support for daily schedules, intervals, and time-based triggers
- **Device Property Management**: Easy access to device properties with built-in helper functions
- **Simulation Support**: Built-in simulation capabilities for testing rules
- **Compilation System**: Efficient rule compilation and execution
- **Comprehensive Logging**: Detailed logging and debugging capabilities

## Quick Start

### Installation

1. Import the `EventRunner6.fqa` file into your Fibaro HC3 system
2. Configure the QuickApp in your desired room
3. Start writing rules in the `main` function
4. [Home automation recipes](doc/Recipes.md)

### Basic Example

```lua
function QuickApp:main(er)
  local rule, var = er.rule, er.variables
  
  -- Define device mappings
  var.HT = {
    kitchen = {
      light = { roof = 66, window = 67 },
      sensor = { roof = 68 }
    }
  }

  -- Simple automation rule
  rule("HT.kitchen.sensor.roof:breached => HT.kitchen.light.roof:on")
end
```

## Rule Syntax

EventRunner6 uses an intuitive syntax for defining automation rules.
For more detailed rule syntax and advanced usage, see the [EventScript reference](doc/EventScript.md). Also a more tutorial style document at [EventScript tutorial](doc/Tutorial.md)

### Basic Rule Structure
```lua
rule("trigger => action")
```

### Device Properties
Access device properties using the dot notation:
```lua
-- Check if a device is on
rule("HT.living.light.main:isOn => log('Light is on')")

-- React to sensor breaches
rule("HT.bedroom.sensor.motion:breached => HT.bedroom.light:on")
```

### Time-based Triggers
```lua
-- Daily triggers
rule("@10:00 => HT.all.lights:off")

-- Interval triggers  
rule("@@00:05 => log('Every 5 minutes')")

-- Time ranges
rule("10:00..22:00 & HT.sensor.motion:breached => HT.light:on")
```

### Complex Conditions
```lua
-- Multiple conditions
rule("HT.sensor.motion:breached & 22:00..06:00 => HT.light:on")

-- OR conditions
rule("HT.sensor.door:breached | HT.sensor.window:breached => HT.alarm:on")
```

## Device Properties

EventRunner6 provides extensive device property support:

### Sensor Properties
- `breached` - Sensor is triggered
- `safe` - Sensor is safe
- `bat` - Battery level
- `last` - Time since last trigger

### Light Properties
- `isOn/isOff` - Light state
- `value` - Light value/brightness
- `on/off` - Turn light on/off

### Alarm Properties
- `armed/isArmed` - Alarm state
- `breached` - Alarm triggered
- `tryArm` - Attempt to arm

### Scene Properties
- `start` - Start scene
- `kill` - Stop scene

## Advanced Features

### Global Variables
```lua
-- Access global variables
rule("$myVariable == 'active' => HT.light:on")

-- QuickApp variables
rule("$$localVar > 10 => action()")
```

### Custom Events
```lua
-- React to custom events
rule("#myCustomEvent => handleCustomEvent()")
```

### Device Collections
```lua
-- Work with multiple devices
var.allLights = {66, 67, 68, 69}
rule("sunset => allLights:off")
```

### Conditional Logic
```lua
rule([[
  HT.sensor.motion:breached => 
    if HT.sensor.lux:value < 100 then
      HT.light:on
    else
      log('Bright enough, no light needed')
    end
]])
```

## Configuration Options

Configure EventRunner6 behavior through the `opts` table:

```lua
er.opts = {
  started = true,      -- Log when rules start
  check = true,        -- Log rule condition results  
  result = false,      -- Log rule results
  listTriggers = true  -- List all rule triggers
}
```

## Project Structure

```
├── eventrunner.lua     # Main QuickApp entry point
├── rule.lua           # Core rule engine
├── compiler.lua       # Rule compilation system  
├── parser.lua         # Rule syntax parser
├── props.lua          # Device property definitions
├── utils.lua          # Utility functions and time handling
├── builtins.lua       # Built-in functions
├── sim.lua            # Simulation support
├── tests/             # Test files
│   ├── rules.lua      # Rule test examples
│   └── test.lua       # Test framework
├── include.txt        # File inclusion list
└── EventRunner6.fqa   # Compiled QuickApp package
```

## Development

### Adding New Rules
Edit the `main` function in `eventrunner.lua` to add new automation rules:

```lua
function QuickApp:main(er)
  local rule, var = er.rule, er.variables
  
  -- Your device mappings
  var.HT = { ... }
  
  -- Your rules
  rule("trigger1 => action1")
  rule("trigger2 => action2")
end
```

### Testing
Use the simulation system for testing:

```lua
-- Load test devices
-- THis only works for offline testing, ex. using plua
er.loadSimDevice("path/to/test/device.lua")

-- Speed up time for testing
er.speed(24) -- Run 24 hours in accelerated time
```

### Debugging
Enable debug flags for detailed logging:

```lua
fibaro.EventRunner.debugFlags = {
  post = true,           -- Log event posting
  sourceTrigger = true,  -- Log source triggers
  refreshEvents = true   -- Log refresh events
}
```

## Dependencies

- Fibaro Home Center 3
- Lua 5.3+
- Fibaro QuickApp framework

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

- **Jan Gabrielsson** - *Initial work and development*

## Acknowledgments

- Fibaro community for feedback and testing
- Contributors to the EventRunner framework evolution

---

For more detailed documentation and examples, visit the project repository or check the test files in the `tests/` directory.
