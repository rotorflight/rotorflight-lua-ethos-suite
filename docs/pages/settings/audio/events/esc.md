---
title: ESC temp
sidebar_label: ESC temp
sidebar_position: 20
---

# ESC temp

Whether an over-temperature ESC is called out, and the temperature that counts as too hot.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *ESC temp*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *ESC temp* | Calls out when an ESC reports a temperature at or above the threshold. |
| *ESC threshold* | The temperature that counts as too hot. Range 60 to 300 degrees Celsius, default 90. Greyed out while the alert above it is off. |

## Notes

- Off by default. The alert needs ESC temp telemetry from the flight controller; with
  nothing reporting, there is nothing to compare against the threshold.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*