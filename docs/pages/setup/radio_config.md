---
title: Radio Config
sidebar_label: Radio Config
sidebar_position: 20
---

# Radio Config

Radio Config page. Loaded on demand from Setup -> Radio Config.

## Where to find it

*Configuration* → *Setup* → *Radio Config*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Stick (Deflection) | Configures Stick (Deflection). Range: 200 to 700 us. Default: 510 us. |
| Stick (Center) | Configures Stick (Center). Range: 1400 to 1600 us. Default: 1500 us. |
| Throttle (Max) | Configures Throttle (Max). Range: 1510 to 2150 us. Default: 1900 us. |
| Throttle (Min) | Configures Throttle (Min). Range: 860 to 1500 us. Default: 1100 us. |
| Deadband (Yaw) | Configures Deadband (Yaw). Range: 0 to 100 us. Default: 2 us. |
| Deadband (Cyclic) | Configures Deadband (Cyclic). Range: 0 to 100 us. Default: 2 us. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
