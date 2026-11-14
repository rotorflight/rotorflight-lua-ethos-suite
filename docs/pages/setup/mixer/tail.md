---
title: Tail
sidebar_label: Tail
sidebar_position: 30
---

# Tail

How the tail is driven and how far it may move. The page shows only the fields for the tail mode, and changing between a servo tail and a motor tail swaps them straight away: a variable pitch tail works in degrees, a motorised or bidirectional tail in percent.

## Where to find it

*Configuration* → *Setup* → *Mixer* → *Tail*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Tail Mode | Variable Pitch (a servo on servo 4), Motorized Tail or Bidirectional (a tail motor on motor 2). Changing it reboots the flight controller on save. |
| Tail pin | Read only. Where the tail pin is: *Servo 4*, *Motor 2*, *Own motor pin* (motor 2 has a pin of its own) or *No pin*. *Save: to motor 2* or *Save: to servo 4* when the tail mode needs the pin moved; Save moves it. *Kept: …* when the flight controller refused the move, with the reason (see Notes). Needs Rotorflight with MSP API 12.10; shows *-* on older firmware. |
| Yaw Direction | Normal or Reversed yaw. |
| Tail Idle Thr% | Motor tails only. The lowest throttle sent to the tail motor, in %. |
| Tail Center Offset | Motor tails only. Tail motor throttle for zero yaw, in %. |
| Yaw Center Trim | Variable pitch only. Tail pitch trim at centre, in degrees. |
| Yaw Calibration | Yaw gain to match the tail mechanics, in %. |
| Yaw CW Limit / Yaw CCW Limit | Largest yaw each way: % for a motor tail, degrees for a variable pitch tail. |

## Notes

- Many flight controllers come with the tail on servo 4. A motorised tail needs that pin as motor 2. When the tail mode and the pin disagree, the page offers Save even with nothing edited, and Save moves the pin (MSP2_TAIL_MOTOR_OUTPUT) before the flight controller reboots. A pin left on servo 4 with a motorised tail blocks arming (*Motor Protocol* on [FBL Status](../../tools/diagnostics/fblstatus.md)).
- The flight controller refuses to move the pin when its timer also drives another servo or motor (*Kept: timer shared*), when motor 1 has no pin (*Kept: no motor 1*), when the pin has no timer (*Kept: no timer*), when the ESC protocol is DShot without bitbang and the pin has no DMA (*Kept: no DMA*), or when the motor and servo pins were set by hand (*Kept: custom pins*). Use the Remap FC tab of the Rotorflight Configurator in those cases.
- Changing between a servo tail and a motor tail also sets Tail Torque Assist on every PID profile: gain 100 for a motor tail, 0 for a servo tail. The save confirmation says so. Tail Torque Assist only acts with the Electric or Direct governor.
- On a variable pitch tail, the Tool button turns on mixer override for yaw, which holds the tail at centre. It is greyed out on a motor tail: a disarmed flight controller does not drive the tail motor from the mixer. While override is on, every field except Yaw Center Trim is locked, and the trim is sent to the flight controller half a second after you stop changing it, so you can watch the tail move. Save keeps the trim. Nothing is sent until you change the trim, and nothing is sent while the model is armed or the radio has not confirmed it is disarmed. Leaving the page without saving puts the old trim back, unless the model is armed then: the flight controller keeps the new trim until it restarts. Leaving the page also turns the override off.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
