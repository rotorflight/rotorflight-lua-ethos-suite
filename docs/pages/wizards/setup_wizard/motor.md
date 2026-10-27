---
title: Motor & ESC
sidebar_label: Motor & ESC
sidebar_position: 60
---

# Motor & ESC

Step 7 of the Model setup wizard. It sets the ESC protocol, the motor poles and the gear
ratios.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 7 *Motor & ESC*. The protocol screen comes
first, then the number screens.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

The tail gear screens are shown only for a variable-pitch (servo) tail. A motor tail has no
gears to the main rotor.

## Settings

| Setting | What it does |
| --- | --- |
| ESC protocol: PWM, DShot150, DShot300 | The three protocols offered as tiles. Use PWM if you are not sure. Blades off. |
| ESC protocol: Other | A drop-down with every other protocol: DShot600, Castle, OneShot, ProShot, DISABLED and the rest. SRXL2 is added from API 12.10. It shows the protocol you have set when it is one of those. DShot600 is not a tile: on long ESC leads it picks up noise. |
| Motor poles | Magnet poles of the main motor, from its data sheet (often 10 or 12). |
| Pinion teeth, Main gear teeth | Teeth on the motor pinion and the main gear. They give the main ratio, shown as n:1. |
| Tail gear in, Tail gear out | Teeth on the tail drive gear at the main shaft and on the tail rotor shaft gear. They give the tail ratio. Pitch tail only. |

## Notes

- DShot150 has no bidirectional DShot, so the flight controller gets no RPM from it. While
  DShot150 is set, the step says that the governor and the RPM filter need DShot300 or an RPM
  sensor. Choosing DShot150 also turns bidirectional DShot off in the same write. An ESC that
  does not answer bidirectional requests may not arm.
- Leaving Castle turns the ESC sensor off, unless a serial ESC telemetry protocol is set.
- The protocol and the gear ratios apply after the restart at step 8, Connect servos.

## Related

- [ESC throttle](../../setup/esc_motors/throttle.md) and [ESC telemetry](../../setup/esc_motors/telemetry.md): the ESC settings on their own pages.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
