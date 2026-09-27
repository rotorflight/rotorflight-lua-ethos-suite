---
title: BUS Output
sidebar_label: BUS Output
sidebar_position: 20
---

# BUS Output

Servos -> BUS Output. BUS servos look almost identical to PWM in the UI, but the firmware indexes them differently.

## Where to find it

*Configuration* → *Setup* → *Servos* → *BUS Output*

Greyed out until the flight controller answers. Read-only while the model is armed. Only available when servo bus output is configured.

## Settings

| Setting | What it does |
| --- | --- |
| Center | Configures Center. |
| Minimum | Configures Minimum. |
| Maximum | Configures Maximum. |
| Scale Negative | Configures Scale Negative. |
| Scale Positive | Configures Scale Positive. |
| Speed | Configures Speed. |
| Reverse | Configures Reverse. |
| Geometry | Configures Geometry. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
