# EventRunner Architecture

## Overview
EventRunner is a rule-based home automation engine that executes expressions and rules coded in [EventScript](#eventscript-language-specification)—a domain-specific language designed for home automation. EventScript allows users to define schedules, triggers, delays, and device function invocations in an intuitive, declarative manner.

EventRunner is developed in VSCode using [Plua](https://forum.fibaro.com/topic/79105-plua-quickapp-development/), a Lua interpreter with built-in support for QuickApp emulation.

## Core Components

### 1. EventScript Language
EventScript is a domain-specific language for home automation that extends Lua syntax with automation-specific constructs:
- **Rules**: `<trigger> => <actions>` - declarative automation rules
- **Schedules**: `@sunset`, `@daily` - time-based triggers  
- **Device Functions**: `lamp:on`, `sensor:value` - device interaction
- **Temporal Operations**: `wait()`, `trueFor()`, between `<time1>..<time2>` - time-aware logic

### 2. Rule Engine
The rule engine is event-driven and uses selective triggering rather than polling: 
- **Event Listeners**: Only rules that can be affected by an event are evaluated
- **Lazy Evaluation**: Rules don't consume CPU when not triggered
- **Scalable**: Supports virtually unlimited rules without performance degradation

### 3. Compiler & Runtime
- **Parser**: Converts EventScript to Abstract Syntax Tree (AST)
- **Compiler**: Transforms AST to executable Lua using Continuation Passing Style (CPS)
- **Runtime**: Manages rule execution, timers, and event dispatch

## EventScript Language Specification

### BNF Grammar

```bnf
// Top-level structure
chunk        ::= block
block        ::= {stat} [retstat]

// Statements
stat         ::= ';' 
               | varlist '=' exprlist 
               | functioncall 
               | label                                              // NOT IMPLEMENTED
               | break 
               | goto Name                                          // NOT IMPLEMENTED
               | do block end 
               | while exp do block end 
               | repeat block until exp 
               | if exp then block {elseif exp then block} [else block] end 
               | for Name '=' exp ',' exp [',' exp] do block end 
               | for namelist in exprlist do block end 
               | function funcname funcbody 
               | local function Name funcbody 
               | local namelist ['=' exprlist]

retstat      ::= return [exprlist] [';']

// Labels and function names
label        ::= '::' Name '::'
funcname     ::= Name {'.' Name} [':' Name]

// Variable and name lists
varlist      ::= var {',' var}
var          ::= Name 
               | prefixexp '[' exp ']' 
               | prefixexp '.' Name
namelist     ::= Name {',' Name}
exprlist     ::= exp {',' exp}

// Expressions
exp          ::= nil | false | true | Numeral | LiteralString | '...' 
               | functiondef 
               | prefixexp 
               | tableconstructor 
               | exp binop exp 
               | unop exp

prefixexp    ::= var | functioncall | '(' exp ')'

// Function calls and definitions
functioncall ::= prefixexp args 
               | prefixexp ':' Name args

args         ::= '(' [exprlist] ')' 
               | tableconstructor 
               | LiteralString

functiondef  ::= function funcbody
funcbody     ::= '(' [parlist] ')' block end
parlist      ::= namelist [',' '...'] | '...'

// Table constructor
tableconstructor ::= '{' [fieldlist] '}'
fieldlist        ::= field {fieldsep field} [fieldsep]
field            ::= '[' exp ']' '=' exp 
                   | Name '=' exp 
                   | exp
fieldsep         ::= ',' | ';'

// Operators
binop        ::= '+' | '-' | '*' | '/' | '//' | '^' | '%' 
               | '&' | '~' | '|' | '>>' | '<<' | '..' 
               | '<' | '<=' | '>' | '>=' | '==' | '~=' 
               | '??' | and | or

unop         ::= '-' | not | '#' | '~'
```

### Rule Syntax
Rules follow the pattern: `<trigger> => <actions>`

Examples:
```eventscript
78:isOn => lamp:on                           -- Simple device trigger
@sunset => lamp:on; wait(01:00); lamp:off   -- Time-based with delay
trueFor(00:05,sensor:safe) => lamp:off       -- Temporal condition
```

## Execution Model

### 1. Event-Driven Architecture

The function `eval(str)` takes a string in EventScript notation and compiles and runs it.
If the string contains '=>' it is considered a rule, and is compiled and stored as a rule.

Rules look like:
```
<trigger expression> => <actions>
```

The compiler scans the trigger expression for all functions that can change value due to some system event.
Example:
```eventscript
78:isOn => <action>
```

This checks if device 78 is on. This rule needs to trigger whenever 78's value changes so we can check if the rule's actions should run.

The result of the scan is that we set up an event listener that listens for all events in the trigger expression and then starts the rule:

```lua
addEventListener({
    {type='device', id = 78, property='value'}, -- event/sourceTrigger
    ... -- other events
}, 
function(event) rule:start(event) end) -- Handler, starting the rule when event triggers
```

This way we only test rules that may trigger and we don't need to constantly loop over all rules to see what should run.
It also means that we can in principle support an infinite number of rules, as they don't consume CPU if they don't run.

### 2. Continuation Passing Style (CPS)

We compile EventScript to Lua functions using 'Continuation Passing Style' (CPS).
This means that all functions are passed an extra argument, a continuation that tells what the function should do after it has done its work.

```lua
function ADD(arg1, arg2, cont)
   arg1(function(res1) 
      arg2(function(res2) 
         cont(res1 + res2)
      end)
   end)
end
```

The reason for this is that we need to be able to 'pause' EventScript expressions and let other rules run.

Examples:
```eventscript
rule("@sunset => lamp:on; wait(01:00); lamp:off") -- pause an hour and turn off the light
rule("trueFor(00:05,sensor:safe) => lamp:off") -- turn off lamp when sensor safe for 5min
```

To be able to do that, we can just do a `setTimeout(cont, ...)`:

```lua
function WAIT(time, cont) 
   setTimeout(function() cont(true) end, time * 1000) 
end -- Continue after time seconds
```

All timers started by a rule are kept track of so if we do a `rule:disable()` all timers are cancelled.

### 3. Scheduling System

`@daily` rules register their time for the day in a global scheduler that calls the rule when time is up.
Every midnight, the daily times are recalculated and `setTimeout`s started for the upcoming day for each rule. If a daily rule depend on a variable that can change, like
```lua
rule("@$GlobalTime => ...")
```
the rule is also triggered to recalculate the time when the variable change. Not that this only works for fibaro global variables and triggerVars, that emit events when they change value.

## System Architecture

### Core Modules

#### 1. Parser (`parser.lua`)
- **Responsibility**: Lexical analysis and parsing of EventScript
- **Input**: EventScript source code strings
- **Output**: Abstract Syntax Tree (AST)
- **Key Features**:
  - Token recognition for EventScript keywords and operators
  - Syntax validation and error reporting
  - Support for both expressions and rule declarations

#### 2. Compiler (`compiler.lua`)
- **Responsibility**: AST to executable Lua transformation
- **Input**: AST from parser
- **Output**: Compiled Lua functions with CPS
- **Key Features**:
  - Continuation Passing Style (CPS) transformation
  - Event dependency analysis for trigger expressions
  - Code optimization for performance

#### 3. Rule Engine (`rule.lua`)
- **Responsibility**: Rule lifecycle management
- **Key Features**:
  - Rule registration and storage
  - Event listener management
  - Rule execution scheduling
  - Timer and resource cleanup
  - Rule enable/disable functionality

#### 4. Main QA - rule entry (`eventrunner.lua`)
- **Responsibility**: Core QA environment
- **Key Features**:
  - Defines rule in ` main` 

#### 5. Utilities (`utils.lua`)
- **Responsibility**: Supporting functions and helpers
- **Key Features**:
  - Time and date manipulation
  - String processing utilities
  - Debugging and profiling tools
  - Configuration management

#### 6. Built-ins (`builtins.lua`)
- **Responsibility**: Standard library functions
- **Key Features**:
  - Time functions (`@sunset`, `@sunrise`, `between()`)
  - Device functions (`device:on`, `device:value`)
  - Temporal functions (`wait()`, `trueFor()`, `since()`)
  - Logic and math operations

### Data Flow

```
EventScript Source
       ↓
   Parser (AST)
       ↓
  Compiler (CPS Lua)
       ↓
   Rule Engine
       ↓
  Runtime Engine
       ↓
   Device Actions
```

## Event System

### Event Types
1. **Device Events**: Property changes on devices
2. **Time Events**: Scheduled or calculated time points
3. **User Events**: Manual triggers and custom events
4. **System Events**: Startup, shutdown, error conditions

### Event Processing Pipeline
1. **Event Source**: Device, timer, or user action generates event
2. **Event Dispatch**: Core engine routes event to interested rules
3. **Rule Evaluation**: CPS-compiled rule code executes
4. **Action Execution**: Device commands or further events triggered

### Event Listener Registration
```lua
addEventListener({
    {type='device', id=78, property='value'},
    {type='time', pattern='@sunset'},
    {type='custom', name='security_mode_change'}
}, function(event) 
    rule:start(event) 
end)
```

## Continuation Passing Style (CPS)

### Why CPS?
EventRunner uses CPS to enable:
- **Non-blocking execution**: Rules can pause without blocking others
- **Timer integration**: `wait()` functions integrate seamlessly
- **Resource management**: Automatic cleanup when rules are cancelled
- **Composition**: Complex temporal logic can be built from simple parts

### CPS Transformation Example
```eventscript
-- Original EventScript
lamp:on; wait(01:00); lamp:off

-- Compiled CPS Lua
function(cont)
    DEVICE_ON(lamp, function()
        WAIT(3600, function()
            DEVICE_OFF(lamp, cont)
        end)
    end)
end
```

### Timer Management
- Each rule maintains a list of active timers
- `rule:disable()` cancels all timers for that rule
- Prevents resource leaks and unwanted delayed actions
- Supports rule modification without timer conflicts

## Scheduling System

### Time-based Rules
EventRunner supports multiple time-based trigger types:

#### 1. Absolute Times
```eventscript
@06:30 => lamp:on                    -- Daily at 6:30 AM
@sunset => lamp:on                   -- At calculated sunset
@sunrise+01:00 => lamp:off           -- 1 hour after sunrise
```

#### 2. Periodic Schedules
```eventscript
@daily => backup:run                 -- Every day at midnight
@monthly => report:generate          -- Every month
```

#### 3. Conditional Time Windows
```eventscript
motion:detected & sunset..sunrise => light:on
```

### Scheduler Implementation
- **Daily Recalculation**: Times recalculated every midnight
- **Timezone Awareness**: Handles DST and timezone changes
- **Astronomical Calculations**: Sunset/sunrise computed for location
- **Efficient Timers**: Only active for upcoming day to minimize memory

## Device Integration

### Device Interface
EventRunner provides a unified interface for device interaction:

```eventscript
-- Property access
device:value                         -- Get current value
device:isOn                         -- Boolean state check
device:lastChanged                  -- Timestamp of last change

-- Actions
device:on                           -- Turn device on
device:off                          -- Turn device off
device:toggle                       -- Toggle state
device:setValue(value)              -- Set specific value
```

### Device Event Generation
- Property changes automatically generate events
- Events include old value, new value, and timestamp
- Only rules with relevant triggers are notified
- Supports both push and pull device models

## Memory and Performance

### Scalability Design
- **Lazy Evaluation**: Rules only run when triggered
- **Event Filtering**: Only relevant rules receive events
- **Memory Efficiency**: Compiled functions reused across rule instances
- **Timer Optimization**: Consolidated timer management

### Resource Management
- **Automatic Cleanup**: Disabled rules release all resources
- **Memory Monitoring**: Built-in profiling for resource usage
- **Garbage Collection**: Lua GC optimized for rule patterns
- **Error Isolation**: Rule failures don't affect other rules

## Error Handling

### Error Types
1. **Parse Errors**: Syntax errors in EventScript
2. **Compile Errors**: Invalid rule structure or references
3. **Runtime Errors**: Device communication failures, timeout errors
4. **Resource Errors**: Memory exhaustion, timer conflicts

### Error Recovery
- **Rule Isolation**: Errors in one rule don't affect others
- **Graceful Degradation**: System continues with failed rules disabled
- **Error Logging**: Comprehensive logging for debugging
- **User Feedback**: Clear error messages for rule authors

### Debugging Support
- **Rule Tracing**: Execution path logging for complex rules
- **Variable Inspection**: Runtime state examination
- **Performance Profiling**: Execution time and resource usage
- **Interactive Testing**: Live rule evaluation and testing

## Configuration and Deployment

### Configuration Management
- **Rule Storage**: Persistent storage of compiled rules
- **Device Configuration**: Device mapping and capabilities
- **System Settings**: Timezone, location, logging levels
- **User Preferences**: Custom functions and variables

### Hot Reload
- **Dynamic Updates**: Rules can be modified without system restart
- **Safe Transitions**: Existing rule timers handled during updates
- **Validation**: New rules validated before activation
- **Rollback**: Failed updates can be reverted automatically

## Future Considerations

### Planned Enhancements
1. **Distributed Rules**: Multi-controller rule coordination
2. **Machine Learning**: Predictive rule suggestions
3. **Visual Editor**: Graphical rule creation interface
4. **Rule Templates**: Reusable rule patterns
5. **External Integrations**: Cloud services and third-party APIs

### Extensibility Points
- **Custom Functions**: User-defined EventScript functions
- **Device Drivers**: Plugin architecture for new device types
- **Event Sources**: External event integration
- **Action Handlers**: Custom action implementations