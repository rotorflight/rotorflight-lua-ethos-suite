---
title: Level swash
sidebar_label: Level swash
sidebar_position: 100
---

# Level swash

Step 16 of the Model setup wizard. It trims the swash until it is level and the blades are at
zero pitch.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 16 *Level swash*. Two pages: a safety card,
then the level page.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Pages

1. **Safety card.** The motor is unplugged, because the blades are fitted in this step. Start is
   greyed out until *Motor unplugged* is answered with yes. Under the answer: the swash is held at its
   centre and is trimmed until it is level with the blades at zero pitch.
2. **Level page.** The width is split into three equal parts: the EdgeTX suite’s pictures side by
   side, each with its view (From behind, and From the side) and a short description under it, then the
   trims, one under the other, each with its name on the left.

## Settings

| Setting | What it does |
| --- | --- |
| Roll | The roll trim, seen from behind: trim until the swash is level left to right. Type the value in the field. |
| Pitch | The pitch trim, seen from the side: trim until the swash is level front to back. |
| Collective | The collective trim: trim until the main blades are at zero pitch. |
| Reset | Resets all three trims to 0. |

## Notes

- The swash is held at its centre while you trim.
- Each trim moves in 0.1 % steps, between -100 % and +100 %.
- Changes are sent to the flight controller as you make them.
- Level the swash mechanically first (the servo links, with a swash leveller or by eye). The trims
  are for what the links cannot adjust.

## Related

- [Trims](../../setup/mixer/trims.md): the same trims on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
