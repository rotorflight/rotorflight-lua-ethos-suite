---
title: Autolevel
sidebar_label: Autolevel
sidebar_position: 40
---

# Autolevel

Autolevel profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Autolevel -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Autolevel*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Horizon Mode | Configures Horizon Mode. Range: 0 to 200. Default: 40. |
| Acro Trainer (Gain) | Configures Acro Trainer (Gain). Range: 25 to 255. Default: 75. |
| Acro Trainer (Max) | Configures Acro Trainer (Max). Range: 10 to 80 °. Default: 20 °. |
| Angle Mode (Gain) | Configures Angle Mode (Gain). Range: 0 to 200. Default: 40. |
| Angle Mode (Max) | Configures Angle Mode (Max). Range: 10 to 90 °. Default: 55 °. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
