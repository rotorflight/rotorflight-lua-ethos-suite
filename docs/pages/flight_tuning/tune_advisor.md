---
title: Tune Advisor
sidebar_label: Tune Advisor
sidebar_position: 30
---

# Tune Advisor

While you fly in rate mode, the flight controller measures how the heli answers the sticks. Each time you
disarm, the radio saves that flight's measurements. This page combines your last flights and suggests one change
at a time for each axis. Press *Save* to write the suggested changes for the shown axis to the flight controller,
or make them yourself on *PIDs*, *Rates* or *PID Controller*. Then fly again and come back.

The flight controller counts only rate flight while spooled up and airborne, with the heli moving on some axis.
Time in Angle, Horizon, Trainer, Altitude hold, Rescue, GPS rescue or failsafe is left out. The page combines up
to the last 5 flights flown with the same tune as the newest one: a flight before a change to P, F, B, Iterm
Relax Cutoff or the rates on that axis is left out, because the advice is worked out against the tune you fly
now. A useful set is about ten seconds of rolls, flips and pirouettes with the stick centred after each one,
which one flight may or may not give.

Each time you disarm, the background task reads all three axes from the flight controller, saves them as one
flight, then clears the flight controller so the next flight is measured on its own. This happens whether or not
this page is open. The flights are kept in `LOGS:/rfsuite/tune/<model>/history.csv` on the radio's SD card, one
row per axis, newest last; only the last 5 flights are kept. `<model>` is the same flight controller ID that
names the flight log folders, and a `logs.ini` beside the history holds the model name. A flight without rate
flight is not saved. A disarm while the link is down is saved once the radio reconnects, provided the flight
controller has not been powered off in between. Combining flights adds up the counts and averages each
measurement weighted by how much data it came from; the flight controller weights its own figures slightly
differently, so the combined response is a close estimate rather than exact, while the stop figures combine
exactly.

## Where to find it

*Configuration* → *Flight Tuning* → *Tune Advisor*

Greyed out until the flight controller answers. The page works from the flights saved for the connected model,
and updates when you disarm while it is open; through a link loss it keeps showing them. On opening (and on
Reload) the page asks the flight controller once whether its firmware has the Tune Advisor: firmware from before
it shows "Needs newer firmware".

## Settings

| Line | What it shows |
| --- | --- |
| Axis | Roll, Pitch or Yaw. Everything below is for the chosen axis. |
| Changes / Why | Only on 480-pixel-wide radios (X18, X18R, X10 and similar), beside Axis. *Changes* shows the suggested changes and as many reasons as fit, ending in "More under Why" when some are left out; *Why* shows all the reasons. Larger radios show everything. |
| Flight data | Minutes and seconds of rate flight in the flights combined, and how many of the last 5 that is, for example "2m 12s, 3/5 flights". |
| Response | How fast the heli turns compared with the rate the stick asks for, for example "53% faster than asked". "Needs more flying" shows how much data is still needed; "Too uneven to judge" means the response varies too much. |
| Stops | How much the heli bounces back after you centre the stick, as a share of the turn rate. Needs 10 stops. |
| Suggested changes | Up to three changes, each named by the page and setting to change and in the units that page shows, for example *PIDs > Roll > F: 100 -> 80* and *Rates > Roll > Rate: 720 -> 900*. When there is something *Save* can write, a last line says so. After they are written, this shows "Changes saved to the flight controller" until the next flight is saved. |
| Why | The reason for each change, and a fact worth knowing when there is room (for example how much faster the heli turns at high collective). |
| Save button | Writes the suggested changes for the shown axis to the flight controller. Enabled only while connected, disarmed and with a change it can write. See *Applying the changes* below. |
| Tool button | Erases this model's saved flights, and the flight controller's current measurements, after asking to confirm. |

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

## Applying the changes

*Save* first lists the changes and asks you to confirm. It then shows each step as it runs:

1. **Reading current settings**: reads PIDs, PID Controller and Rates from the flight controller. A failed or short
   read stops here and nothing is changed.
2. It checks that the flight controller still holds the tune these flights were flown with: the same PID and rate
   profile, and the same P, F, B, Iterm Relax Cutoff, rate type and rates on that axis. If anything differs (you
   changed it by hand, switched profile, or already applied this advice), it stops and nothing is changed: fly
   again on the current settings. It also stops if a new value is out of range or the heli is armed.
3. **Writing changes**: writes only the settings that change; every other setting is written back as it was read.
4. **Saving to flight controller**: commits them so they survive a restart.
5. **Checking saved settings**: reads them back and confirms the new values.

With Betaflight, Raceflight or KISS rates the page can only give the rate change as a percentage, so *Save* does not
write it, and does not write the F change that goes with it either: F on its own would change the stick feel. Make
both changes by hand, or switch to Actual, Quick or Rotorflight rates.

If writing fails, nothing is saved and restarting the flight controller undoes any part already sent. If the
read-back does not confirm the change, check the values on *PIDs*, *Rates* and *PID Controller*.

The saved flights are kept. The next flight is on the new tune, so the page starts again from it and leaves the
older flights out. Each change written is added to `changes.csv` beside the flight history (date, axis, setting,
old value, new value), so you can always see what the advisor changed and set it back by hand. *Clear*
does not erase it.

## Adjustment functions

In-flight adjustments (*Setup* → *Controls* → *Adjustments*) can change the same settings the advisor measures
and writes: P, F, B, the rates and Iterm Relax Cutoff per axis, and the PID and rate profile. The firmware
applies an adjustment straight away and saves it when you disarm.

- **Adjusting during a flight mixes two tunes.** The flight controller checks the tune only when you arm, so a
  flight where you adjusted one of these settings (or switched profile) is measured partly on the old value and
  saved as if flown on the value you ended on. Leave these adjustments alone while collecting flights for the
  advisor. If you did use one, press *Clear* and fly again.
- **Adjusting between flights is fine.** A *Stepped* adjustment (a switch) is saved at disarm, so the next flight is on
  a new tune and the advisor starts again from it, as it does after *Save*.
- **A *Mapped* adjustment (a knob or slider) overrides Apply.** It sets the value from the knob's position: once the
  knob moves, and at every power-up while its range is enabled, the value goes back to what the knob says. A value
  written by *Save* then lasts only until that happens. Before applying advice to a setting, set its *Mapped*
  adjustment's *Type* to *Off*, or leave the knob where it gives the new value.
- *Save* checks the profiles and values at the moment it writes, so an adjustment or profile switch made since the
  flights stops it with nothing changed.

## Source

[Page implementation](../../../src/rfsuite/app/pages/tune_advisor.lua). Menu conditions come from `app/tool.lua`.
Firmware side: `src/main/flight/tune_advisor.c` in rotorflight-firmware.
