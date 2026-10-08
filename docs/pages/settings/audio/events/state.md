---
title: State callouts
sidebar_label: State callouts
sidebar_position: 40
---

# State callouts

What the suite announces when a state changes rather than when a value crosses a threshold.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *State callouts*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Arming flags* | Announces arming flags as the flight controller reports them. |
| *Governor state* | Announces the governor as it enters and leaves a running mode. |
| *PID profile* | Announces the newly selected PID profile. |
| *Rate profile* | Announces the newly selected rate profile. |
| *Battery profile* | Announces the newly selected pack. |
| *Adjustment function* | Announces the function an in-flight adjustment has landed on. |
| *Adjustment value* | Announces the value an in-flight adjustment has landed on. |

## Notes

- **Battery profile** announces the newly selected pack as "Battery, 2200 milliamp hours, 4
  cells". The cell count is left out when the profile has none set.
- None of these depends on a threshold, so nothing on this page is greyed out by another setting
  here.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*