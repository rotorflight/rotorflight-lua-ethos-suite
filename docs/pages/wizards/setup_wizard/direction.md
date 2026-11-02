---
title: Directions
sidebar_label: Directions
sidebar_position: 90
---

# Directions

Step 15 of the Model setup wizard. It checks that roll, pitch and collective move the swash
the right way.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 15 *Directions*. It opens with the blades
question (all blades removed), then one screen each for Roll, Pitch and Collective.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| All blades removed | The first page. Start is greyed out until it is answered: the servos move with the sticks from here on. |
| Roll | Push the roll stick right. The swash should tilt right. |
| Pitch | Push the pitch stick forward. The swash should tilt forward. |
| Collective | Raise the collective stick. The whole swash should move up. |
| Normal | The button, on every axis. Press it when the swash moves the wrong way: it reverses that mixer input and then reads "Umgekehrt", with a note under Expected to check the axis again. Press it again to take the reversal back. |
| Stick | The stick's position, in percent of its travel, as the flight controller sees it. |
| Expected | The way the swash should move on that axis. |
| Next / Save and continue | The arrows at the bottom. Next goes to the next axis; on the last axis the way forward is Save and continue, which ends the step. |

## Notes

- The sticks drive the swash directly during this step, without the gyro.
- The pictures are the EdgeTX suite's swash pictures for each axis. The gauge under the picture
  shows the stick too.
- The step puts roll, pitch and collective in passthrough. The gyro is not involved until the
  Gyro check step.

## Related

- [Swash](../../setup/mixer/swash.md): the mixer and its reversed inputs.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
