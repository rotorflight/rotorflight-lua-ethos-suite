---
title: Model callout
sidebar_label: Model callout
sidebar_position: 60
---

# Model callout

Plays the name of the connected craft once per connection, if the pilot has recorded one.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Model callout*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Model callout* | Plays the connected craft's recorded name on connect. Off by default. |

## Notes

- The sound is `SD:/audio/<model name>.wav`. Spaces in the model name are also tried as
  underscores, so a model called `Blade 450` is looked for as both `Blade 450.wav` and
  `Blade_450.wav`.
- Nothing is played when neither file exists — there is no error and no callout, the pilot just
  hears nothing. The check latches as soon as the setting is on and the craft name is known, so
  a missing file is **not** retried: copying the file in after that point means reconnecting
  before it will play.
- A craft name that has not arrived yet is not latched against — the name comes from its own MSP
  read, so the search waits for it rather than giving up on the first tick after connect.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*