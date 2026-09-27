---
title: General
sidebar_label: General
sidebar_position: 10
---

# General

Governor "General" profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Governor -> General -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Governor* → *General*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Full Headspeed | Configures Full Headspeed. Range: 0 to 50000 rpm. Default: 1000 rpm. |
| Min Throttle | Configures Min Throttle. Range: 0 to 100 %. Default: 10 %. |
| Max Throttle | Configures Max Throttle. Range: 0 to 100 %. Default: 100 %. |
| Fallback Drop | Configures Fallback Drop. Range: 0 to 50 %. Default: 10 %. |
| Gain | Configures Gain. Range: 0 to 250. Default: 40. |
| Gains (P) | Configures Gains (P). Range: 0 to 250. Default: 40. |
| Gains (I) | Configures Gains (I). Range: 0 to 250. Default: 50. |
| Gains (D) | Configures Gains (D). Range: 0 to 250. Default: 0. |
| Gains (F) | Configures Gains (F). Range: 0 to 250. Default: 10. |
| Precomp (Yaw) | Configures Precomp (Yaw). Range: 0 to 250. Default: 0. |
| Precomp (Cyc) | Configures Precomp (Cyc). Range: 0 to 250. Default: 10. |
| Precomp (Col) | Configures Precomp (Col). Range: 0 to 250. Default: 100. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
