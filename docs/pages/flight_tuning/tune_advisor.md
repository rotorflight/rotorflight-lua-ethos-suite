---
title: Tune Advisor
sidebar_label: Tune Advisor
sidebar_position: 30
---

# Tune Advisor

While you fly in rate mode, the flight controller measures how the heli answers the sticks. This page reads
those measurements and suggests one change at a time for each axis. It changes nothing by itself: make the
change on *PIDs*, *Rates* or *PID Controller*, fly again and come back.

The flight controller counts only rate flight while spooled up and airborne, with the heli moving on some axis.
Time in Angle, Horizon, Trainer, Rescue, GPS rescue or failsafe is left out. The data builds up over several
flights and clears on its own when you change the PIDs, Iterm Relax Cutoff, PID mode, rates or the active
profile. A useful set is about ten seconds of rolls, flips and pirouettes with the stick centred after each one.
The measurements live in the flight controller's memory and are lost at power-off.

## Where to find it

*Configuration* → *Flight Tuning* → *Tune Advisor*

Needs a flight controller connection. Firmware from before the Tune Advisor shows "Needs newer firmware". The
page refreshes every 2 seconds.

## Settings

| Line | What it shows |
| --- | --- |
| Axis | Roll, Pitch or Yaw. Everything below is for the chosen axis. |
| Changes / Why | Only on 480-pixel-wide radios (X18, X18R, X10 and similar), beside Axis. *Changes* shows the suggested changes and as many reasons as fit, ending in "More under Why" when some are left out; *Why* shows all the reasons. Larger radios show everything. |
| Flight data | Minutes and seconds of rate flight measured, and whether measuring is happening now (collecting) or not (paused). |
| Response | How fast the heli turns compared with the rate the stick asks for, for example "53% faster than asked". "Needs more flying" shows how much data is still needed; "Too uneven to judge" means the response varies too much. |
| Stops | How much the heli bounces back after you centre the stick, as a share of the turn rate. Needs 10 stops. |
| Suggested changes | Up to three changes, each named by the page and setting to change and in the units that page shows, for example *PIDs > Roll > F: 100 -> 80* and *Rates > Roll > Rate: 720 -> 900*. |
| Why | The reason for each change, and a fact worth knowing when there is room (for example how much faster the heli turns at high collective). |
| Tool button | Clears the measurements after asking to confirm. |

The suggestions follow these rules:

- **Turns faster or slower than asked** (more than 15% off): change F and the rates by the same amount in
  opposite directions, so the stick feel stays the same but the heli flies the rate you ask for. One step
  changes F by at most 20%. With Actual, Quick and Rotorflight rates the page gives the exact rate values;
  with the other rate types it gives a percentage. An axis with F set to 0 (often the tail) gets no F advice.
- **Full stick asks for more rate than the heli reaches** (roll and pitch), with the cyclic at its limit: lower
  the rates to what the heli reaches.
- **Stops bounce back 12% or more**: if the I-term pushes back, lower *Advanced > PID Controller > Iterm Relax
  Cutoff* by 20%. If F does not match yet, fix F first. Otherwise the controller is barely braking the stop:
  raise P by 20% (or add B).

## Source

[Page implementation](../../../src/rfsuite/app/pages/tune_advisor.lua). Menu conditions come from `app/tool.lua`.
Firmware side: `src/main/flight/tune_advisor.c` in rotorflight-firmware.
