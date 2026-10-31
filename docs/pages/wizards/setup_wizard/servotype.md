---
title: Servo type
sidebar_label: Servo type
sidebar_position: 50
---

# Servo type

Step 7 of the Model setup wizard. It sets the type the servos are made for, which gives
the update rate and the centre pulse, and the geometry correction of the cyclic servos.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 7 *Servo type*. Two groups: *Cyclic
servos* and *Tail servo* (a pitch tail only). Each group has its own screen, with the
servo picture on the left, showing the type's name and the servos' centre and frame rate
under it, and the settings on the right.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs the swash or tail servos to be configured; without them it
shows a message instead.

## Settings

| Setting | What it does |
| --- | --- |
| Type (cyclic) | Analog (50 Hz, 1520 µs), Digital (165 Hz, 1520 µs), Hi-End digital (333 Hz, 1520 µs), Narrow band (560 Hz, 760 µs). |
| Type (tail) | Digital (200 Hz, 1520 µs), Specific digital (333 Hz, 760 µs), Hi-End specific digital (560 Hz, 760 µs). |
| Frame rate | Any rate within the type's band: 50 to 333 Hz for the 1520 µs band, 200 to 560 Hz for the 760 µs band. A rate set by hand shows the nearest type of its band. |
| Geometry correction | On or Off, for the cyclic servos. Corrects the arc of a rotary servo arm at its ends. Not for linear servos. |

## Notes

- A group whose servos match no type opens on its first type (Analog for the cyclic servos,
  Digital for the tail), written once when the step opens. Discard puts the servos back.
- The servos must be centred and their travel set before the geometry correction is checked
  (the *Servo centre* step comes later), then check pitch and limits.
- A new update rate applies after the restart at step 10, Connect servos.
- Keep the servos unplugged until the Connect servos step.

## Related

- [Servos](../../setup/servos/pwm.md): the PWM output and its update rate.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
