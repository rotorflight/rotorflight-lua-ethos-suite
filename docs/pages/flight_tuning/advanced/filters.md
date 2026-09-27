---
title: Filters
sidebar_label: Filters
sidebar_position: 10
---

# Filters

Filters profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Filters -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Filters*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| LPF1 Type | Configures LPF1 Type. |
| LPF1 Cutoff | Configures LPF1 Cutoff. Range: 0 to 4000 hz. Default: 100 hz. |
| LPF2 Type | Configures LPF2 Type. |
| LPF2 Cutoff | Configures LPF2 Cutoff. Range: 0 to 4000 hz. Default: 0 hz. |
| RPM Preset | Configures RPM Preset. |
| RPM Min Hz | Configures RPM Min Hz. Range: 1 to 100 hz. Default: 0 hz. |
| LPF1 Dynamic (Min) | Configures LPF1 Dynamic (Min). Range: 0 to 1000 hz. Default: 0 hz. |
| LPF1 Dynamic (Max) | Configures LPF1 Dynamic (Max). Range: 0 to 1000 hz. Default: 0 hz. |
| Notch 1 (Center) | Configures Notch 1 (Center). Range: 0 to 4000 hz. Default: 0 hz. |
| Notch 1 (Cutoff) | Configures Notch 1 (Cutoff). Range: 0 to 4000 hz. Default: 0 hz. |
| Notch 2 (Center) | Configures Notch 2 (Center). Range: 0 to 4000 hz. Default: 0 hz. |
| Notch 2 (Cutoff) | Configures Notch 2 (Cutoff). Range: 0 to 4000 hz. Default: 0 hz. |
| Dyn Notch (Count) | Configures Dyn Notch (Count). Range: 0 to 8. Default: 0. |
| Dyn Notch (Q) | Configures Dyn Notch (Q). Range: 0 to 100. Default: 0. |
| Dyn Notch Range (Min) | Configures Dyn Notch Range (Min). Range: 10 to 200 hz. Default: 0 hz. |
| Dyn Notch Range (Max) | Configures Dyn Notch Range (Max). Range: 100 to 500 hz. Default: 0 hz. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
