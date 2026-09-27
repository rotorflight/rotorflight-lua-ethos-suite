---
title: Main Rotor
sidebar_label: Main Rotor
sidebar_position: 50
---

# Main Rotor

Main Rotor profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Main Rotor -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Main Rotor*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Collective Pitch Comp | Configures Collective Pitch Comp. Range: 0 to 250. Default: 0. |
| Cyclic Cross Coupling: Gain | Configures Cyclic Cross Coupling: Gain. Range: 0 to 250. Default: 50. |
| Cyclic Cross Coupling: Ratio | Configures Cyclic Cross Coupling: Ratio. Range: 0 to 200 %. Default: 0 %. |
| Cyclic Cross Coupling: Cutoff | Configures Cyclic Cross Coupling: Cutoff. Range: 1 to 250 Hz. Default: 25 Hz. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
