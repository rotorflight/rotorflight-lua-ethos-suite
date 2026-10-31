---
title: Setup Wizard
sidebar_label: Setup Wizard
sidebar_position: 5
---

# Setup Wizard

A guided bench setup of a helicopter, one question per screen. It is the radio's version of
the Rotorflight Configurator's Setup Wizard and applies the same rules. Each of its 17 steps
has its own page, linked below.

## Where to find it

*Configuration* → *Wizards* → *Model setup*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Requirements

The wizard runs on API 12.09 and later, the oldest version the suite supports. Some
parts need newer firmware:

- Board orientation detection (step 1) needs API 12.10. Without it, the step asks you to
  set the orientation on the Alignment page.
- Moving the tail pin between SERVO 4 and MOTOR 2 (step 6) needs API 12.10.
- SRXL2 is offered as an ESC protocol (step 9) from API 12.10.
- F.Port2 is offered as a receiver protocol (step 2) only on API 12.7 to 12.9. From 12.10,
  FBUS detects it.

## Steps

The steps run in this order, because each relies on the ones before it. The checklist
button in the header lists every step, so you can jump to one. The wizard reopens on
the step you left, until the radio is restarted.

Each screen of a step shows its place in the step under the buttons ("Step 2 of 6").
Where a step works through a list (a servo, a check, a trim), the item's own count
stays beside the title. A step with one screen shows no count.

| Step | What it does |
| --- | --- |
| 1. [Board orientation](setup_wizard/sensors.md) | Calibrates the accelerometer and finds the board orientation. |
| 2. [Receiver](setup_wizard/receiver.md) | Sets the protocol, the channel order and the throttle range. |
| 3. [Mode switches](setup_wizard/modes.md) | Puts Arm, and optionally Rescue and Trainer, on switches. |
| 4. [Profiles & gain](setup_wizard/profiles.md) | Sets the profile switch (PID profile, with the rates or alone) and the master gain in flight, on trim buttons or a knob. |
| 5. [Rates](setup_wizard/rates.md) | Gives each rate profile on the profile switch a flying style: Trainer, Sport or 3D, or leaves it as it is. |
| 6. [Swashplate](setup_wizard/swash.md) | Sets the swash type, the rotor direction and the tail type. |
| 7. [Servo type](setup_wizard/servotype.md) | Sets the servo type, and with it the update rate and centre pulse. |
| 8. [Governor](setup_wizard/governor.md) | Sets the governor mode and the throttle type, and the headspeed of each PID profile when a governor runs. |
| 9. [Motor & ESC](setup_wizard/motor.md) | Sets the ESC protocol, where the headspeed comes from (a wire, or bidirectional DShot) when a governor runs, the motor poles and the gear ratios. |
| 10. [Connect servos](setup_wizard/connect.md) | Applies a pending restart and checks the outputs before the servos are plugged in. |
| 11. [Servo centre](setup_wizard/servos.md) | Checks the direction of each swash servo and centres it. |
| 12. [Directions](setup_wizard/direction.md) | Checks that roll, pitch and collective move the swash the right way. |
| 13. [Level swash](setup_wizard/level.md) | Trims the swash until it is level at zero blade pitch. |
| 14. [Blade pitch](setup_wizard/pitch.md) | Calibrates the blade pitch with a pitch gauge and sets the limits. |
| 15. [Tail rotor](setup_wizard/tail.md) | Sets the tail centre, direction, calibration and end stops, or tests and idles a motor tail. |
| 16. [Gyro check](setup_wizard/gyro.md) | Checks by hand that the gyro corrects against each movement. |
| 17. [Finish](setup_wizard/finish.md) | Summarises what was set and saves it. |

## Notes

- Take the main and tail blades off before you start, and leave the servos unplugged
  until step 10. The wizard moves servos and, on a motorised tail, the tail motor.
- Arming is blocked while the wizard is open. If the model arms anyway, or the link
  drops, every servo, mixer and motor override is released and the wizard says why.
  Leaving the wizard by any route releases them too.
- Changes are sent to the flight controller as you make them, so the servos move.
  *Next* becomes *Save and continue* once something has changed, and saves to EEPROM.
  Leaving with unsaved changes asks whether to save or discard them; Discard writes
  back what was there before. Going to another step (from the step list, or Back from
  a step's first screen) asks the same, so one step's changes are never saved by
  another step's Save and continue.
- Changes that only apply after a restart (board orientation, swash or tail type, servo
  update rate, ESC protocol) are saved as you go, and the one restart happens at step 10.
  A step after it shows a reminder while a restart is still owed.
- Not covered here: modes and switches beyond Arm, Rescue and Trainer, rates,
  governor, the ESC throttle calibration and spin test, and ESC telemetry. Use their own pages.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
