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
| *Adjustment function* | Announces the name of the function an in-flight adjustment is changing, followed by its value. |
| *Adjustment value* | Announces the value an in-flight adjustment has settled on. |

## Notes

- **Battery profile** announces the newly selected pack as "Battery, 2200 milliamp hours, 4
  cells". The cell count is left out when the profile has none set.
- **Adjustments** are spoken once the value has stopped changing for about a third of a second.
  A burst of trim clicks therefore says one number, the one the model ended up with, rather than
  each step. Nothing is spoken while the value is still moving. A change that settles while the
  previous announcement is still playing is spoken after it.
- None of these depends on a threshold, so nothing on this page is greyed out by another setting
  here.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*