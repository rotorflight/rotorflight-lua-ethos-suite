---
title: FLYROTOR
sidebar_label: FLYROTOR
sidebar_position: 50
---

# FLYROTOR

Setup -> ESC & Motors -> Forward Programming -> FlyRotor.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *FLYROTOR*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 10).

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## What Save writes

Save writes the ESC's whole 56-byte parameter block. The flight controller fills
that block one page at a time — an identification page, then *Basic*, *Advanced*
and *Other* — and hands all of it over at once, so the block is written whole
rather than field by field.

Two consequences worth knowing:

- A row you did not move comes back as the byte the ESC reported. The suite
  re-encodes every field from what it read, and that round trip is exact — every
  one of the 56 bytes survives all 256 of its values unchanged — so a save cannot
  quietly move a setting it has no row for.
- If the parameters could not be read **in full**, the page refuses to open rather
  than showing you an editor built on a partly empty block. A short read used to
  open an editor whose unseen settings read as zero, and saving from it wrote those
  zeros to the ESC — soft start, the governor terms and the motor limits among
  them. The page now reports the read as failed instead.

*Current Gain* is stored on the ESC shifted by 20, so that its −20…+20 range keeps
the stored byte non-negative. The page shows the real value; the shift is the
ESC's, not yours.

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
