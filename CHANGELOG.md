# Changelog

## [v0.0.43] - 2025-09-26

## Changes in v0.0.43

- ♻️ **Refactor**: add optional name property to rule creation
- ♻️ **Refactor**: improve clarity of rule data structure
- ✨ **Feature**: WIP: local changes before rebase
- ✨ **Feature**: add wnum function to computed variables
- ♻️ **Refactor**: clean up GVAR function by removing commented code
- 🧪 **Test**: add initial test file for array functions
- ♻️ **Refactor**: update rule syntax for logging with wnum
- ♻️ **Refactor**: enhance rule string representation
- ♻️ **Refactor**: improve rule index handling
- ♻️ **Refactor**: enhance error handling in executeSetProp function
- ♻️ **Refactor**: update device creation path handling in createDevice function
- ♻️ **Refactor**: update rule execution logic for clarity
- ♻️ **Refactor**: comment out unused rule definitions


*Generated automatically from git commits*

## [v0.0.42] - 2025-09-21

## Changes in v0.0.42

- ♻️ **Refactor**: improve error handling in property resolution
- ♻️ **Refactor**: update loadDevice function path for consistency
- ✨ **Feature**: add Node-RED integration support
- ♻️ **Refactor**: clean up IP address retrieval logic
- ♻️ **Refactor**: simplify Node-RED event handling
- 📚 **Docs**: create release notes for v0.0.41


*Generated automatically from git commits*

## [v0.0.41] - 2025-09-20

## Changes in v0.0.41

- 🐛 **Fix**: correct time calculation in customDefs function
- ♻️ **Refactor**: update rules for better clarity and organization
- 📚 **Docs**: add Node-RED integration section to documentation
- ✨ **Feature**: efactor: clean up custom definitions and related functions
- ✨ **Feature**: update interpreter path in launch configuration
- ♻️ **Refactor**: comment out unused device loading in rules
- ♻️ **Refactor**: simplify rule definitions for NodeRed integration
- ✨ **Feature**: add release notes for v0.0.40


*Generated automatically from git commits*

## [v0.0.40] - 2025-09-16

## Changes in v0.0.40

- ✨ **Feature**: add support for custom event triggers
- 🐛 **Fix**: correct logic for async wait time adjustment
- 🐛 **Fix**: ensure proper handling of debug information in mergeDbg
- 🧪 **Test**: add tests for new event trigger functionality
- ✨ **Feature**: enhance tutorial with basic functionality section
- 📚 **Docs**: add forum post helper for release announcements
- 🐛 **Fix**: update global variable handling in builtins
- 🐛 **Fix**: improve global variable retrieval in compiler
- ♻️ **Refactor**: streamline alarm property checks in props
- 🐛 **Fix**: refine source trigger debug logic in utils
- 🧪 **Test**: add alarm event handling in tests


*Generated automatically from git commits*

## [v0.0.39] - 2025-09-08

## Changes in v0.0.39

- ✨ **Feature**: add release notes for v0.0.38
- 🐛 **Fix**: update skipTrigger logic in rule creation
- 📚 **Docs**: add forum post helper for release announcements


*Generated automatically from git commits*

## [v0.0.38] - 2025-09-08

## Changes in v0.0.38

- 🐛 **Fix**: update skipTrigger logic in rule creation


*Generated automatically from git commits*

## [v0.0.37] - 2025-09-08

## Changes in v0.0.37

- 🐛 **Fix**: update key property handling in getProps


*Generated automatically from git commits*

## [v0.0.36] - 2025-09-08

## Changes in v0.0.36

- 🐛 **Fix**: log message
- 🐛 **Fix**: correct error handling in rule creation
- 🐛 **Fix**: ensure proper trigger handling in r
- ♻️ **Refactor**: clean up commented-out code in tests


*Generated automatically from git commits*

## [v0.0.35] - 2025-09-07

## Changes in v0.0.35

- 🐛 **Fix**: correct rule validation for daily and interval triggers


*Generated automatically from git commits*

