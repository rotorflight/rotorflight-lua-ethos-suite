---
title: Governor
sidebar_label: Governor
sidebar_position: 55
---

# Governor

Step 9 of the Model setup wizard. It sets the governor mode and, for electric and nitro, the
throttle type. When a governor runs, it also sets the headspeed of each PID profile.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 9 *Governor*. The step starts with a safety
card: the servos stay unplugged and the blades come off, and Start follows once both are
confirmed.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Governor mode | Off, Limit, Direct, Electric or Nitro. Off means no governor: the throttle goes straight to the ESC. |
| Throttle type | Normal, Switch or Function. Shown for every governor mode; Switch and Function are offered only for Electric and Nitro. |
| Headspeed, per PID profile | The headspeed the governor holds, for the first three PID profiles, which the profile switch uses. Shown only for Electric and Nitro. |

## Notes

- The profiles are read when the headspeed screen opens, with no button. Each change is
  written at once; Discard puts the profile back.
- With a governor running, the headspeed source is set in the Motor & ESC step (step 10). It needs a fast RPM signal:
  an RPM sensor, or bidirectional DShot telemetry.
- The ramp times (spoolup, spooldown, recovery) are not part of the wizard. They are set on the
  governor page.
- Changing the mode from Electric or Nitro to Off or Limit resets a Switch throttle type to
  Normal, as the mode cannot use it.
- Changing the governor mode requests a restart (applied at the Connect servos gate, step 11),
  as the firmware reads the governor mode on boot only.
- Profile-only edits (RPM, curves, gains) do not require a restart.

## Related

- [Motor & ESC](motor.md): the ESC and its telemetry, set in the step after this one.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
