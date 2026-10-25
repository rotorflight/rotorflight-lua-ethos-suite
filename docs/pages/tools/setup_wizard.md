---
title: Setup Wizard
sidebar_label: Setup Wizard
sidebar_position: 5
---

# Setup Wizard

A guided bench setup of a helicopter, one question per screen: board orientation,
channel order, swashplate, servos, motor, blade pitch and tail. It is the radio's
version of the Rotorflight Configurator's Setup Wizard and applies the same rules.

## Where to find it

*Configuration* → *Wizards* → *Model setup*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Steps

The steps run in this order, because each relies on the ones before it. The checklist
button in the header lists every step, so you can jump to one. The wizard reopens on
the step you left, until the radio is restarted.

Each screen of a step shows its place in the step under the buttons ("Step 2 of 6").
Where a step works through a list (a servo, a check, a trim), the item's own count
stays beside the title. A step with one screen shows no count.

| Step | What it does |
| --- | --- |
| 1. Board orientation | Confirms that the servos are unplugged and the blades are off (Yes on both enables Start). Then calibrates the accelerometer (helicopter level and still), then finds the board orientation automatically: press Detect and lift the tail about 20° (or enter roll, pitch and yaw by hand). Needs firmware with automatic board alignment (API 12.10). Last, a live picture follows the helicopter as you tilt it; confirm that the direction is correct. A changed orientation applies after a restart: Save and restart there to check it now, or Next to leave the restart to step 6. |
| 2. Receiver | Before the step, confirms that the blades are off and the servos are unplugged (Yes on both enables Next, as in the EdgeTX suite). Then the link card: the receiver protocol (the choices of the EdgeTX suite) and Save & restart; a wrong protocol cuts the radio link, so the card warns first; Then checks the receiver is sending, sets the channel order (ELRS, FrSky, Futaba/Hitec or Spektrum/JR preset, or detected from the sticks), shows each stick read back by function with the way it moves and its live position in percent (Next waits until each of the four sticks has reached 95 % both ways), and sets the throttle range (measured from the throttle travel, or the defaults). The receiver protocol and port are not changed here: the radio talks to the flight controller through this receiver, so they stay in the Configurator. |
| 3. Swashplate | Swash type (120°, 135°, 140°, 90° L, 90° V or Direct), a picture of where its servos sit, main rotor direction (CW or CCW), and tail type (variable pitch, motorised or bidirectional). A new tail type resets the yaw mixer rate, moves the tail pin between SERVO 4 and MOTOR 2 on save where the firmware supports it, and sets Tail Torque Assist on every PID profile. Swash and tail type apply after the restart at step 6. |
| 4. Servo type | Analog (50 Hz), Digital (333 Hz) or Narrow band (560 Hz, 760 µs centre), for the swash servos and the tail servo. A new update rate applies after the restart at step 6. |
| 5. Motor & ESC | ESC protocol: PWM, DShot150 or DShot300, or any other protocol (DShot600, Castle, OneShot, ProShot, DISABLED, ...) from the **Other** drop-down, which shows the protocol set when it is one of those. DShot600 is not offered as a tile: on long ESC leads it picks up noise, so choose it only if you know your wiring suits it. DShot150 has no bidirectional DShot, so the flight controller gets no RPM from it: while it is set the step says that the governor and the RPM filter need DShot300 or an RPM sensor, and choosing it turns bidirectional DShot off in the same write (an ESC that does not answer bidirectional requests may not arm). Then main motor poles, pinion and main gear teeth, and the tail gear ratio for a variable-pitch tail. Applies after the restart at step 6. |
| 6. Connect servos | If a restart is owed, saves and restarts the flight controller with the servos still unplugged, and reopens on this step. Then it checks the motor outputs, lists the servos the wizard will use, and asks you to plug them in. |
| 7. Servo centre | Holds each swash servo 20° up to check its direction (No reverses it), then centres it with -10/-1/+1/+10 µs nudges. Warns when the centre is more than 100 µs off: move the servo arm a spline instead. The tail servo is only centred. |
| 8. Directions | Puts roll, pitch and collective in passthrough. Move each stick as shown: if the swash moves the wrong way, Wrong reverses that mixer input. |
| 9. Level swash | Holds the swash at its middle and trims roll, pitch and collective (0.1 % steps) until it is level and the blades are at zero pitch. |
| 10. Blade pitch | Holds 9° of collective, then 9° of cyclic: measure the blades with a pitch gauge, enter the reading, and Calibrate scales the mixer so 9° is 9°. Then the cyclic limit, collective limit (0 to 20°) and total pitch limit (0 to 36°). |
| 11. Tail rotor | Variable-pitch tail: centre trim, stick direction, calibration at 22° each way, and CW/CCW end stops at up to 60°. Motorised tail: a short spin test at a set power (reverse too on a bidirectional tail) and the tail idle. |
| 12. Gyro check | No overrides: move the helicopter by hand and check the swash (and a servo tail) pushes back against the movement. A wrong answer means the board orientation is wrong: go back to step 1, and don't reverse any servos for it. |
| 13. Finish | A summary of what was set and the checks before the first flight. With DShot150 it repeats the Motor & ESC step's note that there is no RPM for the governor or the RPM filter. Save and finish saves and leaves the wizard. |

## Notes

- Take the main and tail blades off before you start, and leave the servos unplugged
  until step 6. The wizard moves servos and, on a motorised tail, the tail motor.
- Arming is blocked while the wizard is open. If the model arms anyway, or the link
  drops, every servo, mixer and motor override is released and the wizard says why.
  Leaving the wizard by any route releases them too.
- Changes are sent to the flight controller as you make them, so the servos move.
  *Next* becomes *Save and continue* once something has changed, and saves to EEPROM.
  Leaving with unsaved changes asks whether to save or discard them; Discard writes
  back what was there before.
- Changes that only apply after a restart (board orientation, swash or tail type, servo
  update rate, ESC protocol) are saved as you go, and the one restart happens at step 6.
  A step after it shows a reminder while a restart is still owed.
- Not covered here: modes and switches, profiles, rates, governor, the ESC throttle
  calibration and spin test, and ESC telemetry. Use their own pages.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