## [v0.0.34] - 2025-09-07

## Changes in v0.0.34

- 🐛 **Fix**: improve argument checking in unary operations
- ♻️ **Refactor**: restructure unary operation functions for better error handling


*Generated automatically from git commits*

## [v0.0.33] - 2025-09-07

## Changes in v0.0.33

- 🐛 **Fix**: improve argument checking in unary operations
- ♻️ **Refactor**: restructure unary operation functions for better error handling


*Generated automatically from git commits*

## [v0.0.32] - 2025-09-07

## Changes in v0.0.32

- ✨ **Feature**: add dim light support with customizable curves
- 🐛 **Fix**: improve error handling in eval function
- 🐛 **Fix**: update property access syntax in parser
- ♻️ **Refactor**: enhance rule logging with warning prefix


*Generated automatically from git commits*

## [v0.0.31] - 2025-09-06

## Changes in v0.0.31

- ✨ **Feature**: Refactor and enhance EventRunner 6 functionality
  - Removed outdated release notes for versions 0.0.22 to 0.0.26.
  - Added new features and improvements in the builtins, compiler, parser, props, rule, and tests modules.
  - Introduced a custom Weather property object with various weather-related properties and triggers.
  - Improved error handling for global variables and property resolution.
  - Enhanced logging options for rule events and improved documentation for EventScript.
  - Updated rule handling logic and added support for new syntax in the parser.
  - Added tests for new features and ensured existing functionality remains intact.
- 📚 **Docs**: update ToDo list with completed tasks
- 🐛 **Fix**: id:prop assignment when id is number
- 🐛 **Fix**: add warnings for undefined GV and runtime errors
- 📚 **Docs**: update Recipes.md for clarity and accuracy
- 🐛 **Fix**: correct time format for light scheduling rules
- 🐛 **Fix**: update Earth Hour section title for spelling
- ✨ **Feature**: add restart rule for Daylight Savings Time adjustments
- 🐛 **Fix**: correct comparison operator in light activation rule
- ♻️ **Refactor**: increase loop iterations in stress test


*Generated automatically from git commits*

## [v0.0.30] - 2025-09-05

## Changes in v0.0.30

- 🐛 **Fix**: handle nil values in marshallFrom function
- ♻️ **Refactor**: update variable structure in rules test


*Generated automatically from git commits*

## [v0.0.29] - 2025-09-05

## Changes in v0.0.29

- ✨ **Feature**: add nextDST function for daylight saving time calculation
- ♻️ **Refactor**: improve setTimeout handling for long durations
- 🐛 **Fix**: ensure timers are properly tracked in rule execution


*Generated automatically from git commits*

## [v0.0.28] - 2025-09-04

## Changes in v0.0.28

- ✨ **Feature**: add Earth Hour functionality to automation recipes rules
- ♻️ **Refactor**: improve rule handling logic for variable assignments
- 🐛 **Fix**: correct error message in parser for unexpected statements
- 🐛 **Fix**: speed time log message


*Generated automatically from git commits*

## [v0.0.27] - 2025-09-04

## Changes in v0.0.27

- ✨ **Feature**: add Earth Hour functionality to automation recipes rules
- ♻️ **Refactor**: improve rule handling logic for variable assignments
- 🐛 **Fix**: correct error message in parser for unexpected statements


*Generated automatically from git commits*

## [v0.0.26] - 2025-09-04

## Changes in v0.0.26

- ✨ **Feature**: update home automation recipes and scheduling rules
- 🐛 **Fix**: bug in scheduling of between test fixed
- 📚 **Docs**: add release notes for v0.0.25
- ♻️ **Refactor**: improve rule handling logic in event processing


*Generated automatically from git commits*

## [v0.0.25] - 2025-09-04

## Changes in v0.0.25

- ✨ **Feature**: enhance logging options for rule events
- ♻️ **Refactor**: improve error handling in parser
- 📚 **Docs**: update EventScript documentation with rule lifecycle details


*Generated automatically from git commits*

## [v0.0.24] - 2025-09-04

