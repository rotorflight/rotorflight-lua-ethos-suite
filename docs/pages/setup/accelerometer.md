---
title: Accelerometer
sidebar_label: Accelerometer
sidebar_position: 40
---

# Accelerometer

Accelerometer page. Loaded on demand from Setup -> Accelerometer.

## Where to find it

*Configuration* → *Setup* → *Accelerometer*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | Configures Roll. Range: -300 to 300 °. Default: 0 °. |
| Pitch | Configures Pitch. Range: -300 to 300 °. Default: 0 °. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Calibrate waits until the flight controller reports that the calibration has
  finished, then saves to the EEPROM and plays the confirmation beep. If it does
  not finish within 15 seconds, the page shows an error and saves nothing.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
