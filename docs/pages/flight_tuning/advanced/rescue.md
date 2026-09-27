---
title: Rescue
sidebar_label: Rescue
sidebar_position: 70
---

# Rescue

Rescue profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Rescue -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Rescue*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Rescue Mode Enable | Configures Rescue Mode Enable. |
| Flip to Upright | Configures Flip to Upright. |
| Hover | Configures Hover. Range: 0 to 1000 %. Default: 350 %. |
| Rate | Configures Rate. Range: 5 to 1000 °/s. Default: 300 °/s. |
| Accel | Configures Accel. Range: 0 to 10000 °/s². Default: 3000 °/s². |
| Pull-up (Collective) | Configures Pull-up (Collective). Range: 0 to 1000 %. Default: 650 %. |
| Pull-up (Time) | Configures Pull-up (Time). Range: 0 to 250 s. Default: 3 s. |
| Climb (Collective) | Configures Climb (Collective). Range: 0 to 1000 %. Default: 450 %. |
| Climb (Time) | Configures Climb (Time). Range: 0 to 250 s. Default: 10 s. |
| Flip (Fail Time) | Configures Flip (Fail Time). Range: 0 to 250 s. Default: 20 s. |
| Flip (Exit Time) | Configures Flip (Exit Time). Range: 0 to 250 s. Default: 5 s. |
| Gains (Level) | Configures Gains (Level). Range: 5 to 250. Default: 100. |
| Gains (Flip) | Configures Gains (Flip). Range: 5 to 250. Default: 200. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
