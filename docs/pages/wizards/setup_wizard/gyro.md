---
title: Gyro check
sidebar_label: Gyro check
sidebar_position: 130
---

# Gyro check

Step 19 of the Model setup wizard. With no overrides, you move the helicopter by hand and check
that the swash pushes back against each movement.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 19 *Gyro check*. Three movements: Roll,
Pitch and Yaw.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | Roll the helicopter quickly to the right. The swash should tilt left, against the movement. |
| Pitch | Tip the nose down quickly. The swash should tilt back, against the movement. |
| Yaw | Turn the nose quickly to the right. The tail blades should push the nose back to the left. |
| Against / With | A switch on the right. Against (the default) is the gyro correcting the movement, as the picture shows. Press it to switch to With: the gyro moves with the movement. That shows the board orientation note and a button to the Sensors step, and the way forward waits until the answer is Against again. |

## Notes

- The first page is a safety card: the motor is unplugged, and Start is greyed out until that is
  answered.
- Each axis has its own page, with the EdgeTX suite's picture.
- A wrong answer means the board orientation is wrong. Fix it in the Board orientation step
  (Sensors); do not reverse any servo for it.

## Related

- [Board orientation](sensors.md): the step to go back to.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
