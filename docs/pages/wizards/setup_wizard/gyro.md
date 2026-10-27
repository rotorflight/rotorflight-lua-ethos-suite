---
title: Gyro check
sidebar_label: Gyro check
sidebar_position: 130
---

# Gyro check

Step 14 of the Model setup wizard. With no overrides, you move the helicopter by hand and check
that the swash pushes back against each movement.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 14 *Gyro check*. Three movements: Roll,
Pitch and Yaw.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | Roll the helicopter quickly to the right. The swash should tilt left, against the movement. |
| Pitch | Tip the nose down quickly. The swash should tilt back, against the movement. |
| Yaw | Turn the nose quickly to the right. The tail blades should push the nose back to the left. |
| With / Against | Answer whether the gyro corrects the movement with it or against it. |
| Orientation | Opens the Board orientation step, if the answer was wrong. |

## Notes

- Blades off and disarmed before you start.
- A wrong answer means the board orientation is wrong. Fix it in the Board orientation step.
  Do not reverse any servo for it.

## Related

- [Board orientation](sensors.md): the step to go back to.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
