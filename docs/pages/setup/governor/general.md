---
title: General
sidebar_label: General
sidebar_position: 10
---

# General

Setup -> Governor -> General page.

## Where to find it

*Configuration* → *Setup* → *Governor* → *General*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Mode | Configures Mode. |
| Throttle type | Configures Throttle type. |
| Idle throttle | Configures Idle throttle. Range: 0 to 250 %. Default: 0 %. |
| Auto throttle | Configures Auto throttle. Range: 0 to 250 %. Default: 0 %. |
| Handover throttle% | Configures Handover throttle%. Range: 0 to 50 %. Default: 20 %. |
| Throttle hold timeout | Configures Throttle hold timeout. Range: 0 to 250 s. Default: 5 s. |
| Autorotation Timeout | Configures Autorotation Timeout. Range: 0 to 250 s. Default: 0 s. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
