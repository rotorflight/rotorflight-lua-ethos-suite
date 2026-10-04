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

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## OPTO models

An OPTO ESC has **no BEC**, so it has no *BEC Voltage* row - and because that byte is
missing from its block, **every field after it moves up one place**. The page works
this out from the ESC itself; there is nothing to select.

| | With a BEC | OPTO |
| --- | --- | --- |
| *BEC Voltage* row | shown | **hidden** |
| *Startup Time* is item | 6 | 5 |
| *Active Freewheel* is item | 15 | 14 |

`OPTO` is looked for in all three places the block names the ESC - the firmware
string, and both copies of the model string - so it is found whichever of them the
manufacturer put it in.

### Startup Time

The row reads **4 to 25 seconds**. An ESC reports **0 to 21** for the same range, and
the page converts: it adds four on the way in and takes four off again on the way
out, so a save writes back the byte the ESC sent.

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
