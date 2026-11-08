---
title: Blade pitch
sidebar_label: Blade pitch
sidebar_position: 110
---

# Blade pitch

Step 17 of the Model setup wizard. It calibrates the blade pitch with a pitch gauge, sets the hard
pitch limits, and sets the collective pitch at full stick for each rate profile.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 17 *Blade pitch*. The pages: a safety card, the
collective and the cyclic (each measured, then fine adjusted), the three limits, and one page for the
collective at full stick of each rate profile.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Pages

1. **Safety card.** The motor is unplugged, because the blades are measured in this step. Start is
   greyed out until *Motor unplugged* is answered with yes.
2. **Collective and cyclic.** Each in two pages: *measure* (the collective held at 9 degrees, or the
   blades along the boom, with roll held at 9 degrees; #2709), then *fine* (the rate in 0.1 %). On the *measure*
   page, *Hold angle* sets the angle the axis is held at (9 degrees by default, up to the stored limit; #2708).
   *Check at 0 degrees* holds the blades at zero pitch, so you can see the zero at the gauge before you
   calibrate. Away from 9 degrees the page only shows *Hold angle*, the check button and *Back to 9 degrees*;
   Measured, the rate and Calibrate are offered at 9 degrees only, because the calibration counts from 9
   degrees (#2706).
3. **Limits.** Cyclic, collective and total. These are the hard limits of the mixer, the same for
   every rate profile.
4. **Collective at full stick.** One page with a row per rate profile the profile switch picks (or the
   active one). Each profile has its own value.

## Settings

| Setting | What it does |
| --- | --- |
| Hold angle | The angle the axis is held at on the measure page, in 0.1 degrees, either side of zero: from minus to plus the stored limit of the axis, but at least 9 and at most 12 degrees. The negative side checks the collective geometry, for example -10 after +10. It starts at 9 degrees. Use it to look at the gauge at another angle; the calibration still counts from 9 degrees. |
| Measured | The blade pitch you read on the gauge, typed in its field, 1.0 to 30.0 degrees. |
| Rate | The rate of the axis, in 0.1 %, typed in its field. Adjust it until the gauge reads 9 degrees. |
| Calibrate | Scales the mixer so that 9 degrees on the gauge is 9 degrees in the flight controller. It then reads "Calibrated. Measure again to check." |
| Cyclic limit | The most blade pitch the cyclic sticks can command: 0 to 20 degrees. |
| Collective limit | The most blade pitch the collective stick can command: 0 to 20 degrees. |
| Total limit | The most blade pitch cyclic and collective together may reach: 0 to 36 degrees. |
| Collective at full stick | The blade pitch the collective stick gives at full stick, for this rate profile: 0 to 31.9 degrees. About 12 degrees is usual for 3D, less for sport flying. |

## Notes

- You need a pitch gauge. The wizard holds the blades at the set pitch; you measure and type what
  you read.
- Each limit page suggests a value: 10 degrees for cyclic, 12 degrees for collective. Use it, or
  type your own within the range.
- The collective at full stick is set for every rate profile on the profile switch, because each
  profile can fly a different collective. Keep it at or below the collective limit.
- The collective at full stick is only set on the Rotorflight rates type. On a profile with the
  Actual rates type its rows are left out, and the page says so: set the rates on the Rates page.
- Each change is sent to the flight controller as you make it. The rate profile the flight controller
  is on is selected again afterwards.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
