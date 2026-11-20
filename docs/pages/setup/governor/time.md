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

- Written to the flight controller EEPROM on Save. The flight controller takes these settings into the running governor only at start-up, so a save that changes one of them restarts the flight controller; without the restart the new value would be stored but not flown until the next power-up (#2780). A save that changes nothing does not restart. The restart is skipped while the model is armed.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
