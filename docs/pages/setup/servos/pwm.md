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
- The list shows only the PWM outputs. When a SBUS or FBUS port is configured, the bus channels are not listed here; they are on the Bus page.
- The Tool button's servo override is switched on only after the page has read the servo's values. Until then, confirming the override dialog does nothing.
- The list behind the page has its own Tool button, which switches the override on for all servos at once. It exists only after the status and mixer read has answered; on a failed read the page shows the load error instead and no Tool button.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
