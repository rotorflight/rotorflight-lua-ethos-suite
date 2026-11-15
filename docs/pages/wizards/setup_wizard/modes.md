---
title: Mode switches
sidebar_label: Mode switches
sidebar_position: 30
---

# Mode switches

Step 3 of the Model setup wizard. It puts the Arm mode, and optionally Rescue and Trainer,
on switches of your radio.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 3 *Mode switches*. One screen per mode.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

Rescue and Trainer are shown only when the flight controller offers them. They need an
accelerometer.

## Settings

| Setting | What it does |
| --- | --- |
| Arm (required) | Arms the motor. Next waits until Arm is on a switch. Use a switch you will not knock by accident. |
| Rescue | Turns the helicopter upright and holds it level. Optional. |
| Trainer | Limits how far the helicopter can tilt, to help while learning. Optional. |
| Assign | Press, then flick the switch to the position that should turn the mode on. The wizard writes a mode range for that position. Times out after 15 s if no switch moves. |
| Assign again, Remove, Cancel | Change or clear the switch of a mode while it is on its screen. |
| Range (CH n, from - to µs) | The channel and pulse range the mode is set to. |

## Notes

- The switches are read from the radio's own channel outputs.
- Arming stays blocked while the wizard is open.
- If the flight controller has no free mode slot, the step says so. Remove a mode under
  Modes, then assign again.
- The last screen sums up what is set. It says whether the way forward is Next (nothing
  changed) or Save and continue (the changes already work on the flight controller but are
  not yet stored in its EEPROM).
- Any other mode is set on the Modes page.

## Related

- [Modes](../../setup/controls/modes.md): all mode ranges and their conditions.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
