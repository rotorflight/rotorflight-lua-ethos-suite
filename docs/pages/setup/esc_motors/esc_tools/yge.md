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
- *BEC Voltage* goes up to **12.0 V** on the models that have an HV BEC, and stays
  at **8.4 V** on the ones that do not. The ceiling follows the ESC that answered,
  so it changes with the model; an ESC this page has no entry for is treated as an
  8.4 V one. See #2337.
- The *BEC Voltage* row is **hidden entirely** on an Opto model. An Opto ESC has no
  BEC, so there is no voltage to set — a capped control for a setting that cannot
  exist would be worse than no control.

### 12 V BEC and the HV-BEC flag

The HV-BEC flag is not a row of its own. It follows the BEC Voltage instead, and
it follows it in one direction only:

| You do | The flag becomes |
| --- | --- |
| move the voltage **to 12.0 V** | set |
| move the voltage **to anything below 12.0 V** | cleared |
| do not touch the voltage | left exactly as the ESC reported it |

So 12.0 V is the mode and 11.9 V is not, even though both are on the same slider —
selecting 11.9 V clears the flag. And a save that changed some other setting leaves
the flag alone, even if the ESC reported a combination this page would not have
produced itself.

Models with a **12 V** BEC — seven of them, and the three HVTs are among them, so
a 12 V BEC is not a v2-only feature:

| | |
| --- | --- |
| *YGE 165 HVT* | *YGE 205 HVT v2* |
| *YGE 205 HVT BEC* | *YGE Aureus 105v2* |
| *YGE Saphir 125v2* | *YGE Aureus 135v2* |
| *YGE Saphir 155v2* | |

Models with **no BEC**, where the row is hidden: *YGE 90 HVT Opto*,
*YGE 120 HVT Opto*, *YGE Opto 135*, *YGE Opto 255*, *YGE Opto 405*.

Every other YGE model has a BEC and is offered up to 8.4 V.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
