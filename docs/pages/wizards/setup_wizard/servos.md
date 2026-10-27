---
title: Servo centre
sidebar_label: Servo centre
sidebar_position: 80
---

# Servo centre

Step 10 of the Model setup wizard. It checks the direction of each swash servo and centres it.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 10 *Servo centre*. One screen per servo;
where the step works through a list, the item's count stands beside the title.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step lists only the swash and tail servos that exist.

## Settings

| Setting | What it does |
| --- | --- |
| Servo test | Holds the servo 20 degrees up. Yes, up: the arm moved towards the swash. No, down: the servo is reversed, and the step checks the arm again. |
| Centre nudges (-10, -1, +1, +10 µs) | Moves the centre until the servo arm is level. The tail servo arm is set to 90 degrees to the pushrod. |
| Centre value | The centre pulse in µs, shown as you nudge it. |

## Notes

- The wizard warns when the centre is more than 100 µs from the band centre. Move the servo arm
  a spline instead of nudging the centre that far.
- The tail servo is only centred. Its direction is set in the Tail rotor step.
- Keep the servos plugged in, as the Connect servos step asked.

## Related

- [PWM Output](../../setup/servos/pwm.md): the servo outputs on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
