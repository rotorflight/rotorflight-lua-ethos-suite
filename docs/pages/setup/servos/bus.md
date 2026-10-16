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
- The Tool button is disabled until the page has loaded the servo's values. In addition, confirming the override dialog before values are read is prevented as defence in depth.
- The list behind the page has its own Tool button, which switches the override on for all servos at once. It exists only after the status and mixer read has answered; on a failed read the page shows the load error instead and no Tool button.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
