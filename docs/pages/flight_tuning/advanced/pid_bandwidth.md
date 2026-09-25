---
title: PID Bandwidth
sidebar_label: PID Bandwidth
sidebar_position: 30
---

# PID Bandwidth

PID Bandwidth profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> PID Bandwidth -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *PID Bandwidth*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Gyro Cutoff (R) | Configures Gyro Cutoff (R). Range: 0 to 250. Default: 50. |
| Gyro Cutoff (P) | Configures Gyro Cutoff (P). Range: 0 to 250. Default: 50. |
| Gyro Cutoff (Y) | Configures Gyro Cutoff (Y). Range: 0 to 250. Default: 100. |
| D-term Cutoff (R) | Configures D-term Cutoff (R). Range: 0 to 250. Default: 15. |
| D-term Cutoff (P) | Configures D-term Cutoff (P). Range: 0 to 250. Default: 15. |
| D-term Cutoff (Y) | Configures D-term Cutoff (Y). Range: 0 to 250. Default: 20. |
| B-term Cutoff (R) | Configures B-term Cutoff (R). Range: 0 to 250. Default: 15. |
| B-term Cutoff (P) | Configures B-term Cutoff (P). Range: 0 to 250. Default: 15. |
| B-term Cutoff (Y) | Configures B-term Cutoff (Y). Range: 0 to 250. Default: 20. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
