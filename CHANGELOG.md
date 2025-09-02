# Changelog

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

