---
title: Servo centre
sidebar_label: Servo centre
sidebar_position: 80
---

# Servo centre

Step 14 of the Model setup wizard. It checks the direction of each swash servo and centres it, one
page per servo: the servo picture and, beside it, the swashplate picture of the Connect step on the left, and the controls on the right.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 14 *Servo centre*. One page per servo; the
servo's count stands beside the title.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step lists only the swash and tail servos that exist.

## Pages

1. **Servo arms.** The explanation with the servo picture and the swashplate picture of the Connect step beside it: set each arm square to its pushrod, then check each servo. Below it, the question "All blades removed": Start is greyed out until it is ticked, and the blades must be off before the servos move.
2. **One page per servo**, in the order of the list below. The last page, the tail servo (or the last swash servo when there is no tail servo), has *Save and continue* instead of Next: it saves the step and goes on to the next step.

## Settings

| Setting | What it does |
| --- | --- |
| Move up 20° | Holds the servo 20 degrees up. The button then reads "Back to centre": press it to return the servo to the centre. Did the arm move up, towards the swash? Not on the tail servo. |
| Reverse | Flips the servo's direction and holds the servo up again, so the arm moves the new way. The button then reads "Normal" once the direction is reversed. Not on the tail servo. |
| Centre | The centre pulse in µs. Type the value in the field until the servo arm is level. The tail servo arm is set to 90 degrees to the pushrod. |
| Offset | The offset from the band centre, as you change the centre (for example "0 us from 1520 us"). |

## Notes

- The wizard warns when the centre is more than 100 µs from the band centre. Move the servo arm
  a spline instead of typing a centre that far away.
- The tail servo is only centred. Its direction is set in the Tail rotor step.
- Keep the servos plugged in, as the Connect servos step asked.

## Related

- [PWM Output](../../setup/servos/pwm.md): the servo outputs on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
