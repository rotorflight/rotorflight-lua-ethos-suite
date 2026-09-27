---
title: Filters
sidebar_label: Filters
sidebar_position: 30
---

# Filters

Setup -> Governor -> Filters page.

## Where to find it

*Configuration* → *Setup* → *Governor* → *Filters*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Headspeed Filter Cutoff | Configures Headspeed Filter Cutoff. Range: 0 to 250 Hz. Default: 20 Hz. |
| Voltage Filter Cutoff | Configures Voltage Filter Cutoff. Range: 0 to 250 Hz. Default: 20 Hz. |
| TTA Bandwidth | Configures TTA Bandwidth. Range: 0 to 250 Hz. Default: 20 Hz. |
| Precomp Bandwidth | Configures Precomp Bandwidth. Range: 0 to 25 Hz. Default: 10 Hz. |
| D-Term Cutoff | Configures D-Term Cutoff. Range: 0 to 250 Hz. Default: 50 Hz. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
