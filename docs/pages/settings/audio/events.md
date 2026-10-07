---
title: Events
sidebar_label: Events
sidebar_position: 10
---

# Events

Settings -> Audio -> Events.

## Where to find it

*System* → *Settings* → *Audio* → *Events*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- **The fuel events wait for one reading before they speak.** Every event on this page
  looks at the value it watches, and the first value it sees after connecting is only
  recorded — no announcement is made from it. So a flight controller whose telemetry has
  not arrived yet cannot make the tool announce anything: a fuel reading that is still
  its unset `0` is not read as an empty battery.
- **A genuinely empty pack is still announced**, from the second reading onwards — one
  step later than before, not silenced. The same applies after a reconnect or a battery
  change: the first reading is recorded again, and the warning follows if the value is
  still `0`.
- A **threshold** announcement (*fuel.wav* plus the percentage) is unchanged: it is made
  when the reading crosses a step of the callout range, once per step, and a standing
  value does not repeat it.
- **Battery profile** announces the newly selected pack as "Battery, 2200 milliamp
  hours, 4 cells". The cell count is left out when the profile has none set.
- **FC status** callouts need the flight controller's *System Status* or *System Config*
  telemetry sensor (firmware with MSP API 12.10 or newer, selected under *Setup* →
  *Telemetry*). Blackbox full comes from *System Config*, the others from *System
  Status*; without the sensor a switch needs, it has no effect.

  | Switch | Says | Default |
  | --- | --- | --- |
  | Gyro overflow | "Gyro overflow" when the gyro overflows. | On |
  | GPS not responding | "GPS not responding" when a GPS that was talking to the flight controller earlier on this connection stops, held for 1 second. | On |
  | Blackbox full | "Blackbox full" when the blackbox storage fills up. *System Config* must be selected. | On |
  | Control limit | "Control limit" while the cyclic, yaw or collective hits its mixer limit, at most every 3 seconds. | Off, it can be chatty in 3D flight |

  A condition that is already present when the model connects is not announced; the
  dashboard's status banner shows it instead. Each one is announced again only after it
  has cleared and come back. They are spoken whether or not the model is armed.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
