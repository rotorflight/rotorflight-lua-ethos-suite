---
title: SRXL2 ESC
sidebar_label: SRXL2 ESC
sidebar_position: 40
---

# SRXL2 ESC

Sets how the flight controller talks to Spektrum Smart ESCs on an SRXL2 ESC bus: how often it polls them for
telemetry, and which SRXL2 channel drives the second motor of a dual-motor ESC.

Page `app/pages/esc_motors_srxl2.lua`, codec `lib/msp_srxl2_esc_config.lua` (MSP2_GET_SRXL2_ESC_CONFIG /
MSP2_SET_SRXL2_ESC_CONFIG, rotorflight-firmware PR #537), PR #2680.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *SRXL2 ESC*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight
controller reports this ESC telemetry protocol (Protocol ID: 14). The firmware sets that protocol itself whenever a
serial port is assigned the SRXL2 ESC function, so the tile lights after that port is configured and the flight
controller has rebooted.

## Settings

| Setting | What it does |
| --- | --- |
| Telemetry Interval | How many SRXL2 frames pass between telemetry polls of the ESC; 0 turns polling off. Range: 0 to 255 frames. Default: 7. |
| Motor 2 Channel | The SRXL2 channel that carries motor 2 on a dual-motor Smart ESC (for example the Spektrum SPMXAE1020). *Off* for a single-motor ESC; otherwise channel 2 to 32 (channel 1 is always motor 1). Default: Off. |

## Notes

- Saving writes the settings to the flight controller EEPROM and then **reboots the flight controller**: the
  firmware reads them only at boot, and latches the motor 2 channel there.
- The throttle rate is not shown. The firmware derives it from the motor PWM rate; the page writes back the value it
  read unchanged.
- Firmware without MSP2_GET_SRXL2_ESC_CONFIG refuses the read, and the page shows a failed load. A reply of another
  payload version or length is refused the same way, rather than decoded and written back on the next save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
