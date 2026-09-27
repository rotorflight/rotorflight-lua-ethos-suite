---
title: Ramp Time
sidebar_label: Ramp Time
sidebar_position: 20
---

# Ramp Time

Setup -> Governor -> Ramp Time page.

## Where to find it

*Configuration* → *Setup* → *Governor* → *Ramp Time*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Startup time | Configures Startup time. Range: 0 to 600. Default: 200. |
| Spoolup time | Configures Spoolup time. Range: 0 to 600 s. Default: 100 s. |
| Spooldown time | Configures Spooldown time. Range: 0 to 600 s. Default: 100 s. |
| Tracking time | Configures Tracking time. Range: 0 to 100 s. Default: 10 s. |
| Recovery time | Configures Recovery time. Range: 0 to 100 s. Default: 21 s. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
