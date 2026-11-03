---
title: ESC & spin test
sidebar_label: ESC & spin test
sidebar_position: 37
---

# ESC & spin test

Step 13 of the Model setup wizard. It teaches a PWM ESC its throttle range, and runs the main motor
at a test speed to check the direction and the start.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 13 *ESC & spin test*. The step starts with a safety
card: the main blades come off, and the pinion comes out of mesh or the helicopter is held down.
Start follows once it is confirmed. Then the calibration (PWM ESCs only), then the spin test.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Calibration (PWM only)

A PWM ESC learns the pulse for full throttle and the pulse for low throttle. It learns them when it
powers up with full throttle, so the steps are in order:

1. **Full throttle**, with the battery still unplugged and the flight controller on USB. The output
   rises to 100 % in a few seconds.
2. Plug the battery in. The ESC beeps to show it has taken full throttle. The tones are in the ESC's
   manual.
3. **Low throttle**. The ESC confirms the range and stores it. Low throttle is greyed out until
   Full throttle has been pressed.

DShot and the other protocols need no calibration, and the step goes straight to the spin test.

## Spin test

The main motor runs at the test speed for 3 seconds, or until **Stop** is pressed. The test speed is
set in percent, up to 50 %. On a PWM ESC the calibration comes first. The blades were confirmed on
the safety card at the start of the step.

While the motor runs, the ring of the bell in the picture turns, and the caption says
"Motor running"; after Stop or the 3 seconds it says "Motor stopped".

Check that the motor starts smoothly and turns the way the rotor direction set in the Swashplate step
says. If it turns the wrong way, swap two motor wires or reverse it on the ESC.

## Notes

- The Configurator's hold-to-spin is not possible on the radio: a button gives a press only. So the
  spin runs for 3 seconds, and Stop ends it early.
- Leaving the step stops the motor.

## Related

- [Connect servos](connect.md): the gate before this step.
- [Motor & ESC](motor.md): the ESC protocol and the gear ratios.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
