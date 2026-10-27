---
title: Blade pitch
sidebar_label: Blade pitch
sidebar_position: 110
---

# Blade pitch

Step 11 of the Model setup wizard. It calibrates the blade pitch with a pitch gauge and sets
the pitch limits.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 11 *Blade pitch*. Screens: the intro, the
collective, the cyclic, and the three limits.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| Collective | The collective is held at 9 degrees. Measure the blade pitch with a pitch gauge, enter the reading, then Calibrate. |
| Cyclic | The blades are turned to point left and right, with the pitch held at 9 degrees. Measure, enter the reading, then Calibrate. |
| Rate (fine adjust) | Adjusts the rate until the gauge reads 9 degrees. |
| Calibrate | Scales the mixer so that 9 degrees on the gauge is 9 degrees in the flight controller. It reads "Calibrated. Measure again to check." |
| Cyclic limit | The most blade pitch the cyclic sticks can command: 0 to 20 degrees. |
| Collective limit | The most blade pitch the collective stick can command: 0 to 20 degrees. |
| Total limit | The most blade pitch cyclic and collective together may reach: 0 to 36 degrees. |

## Notes

- You need a pitch gauge. The wizard holds the blades at the set pitch; you measure and enter
  what you read.
- Each limit screen suggests a value: 10 degrees for cyclic, 12 degrees for collective.
  Use it or set your own within the range.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
