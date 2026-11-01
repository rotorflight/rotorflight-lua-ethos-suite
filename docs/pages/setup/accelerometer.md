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
| Roll | Configures Roll trim in tenths of a degree. Range: -300 to 300. Default: 0. |
| Pitch | Configures Pitch trim in tenths of a degree. Range: -300 to 300. Default: 0. |

## Notes

- Trim units are handled by `src/rfsuite/lib/msp_acc_trim.lua` (issue #2650).
- Changes are written to the flight controller EEPROM upon Save.
- Calibrate waits until the flight controller reports that the calibration has
  finished, then saves to the EEPROM and plays the confirmation beep. If it does
  not finish within 15 seconds, the page shows an error and saves nothing.
  If the status bit is never seen set during the calibration, the page saves after
  3 seconds on a clear status reply. This fallback does not confirm that the
  calibration has finished; the 15-second timeout still applies.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
