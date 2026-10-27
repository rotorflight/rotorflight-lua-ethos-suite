---
title: Servo type
sidebar_label: Servo type
sidebar_position: 50
---

# Servo type

Step 6 of the Model setup wizard. It sets the servo type for the swash servos and the tail
servo. The type sets the update rate and the centre pulse.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 6 *Servo type*. Two groups: *Cyclic
servos* and *Tail servo*.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs the swash or tail servos to be configured; without them it
shows a message instead.

## Settings

| Setting | What it does |
| --- | --- |
| Analog | 50 Hz, wide band, centre 1520 µs. |
| Digital | 333 Hz, wide band. |
| Narrow | 560 Hz, narrow band, centre 760 µs. |
| Mixed | Shown for a group whose servos are not all the same type. |
| Custom | Shown when a servo matches none of the types. It is left alone until you pick a type. |

## Notes

- A new update rate applies after the restart at step 8, Connect servos.
- Keep the servos unplugged until the Connect servos step.

## Related

- [Servos](../../setup/servos/pwm.md): the PWM output and its update rate.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
