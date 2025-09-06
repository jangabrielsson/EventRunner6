# GitHub Copilot Instructions for EventRunner6

## Project Overview
EventRunner6 is a rule-based automation framework for Fibaro Home Center 3 (HC3) home automation systems. It provides a domain-specific language (DSL) for creating complex automation rules with event handling, scheduling, and device control.

## Architecture
- **Core Engine**: `eventrunner.lua` - Main QuickApp entry point
- **Rule Engine**: `rule.lua` - Core rule processing and execution
- **Compiler**: `compiler.lua` - Compiles EventScript DSL to Lua
- **Parser**: `parser.lua` - Parses EventScript syntax
- **Properties**: `props.lua` - Device property definitions and mappings
- **Utilities**: `utils.lua` - Time handling, logging, and helper functions
- **Built-ins**: `builtins.lua` - Built-in functions for rules
- **Simulation**: `sim.lua` - Testing and simulation support

## Code Style and Conventions

### Lua Standards
- Use 2-space indentation
- Follow standard Lua naming conventions (snake_case for variables, camelCase for functions)
- Use `local` for all local variables
- Prefer explicit returns even when not required

### EventRunner Specific
- Rule syntax uses arrow notation: `"trigger => action"`
- Device references use dot notation: `HT.kitchen.light.roof`
- Time expressions use `@` for daily times: `@10:00`
- Intervals use `@@`: `@@00:05` (every 5 minutes)
- Global variables use `$`: `$myVariable`
- QuickApp variables use `$$`: `$$localVar`
- Custom events use `#`: `#customEvent`

### Function Naming
- Event handlers: `handle*` (e.g., `handleDeviceEvent`)
- Utility functions: descriptive verbs (e.g., `parseTimeExpression`)
- Rule functions: use imperative form (e.g., `turnOn`, `setValue`)

## Key Patterns

### Rule Definition Pattern
```lua
rule("condition => action")
rule("@10:00 & sensor:breached => light:on")
rule("@@00:15 => checkStatus()")
```

### Device Property Access
```lua
-- Reading properties
local isOn = device:isOn
local value = device:value
local lastTrigger = device:last

-- Setting properties  
device:on
device:off
device:setValue(50)
```

### Event Handling
```lua
-- Device events
rule("device:property => action")

-- Time events
rule("@sunrise => action")
rule("10:00..22:00 & condition => action")

-- Custom events
rule("#myEvent => action")
```

### Variable Management
```lua
-- Device mappings in variables table
var.HT = {
  room = {
    device_type = { device_name = deviceId }
  }
}

-- Access devices through variables
rule("HT.room.device_type.device_name:property => action")
```

## Testing Patterns
- Use `sim.lua` for offline testing
- Test files in `tests/` directory follow naming: `test*.lua`
- Use `er.speed()` for accelerated time testing
- Mock devices with `er.loadSimDevice()`

## Error Handling
- Use `pcall` for potentially failing operations
- Log errors with appropriate severity levels
- Provide meaningful error messages with context
- Handle nil values gracefully in rule expressions

## Performance Considerations
- Rules are compiled once and cached
- Use efficient data structures for device lookups
- Minimize string concatenation in hot paths
- Cache frequently accessed device properties

## Documentation Standards
- Document complex rule expressions with inline comments
- Explain non-obvious time calculations
- Document device property mappings
- Include usage examples for new features

## Integration Points
- Fibaro HC3 API for device control
- QuickApp framework for UI and lifecycle
- Lua 5.3 standard library
- Custom event system for inter-rule communication

## Common Tasks
When working with EventRunner6, you'll commonly:
1. Add new device property definitions in `props.lua`
2. Extend rule syntax in `parser.lua` and `compiler.lua`
3. Add built-in functions in `builtins.lua`
4. Create test scenarios in `tests/`
5. Update documentation in `doc/`

## Dependencies and Constraints
- Runs on Fibaro HC3 Lua environment (Lua 5.3)
- Limited to HC3 API capabilities
- Memory constraints typical of embedded systems
- Real-time execution requirements for automation

## File Organization
- Source files in `src/`
- Documentation in `doc/`
- Tests in `tests/`
- Build scripts in `scripts/`
- Distribution files generated in `dist/`

When suggesting code changes or new features, consider the real-time automation context and ensure compatibility with the Fibaro HC3 platform constraints.
