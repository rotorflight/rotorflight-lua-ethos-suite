---
title: Board orientation
sidebar_label: Board orientation
sidebar_position: 10
---

# Board orientation

Step 1 of the Model setup wizard. It calibrates the accelerometer, finds how the flight
controller board is mounted, and shows the result on a live picture of the helicopter.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 1 *Board orientation*. The step has four
screens: the intro, the accelerometer, the orientation and the check ("Step 1 of 4").

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

The step tells you to set the orientation on the Alignment page instead when:

- the board has no accelerometer;
- the firmware cannot detect the orientation (automatic board alignment needs API 12.10).

## Settings

| Setting | What it does |
| --- | --- |
| Servos unplugged, All blades removed | Two toggles on the intro (No / Yes). Start is enabled once both are Yes. |
| Calibrate accelerometer | Stand the helicopter level on its skids and keep it still. The step reports calibrated or failed. Detection is refused until the accelerometer is calibrated. |
| Detect board orientation | With the helicopter level, press Detect, then lift the tail about 20 degrees and hold it still. The result shows roll, pitch and yaw in degrees. "No orientation matched" and "Timed out" mean: lift the tail straight up, or a little further, and try again. |
| Direction is correct | The live picture follows every tilt, left and right, nose down and up. Confirm that it moves the right way. |
| Save and restart | Shown when the orientation has changed. Saves it and restarts the flight controller so it applies now. Next leaves the restart to step 10, Connect servos. |

## Notes

- The orientation applies after a restart. Save and restart here checks it at once. Next
  postpones the restart to step 10, and the servos stay unplugged until then.
- Remove the main and tail blades and unplug the servos before you start.

## Related

- [Alignment](../../setup/alignment.md): set the orientation by hand.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
