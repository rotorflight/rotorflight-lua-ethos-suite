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
| Startup time | Configures Startup time. Range: 0 to 60 s. Default: 20 s. |
| Spoolup time | Configures Spoolup time. Range: 0 to 60 s. Default: 10 s. |
| Spooldown time | Configures Spooldown time. Range: 0 to 60 s. Default: 10 s. |
| Tracking time | Configures Tracking time. Range: 0 to 60 s. Default: 5 s. |
| Recovery time | Configures Recovery time. Range: 0 to 60 s. Default: 3 s. |

## Notes

- Written to the flight controller EEPROM on Save; Rotorflight 2 applies governor settings immediately, so the save does not restart the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