## Changes in v0.0.24

- ✨ **Feature**: add release notes for v0.0.23
- ♻️ **Refactor**: update event handling in rule creation
- ♻️ **Refactor**: modify test rule parameters for clarity


*Generated automatically from git commits*

## [v0.0.23] - 2025-09-04

## Changes in v0.0.23

- ✨ **Feature**: improve rule logging options and formats for rule events
- ✨ **Feature**: add trigger-variable support in event engine
- ♻️ **Refactor**: update loadLibrary function scope in documentation


*Generated automatically from git commits*

## [v0.0.22] - 2025-09-03

## Changes in v0.0.22

- ♻️ **Refactor**: improve error handling in rule definitions
- ♻️ **Refactor**: update loadLibrary function scope
- ♻️ **Refactor**: enhance block parsing logic
- 🐛 **Fix**: bug in case statement fixed


*Generated automatically from git commits*

## [v0.0.21] - 2025-09-03

## Changes in v0.0.21

- ✨ **Feature**: update add-on setup instructions and examples
- ♻️ **Refactor**: change loadLibrary function to local scope
- ♻️ **Refactor**: improve error handling in rule definitions
- ✨ **Feature**: add synchronous HTTP call functionality
- ✨ **Feature**: implement HC3 API integration
- ♻️ **Refactor**: update HTTP client authorization handling
- 📚 **Docs**: add release notes for v0.0.20


*Generated automatically from git commits*

## [v0.0.20] - 2025-09-03

## Changes in v0.0.20

- ✨ **Feature**: Add addon support and refactor builtins and rules
  - Refactored `builtins.lua` to remove redundant uptime and weather property definitions, now handled by `addons`.
  - Updated `parser.lua` to improve property access handling.
  - Modified `rule.lua` to load rules asynchronously, enhancing startup performance.
- ✨ **Feature**: add add-on documentation for EventRunner 6


*Generated automatically from git commits*

## [v0.0.19] - 2025-09-02

## Changes in v0.0.19

- ✨ **Feature**: add uptime tracking and event formatting
- 🐛 **Fix**: correct assignment error in parser
- ♻️ **Refactor**: improve rule handling and logging
- 🧪 **Test**: add usage examples for QuickApp
- ✨ **Feature**: add commit message guidelines and VS Code settings
- 📚 **Docs**: include examples and formatting rules for conventional commits


*Generated automatically from git commits*

## [v0.0.18] - 2025-09-02

## Changes in v0.0.18

- 🐛 **Fix**: adjusted formatting for error messages in console
- ✨ **Feature**: add HTML forum post generator and release notes for v0.0.17


*Generated automatically from git commits*

## [v0.0.17] - 2025-09-02

## Changes in v0.0.17

- 🐛 **Fix**: correct remote key condition in rule for R7 fix: better error message for array ref with nil table
- ✨ **Feature**: enhance release notes generation and add commit message tagging guidelines


*Generated automatically from git commits*

## [v0.0.16] - 2025-09-02

## Changes in v0.0.16

- ✨ **Feature**: add coercion function for comparison operators fix:  improve error handling in tokenizer feat: key property for centralSceneEvents
- ✨ **Feature**: enhance forum post formatting and add usage instructions


*Generated automatically from git commits*

## [v0.0.15] - 2025-09-02

## Changes in v0.0.15

### Commits since v0.0.14:

- ✨ **Feature**: add forum post generation functionality and update release script

---
*Generated automatically from git commits*

## [v0.0.14] - 2025-09-02

## Changes in v0.0.14

### Commits since v0.0.13:

- ✨ **Feature**: Refactor EventScript documentation and improve built-in logging functionality
  - Updated documentation in Architecture.md to clarify temporal operations syntax.
  - Corrected method calls in EventScript.md to use dot notation for rule methods.
  - Enhanced Tutorial.md with additional best practices for using time guards and rule initialization.
  - Improved logging functionality in builtins.lua to handle color tags and table serialization.
  - Introduced compatibility module in compater5.lua for loading modules with priority.
  - Streamlined variable retrieval functions in compiler.lua for better readability.
  - Modified rule.lua to improve time formatting in daily triggers and rule initialization.
  - Updated tests/rules.lua to include new rule registration and initialization practices.
