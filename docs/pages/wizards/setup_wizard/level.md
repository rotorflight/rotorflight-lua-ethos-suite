---
title: Level swash
sidebar_label: Level swash
sidebar_position: 100
---

# Level swash

Step 12 of the Model setup wizard. It trims the swash until it is level and the blades are at
zero pitch.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 12 *Level swash*. Three trim screens, one
each for Roll, Pitch and Collective.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

| Setting | What it does |
| --- | --- |
| Roll trim | Seen from behind, trim until the swash is level left to right. |
| Pitch trim | Seen from the side, trim until the swash is level front to back. |
| Collective trim | Trim until the main blades are at zero pitch. |
| Reset | Resets the trim of the current screen. |

## Notes

- The swash is held at its centre while you trim.
- Each trim moves in 0.1 % steps, between -100 % and +100 %.
- Changes are sent to the flight controller as you make them.

## Related

- [Trims](../../setup/mixer/trims.md): the same trims on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
