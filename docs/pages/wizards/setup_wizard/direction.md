---
title: Directions
sidebar_label: Directions
sidebar_position: 90
---

# Directions

Step 9 of the Model setup wizard. It checks that roll, pitch and collective move the swash
the right way.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 9 *Directions*. One screen each for Roll,
Pitch and Collective, after an intro.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | Push the roll stick right. The swash should tilt right. |
| Pitch | Push the pitch stick forward. The swash should tilt forward. |
| Collective | Raise the collective stick. The whole swash should move up. |
| Correct / Wrong | Answer whether the swash moved as shown. Wrong reverses that mixer input. Check it again after a reversal. |

## Notes

- The sticks drive the swash directly during this step, without the gyro.
- The step puts roll, pitch and collective in passthrough. The gyro is not involved until the
  Gyro check step.

## Related

- [Swash](../../setup/mixer/swash.md): the mixer and its reversed inputs.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
