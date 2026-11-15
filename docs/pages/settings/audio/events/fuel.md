---
title: Fuel
sidebar_label: Fuel
sidebar_position: 30
---

# Fuel

How often the SmartFuel estimate speaks, how often it repeats, and whether it buzzes as well.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Fuel*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Fuel* | Turns the SmartFuel callouts on. Everything below is greyed out while it is off. |
| *Callout percent* | The step at which a percentage callout is made. *Default* speaks at 10 percent. *Every 5%* speaks at each 5 percent step, from 95 down to 5. *Every 10%*, *Every 20%*, *Every 25%* and *Every 50%* speak at their steps down to 10 percent. The 100 percent step is never spoken. Defaults to *Default*. |
| *Low fuel repeats* | How often a standing low-fuel warning repeats. Range 1 to 10, default 1. |
| *Low fuel haptic* | Vibrates as well as speaks on a low-fuel warning. Off by default. |

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
- **0 % is the consumption reserve, not an empty pack.** The SmartFuel value reads 0 % at the
  *Consumption Warning %* set on the Battery page (35 % by default). The low-fuel warning is
  spoken at 0 %, so it comes while that share of the pack is still left. To be warned at 40 % left,
  set *Consumption Warning %* to 40.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*