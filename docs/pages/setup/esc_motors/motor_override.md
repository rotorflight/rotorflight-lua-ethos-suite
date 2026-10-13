---
title: Motor Override
sidebar_label: Motor Override
sidebar_position: 10
---

# Motor Override

Setup -> ESC & Motors -> Motor Override. Drives a motor directly from the radio via MSP_SET_MOTOR_OVERRIDE (195).

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Motor Override*

Disabled while the model is armed. Greyed out until the flight controller answers.

> **Remove the blades and secure the craft first.** The flight controller drives the
> motor directly with no throttle stick, no mix and no arming check in between. Anything
> that is still attached turns.

## Settings

| Setting | What it does |
| --- | --- |
| Motor | Which motor this page drives. Offered only on a board with more than one. |
| Enable motor override | Arms the page. Asks for confirmation first. |
| Throttle | 0-100 % of full throttle, applied directly to the selected motor. |

## How it stays safe

**A confirmation stands in front of the switch.** Turning the switch on asks before
anything is written; turning it off asks too, because handing the motor back is a step
worth being deliberate about. A cancel puts the page back the way it was.

**The flight controller holds a 1-second deadline.** `MOTOR_OVERRIDE_TIMEOUT` is one
second (`motors.h`), and `motors.c` resets every override once it passes. So a single write
is not a motor that stays on - it is a motor that turns for one more second. The page
therefore re-sends the current value four times a second while the override is enabled.
Without that the motor would stop by itself about a second after you let go of the wheel,
which reads as an intermittent fault.

**Leaving the page releases the motor.** Back, a page switch and closing the tool all run
the same release, and it names *every* motor the page could have touched - not only the
selected one - because the pilot may have moved between them in between.

**An armed model cannot be overridden at all.** The firmware ignores the write outright
while armed (`motors.c`, `setMotorOverride` checks the arming flag first). The switch is
therefore disabled rather than shown as a control that would quietly do nothing, and an
override that was already running when the model armed is handed straight back.

**A lost link hands the motor back.** When the link drops nothing can be written any more,
so the one-second deadline on the board ends the override on its own. The page drops the
switch at the same moment instead of leaving it claiming a motor is being driven.

What none of that can cover - the script being killed, the transmitter crashing - is
covered by the firmware, for the same reason the keep-alive exists: no write, no motor,
one second after the last one.

## Notes

- The page shows what the flight controller is *already* overriding when it opens, rather
  than starting from zero. A non-zero value there means something else is driving that
  motor.
- Only the forward half of the range is offered. The firmware accepts negative values and
  they run the motor backwards, which is not part of any setup procedure.
- The title carries a `*` while the override is engaged.

## Servo override has no equivalent keep-alive

Servo override (`MSP_SET_SERVO_OVERRIDE`, 196) holds until something writes
`SERVO_OVERRIDE_OFF`. The firmware stores the value and has no timeout for it
(`servos.c`, `setServoOverride`) - there is no counterpart to `MOTOR_OVERRIDE_TIMEOUT` on
the servo side. Servo override pages in this suite therefore re-send only when the value
actually changes, and release on close.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*