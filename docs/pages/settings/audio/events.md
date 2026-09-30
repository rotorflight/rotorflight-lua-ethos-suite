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

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
