---
title: Hobbywing V5
sidebar_label: Hobbywing V5
sidebar_position: 10
---

# Hobbywing V5

Setup -> ESC & Motors -> Forward Programming -> Hobbywing V5.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *Hobbywing V5*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 3).

## Settings

Every row on this page is written **to the ESC itself** over MSP. Which rows exist
is decided by the ESC that answers, not by a setting you choose here.

| Setting | What it does | Shown on |
| --- | --- | --- |
| *Flight Mode* | *Startup* / *Normal* / *Startup and Normal* | all but HW1128, HW1132 |
| *Lipo Cell Count* | Cell count the ESC may use. The list follows the model: *Auto* + 3S..14S on most, *Auto* + 3S..8S on some, *Auto* + 6S..14S in even steps on HW1104, *Auto* + 2S..4S on HW1128. | all |
| *Voltage Cutoff Type* | *Disabled* / *Low Voltage* / *RC Cutoff* | all |
| *Cutoff Voltage* | Threshold for the two types above. The list follows the model. | all |
| *BEC Voltage* | Output voltage of the BEC. The ceiling follows the model - up to 12.0 V on some. | all but **OPTO**, HW1128 |
| *Startup Time* | Spin-up time, **4 to 25** seconds | all but HW1128, HW1132 |
| *Response Time* | How quickly the ESC answers throttle changes | **HW1132 only** |
| *Governor P-Gain* | Proportional strength of the RPM governor, **0 to 9** | all but HW1128, HW1132 |
| *Governor I-Gain* | Integral strength, **0 to 9** | all but HW1128, HW1132 |
| *Auto Restart* | Retry window after a throttle undervolt, **0 to 90** | all but HW1128, HW1132 |
| *Restart Time* | How long a retry takes to spin back up - 1s, 1.5s, 2s, 2.5s or 3s | all but HW1128, HW1132 |
| *Brake Type* | *Disabled* / *Normal* / *Proportional* / *Reverse*. HW1128 drops *Proportional*, and its BEC-less rows differ again. | all but HW1132 |
| *Brake Force* | Brake strength, **0 to 100 %** | all but HW1132 |
| *Motor Timing* | Commutation advance, **0 to 30** | all |
| *Rotation Direction* | *Forward* / *Reverse*, plus *4D* and *4D Reverse* on HW1128 | all |
| *Active Freewheel* | The motor is driven freely above the throttle threshold | all |
| *Startup Power* | How hard the motor is kicked at start-up, *1* to *7* | all |

There are four row sets. Most models get the full list; **HW1132** gets a short one
with *Response Time* and without the governor rows; **HW1128** gets another, without
*BEC Voltage*; and an **OPTO** model gets the full list **without** *BEC Voltage*.

A row that is not listed for your model is **not built at all** - the page does not
show a disabled row for a setting the ESC does not have. *BEC Voltage* on an OPTO
model is the common case: an OPTO ESC has no BEC, so there is no voltage to set.

### What Save does

Save writes the whole block to the ESC in one go, and then also sends the flight
controller an **EEPROM write** to commit its own settings.

Only the rows you moved are taken from the page. A row you did not touch is written
back exactly as the ESC reported it, so saving one setting does not quietly reset
another.


## OPTO models

An OPTO ESC has **no BEC**, so there is no *BEC Voltage* row to set. The page notices
on its own, from the ESC that answers - there is nothing to select, and nothing to
switch on.

Every other row stays exactly where it was. Behind the scenes the missing BEC byte
shifts the fields that follow it, so the page reads and writes the layout that
belongs to your model; on the screen you only see the BEC row disappear.

`OPTO` is looked for in all three places the block names the ESC - the firmware
string, and both copies of the model string - so it is found whichever of them the
manufacturer put it in.

### Startup Time

The row reads **4 to 25 seconds**, but the ESC counts from 0 - it reports **0 to 21**
for the same range. The page does not correct for this yet, so an ESC set to its
shortest start-up currently shows `0s` on a row that begins at `4`.

### Active Freewheel

*Enabled* is **0**, *Disabled* is **1** - the same as EdgeTX. The byte is passed to
the ESC exactly as the ESC reported it, in both directions.

> If your ESC shows the wrong sense here, that is not this page: check whether the
> ESC's own firmware reverses the bit, and report it with the firmware version. The
> flight controller does not interpret this block at all - it compares it byte for
> byte and passes it on.

## Choosing the ESC

If the flight controller reports more than one ESC, this page lists them and you
pick the one to program. The list has one entry per ESC that is actually there.

With a single ESC there is nothing to choose, so the list is skipped and the page
goes straight to that ESC.

If the flight controller does not say how many ESCs there are, all four entries are
listed and only *ESC 1* can be opened. The page does not guess.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
