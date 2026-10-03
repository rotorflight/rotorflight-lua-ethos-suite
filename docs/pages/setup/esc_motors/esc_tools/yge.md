---
title: YGE
sidebar_label: YGE
sidebar_position: 90
---

# YGE

Setup -> ESC & Motors -> Forward Programming -> YGE.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *YGE*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 9).

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- *Motor Timing* is shown in the ESC's own terms, not as a list position: the
  four automatic modes (*Auto Norm*, *Auto Eff*, *Auto Power*, *Auto Extr*) and
  the six fixed advance angles (*0 deg* .. *30 deg*) are translated to and from
  the word the ESC actually uses, and a row you did not touch is written back
  with the word it was read with. See #2336.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
