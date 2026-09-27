---
title: RPM
sidebar_label: RPM
sidebar_position: 30
---

# RPM

Setup -> ESC & Motors -> RPM page.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *RPM*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| RPM Sensor | Configures RPM Sensor. |
| DShot RPM Telemetry | Configures DShot RPM Telemetry. |
| Motor Pole Count | Configures Motor Pole Count. Range: 2 to 256. Default: 10. |
| Main Motor Ratio (Pinion) | Configures Main Motor Ratio (Pinion). Range: 1 to 50000. Default: 1. |
| Main Motor Ratio (Main) | Configures Main Motor Ratio (Main). Range: 1 to 50000. Default: 1. |
| Tail Motor Ratio (Rear) | Configures Tail Motor Ratio (Rear). Range: 1 to 50000. Default: 1. |
| Tail Motor Ratio (Front) | Configures Tail Motor Ratio (Front). Range: 1 to 50000. Default: 1. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
