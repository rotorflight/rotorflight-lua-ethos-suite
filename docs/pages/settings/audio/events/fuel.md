---
title: Smart Fuel
sidebar_label: Smart Fuel
sidebar_position: 30
---

# Smart Fuel

How often the SmartFuel estimate speaks, how often it repeats, and whether it buzzes as well.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Smart Fuel*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Smart Fuel* | Turns the SmartFuel callouts on. Everything below is greyed out while it is off. |
| *Callout percent* | The step at which a percentage callout is made. *Default* leaves the choice to the flight controller; the others speak every 5, 10, 20, 25 or 50 percent. Defaults to 10. |
| *Repeats at 0%* | How often a standing low-fuel warning repeats. Range 1 to 10, default 1. |
| *Haptic at 0%* | Vibrates as well as speaks on a low-fuel warning. Off by default. |

## Notes

The callouts distinguish Nitro (Fuel / Low Fuel) from Electric (Battery / Battery Empty). The same model detection controls the ActiveLook warning text and symbols.

- **The fuel events wait for one reading before they speak.** Every event on this page looks
  at the value it watches, and the first value it sees after connecting is only recorded — no
  announcement is made from it. So a flight controller whose telemetry has not arrived yet cannot
  make the tool announce anything: a fuel reading that is still its unset `0` is not read as an
  empty battery.
- **A genuinely empty pack is still announced**, from the second reading onwards — one step later
  than before, not silenced. The same applies after a reconnect or a battery change: the first
  reading is recorded again, and the warning follows if the value is still `0`.
- A **threshold** announcement (*fuel.wav* for Nitro or *battery.wav* for Electric, plus the percentage) is unchanged: it is made when the
  reading crosses a step of the callout range, once per step, and a standing value does not
  repeat it.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*