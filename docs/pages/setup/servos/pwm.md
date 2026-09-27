---
title: PWM Output
sidebar_label: PWM Output
sidebar_position: 10
---

# PWM Output

Servos -> PWM Output. Builds the PWM servo list from MSP_STATUS servo_count plus MIXER_CONFIG swash/tail mode, then opens an indexed per-servo config editor.

## Where to find it

*Configuration* → *Setup* → *Servos* → *PWM Output*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Center | Configures Center. |
| Minimum | Configures Minimum. |
| Maximum | Configures Maximum. |
| Scale Negative | Configures Scale Negative. |
| Scale Positive | Configures Scale Positive. |
| Rate | Configures Rate. |
| Speed | Configures Speed. |
| Reverse | Configures Reverse. |
| Geometry | Configures Geometry. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
