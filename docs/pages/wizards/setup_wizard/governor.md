---
title: Governor
sidebar_label: Governor
sidebar_position: 55
---

# Governor

Step 8 of the Model setup wizard. It sets the governor mode and, for electric and nitro, the
throttle type. When a governor runs, it also sets the headspeed of each PID profile.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 8 *Governor*. The step starts with a safety
card: the servos stay unplugged and the blades come off, and Start follows once both are
confirmed.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Governor mode | Off, Limit, Direct, Electric or Nitro. Off means no governor: the throttle goes straight to the ESC. |
| Throttle type | Normal, Switch or Function. Only for Electric and Nitro. Switch and Function are not offered for the other modes. |
| Headspeed, per PID profile | The headspeed the governor holds, for the first three PID profiles, which the profile switch uses. Shown only when a governor runs. |

## Notes

- The profiles are read when the headspeed screen opens, with no button. Each change is
  written at once; Discard puts the profile back.
- With a governor running, the headspeed source is set in the Motor & ESC step (step 9). It needs a fast RPM signal:
  an RPM sensor, or bidirectional DShot telemetry.
- The ramp times (spoolup, spooldown, recovery) are not part of the wizard. They are set on the
  governor page.
- Changing the mode from Electric or Nitro to Off or Limit resets a Switch throttle type to
  Normal, as the mode cannot use it.

## Related

- [Motor & ESC](motor.md): the ESC and its telemetry, set in the step after this one.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
