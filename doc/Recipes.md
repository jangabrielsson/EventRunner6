# Home Automation Recipes

## Table of Contents

- [Light Triggering](#light-triggering)
  - [Turn on lights when motion is detected between sunset and sunrise](#turn-on-lights-when-motion-is-detected-between-sunset-and-sunrise)
  - [Turn on lights when motion is detected and fibaro global variable 'Vacation' is not true](#turn-on-lights-when-motion-is-detected-and-fibaro-global-variable-vacation-is-not-true)
- [Light Scheduling](#light-scheduling)
  - [Turn off all lights at midnight](#turn-off-all-lights-at-midnight)
  - [Turn off all lights at 11 on weekdays and midnight on weekends](#turn-off-all-lights-at-11-on-weekdays-and-midnight-on-weekends)
- [Security routines](#security-routines)
  - [Arm security system at night](#arm-security-system-at-night)
  - [Disarm security system in the morning](#disarm-security-system-in-the-morning)
- [Climate control](#climate-control)
  - [Turn on fan if temperature is high](#turn-on-fan-if-temperature-is-high)
  - [Turn on fan if temperature is high for more than 5 min, and off when low for 5min](#turn-on-fan-if-temperature-is-high-for-more-than-5-min-and-off-when-low-for-5min)
- [Notification examples](#notification-examples)
  - [Send notification if door is left open for more than 5 minutes](#send-notification-if-door-is-left-open-for-more-than-5-minutes)
  - [Notification on last Monday in week](#notification-on-last-monday-in-week)

## Light triggering

Turn on lights when motion is detected between sunset and sunrise:

```lua
rule([[motion:breached & sunset..sunrise =>
  hallwayLight:on;
  log('Hallway light turned on due to motion')
]])
```

Turn on lights when motion is detected and fibaro global variable 'Vacation' is not true :

```lua
rule([[motion:breached & !Vacation =>
  hallwayLight:on;
  log('Hallway light turned on due to motion')
]])
```

## Light scheduling

Turn off all lights at midnight:

```lua
rule([[@00:00 =>
  allLights:off;
  log('All lights turned off at midnight')
]])
```

Turn off all lights at 11 on weekdays and midnight on weekends
```lua
rule([[11:00 & wday('mon-thu') =>
  allLights:off;
  log('All lights turned off at 11:00')
]])
rule([[@00:00 & wday('fri-sun') =>
  allLights:off;
  log('All lights turned off at midnight')
]])
```

## Security routines

Arm security system at night, disarm in the morning:

```lua
rule([[@23:00 =>
  securitySystem:arm;
  log('Security system armed for the night')
]])

rule([[@06:00 =>
  securitySystem:disarm;
  log('Security system disarmed for the day')
]])
```

## Climate control

Turn on fan if temperature is high:

```lua
rule([[temp:value > 28 =>
  fan:on;
  log('Fan turned on due to high temperature')
]])

Turn on fan if temperature is high for more than 5 min, and off when low for 5min

```lua
rule([[trueFor(00:05,temp:value > 28) =>
  fan:on;
  log('Fan turned on due to high temperature')
]])

rule([[trueFor(00:05,temp:value < 20) =>
  fan:on;
  log('Fan turned off due to low temperature')
]])
```

## Notification examples

Send notification if door is left open for more than 5 minutes:

```lua
rule("user = 456") -- Id of user that should be pushed to
rule([[trueFor(00:05,door:open) =>
  user:msg = log('Door open for %s minutes',5*again(10))
]])

Notification on last Monday in week

```lua
rule([[@18:00 & day('lastw-last') & wday('mon') =>
  user:msg = log('Last Monday in week, put out the trash')
]])


```