- ✨ **Feature**: add long time-based condition to 'betw' operation
- ✨ **Feature**: update architecture documentation and add key property to EventScript triggers

---
*Generated automatically from git commits*

## [v0.0.13] - 2025-09-01

## Changes in v0.0.13

### Commits since v0.0.12:

- ✨ **Feature**: add key property to getProps for central scene event handling
- ✨ **Feature**: add module loading functionality with priority sorting

---
*Generated automatically from git commits*

## [v0.0.12] - 2025-09-01

## Changes in v0.0.12

### Commits since v0.0.11:

- ✨ **Feature**: enhance create-release script with GitHub CLI integration and artifact upload functionality

---
*Generated automatically from git commits*

## [v0.0.11] - 2025-09-01

## Changes in v0.0.11

### Commits since v0.0.10:

- ✨ **Feature**: add internal variable handling and enhance property assignment in compiler and props modules

---
*Generated automatically from git commits*

## [v0.0.10] - 2025-09-01

## Changes in v0.0.10

### Commits since v0.0.9:

- ✨ **Feature**: add example rule for roof sensor breach logging in event runner
- ✨ **Feature**: enhance error handling and messaging in updater and parser modules

---
*Generated automatically from git commits*

## [v0.0.9] - 2025-09-01

## Changes in v0.0.9

### Commits since v0.0.8:

- ✨ **Feature**: add debug scripts for commit parsing and enhance release note generation
- 🐛 **Fix**: remove local keyword in commit parsing loop
  - Fixes variable scope issue that was causing improper indentation
  - Ensures all commit body lines are processed consistently

---
*Generated automatically from git commits*

## [v0.0.8] - 2025-09-01

## Changes in v0.0.8

### Commits since v0.0.7:

- ✨ **Feature**: enhance release script with preview functionality and improved commit message formatting
- ✨ **Feature**: Enhance EventRunner6 with debug information and update view
  - Added an updateView call in EventRunner6 to display the EventRunner instance details.
  - Adjusted the save path in the updater.lua file to ensure it is saved in the 'dist' directory.


---
*Generated automatically from git commits*

## [v0.0.7] - 2025-09-01

## Changes in v0.0.7

### Commits since v0.0.6:

- 🐛 **Fix**: add period to installation success message in updater fix: testing release messages
- ✨ **Feature**: Add custom weather object and enhance fibaro.call tracking

---
*Generated automatically from git commits*

## [v0.0.6] - 2025-09-01

## Changes in v0.0.6

### Commits since v0.0.5:

- 🐛 **Fix**: improve commit message parsing in create-release script
- ✨ **Feature**: Update header file paths and modify rule registrations in tests

---
*Generated automatically from git commits*

## [v0.0.5] - 2025-08-31

## Changes in v0.0.5

### Commits since v0.0.4:

- 🐛 **Fix**: correct value retrieval in PROGN function and update rules for weather triggers
- ✨ **Feature**: Add Weather property class and integrate weather API
- ✨ **Feature**: update Recipes documentation with new sections and improve structure

---
*Generated automatically from git commits*

## [v0.0.4] - 2025-08-30

## Changes in v0.0.4

### Commits since v0.0.3:

- ✨ **Feature**: delete old svg
- ✨ **Feature**: enhance event handling with new date formatting functions and improve utility functions
- ✨ **Feature**: enhance alarm functions and improve event handling in various modules
- ✨ **Feature**: Enhance EventRunner and Compiler functionality

---
*Generated automatically from git commits*

## [v0.0.3] - 2025-08-29

## Changes in v0.0.3

### Commits since v0.0.2:

- ✨ **Feature**: add nil coalescing operator and enhance function handling in various modules
- ♻️ **Refactor**: improve timeout handling and add new case statement support

---
*Generated automatically from git commits*

