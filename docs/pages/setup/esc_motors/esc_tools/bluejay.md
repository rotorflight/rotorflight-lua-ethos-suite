---
title: Bluejay
sidebar_label: Bluejay
sidebar_position: 40
---

# Bluejay

Setup -> ESC & Motors -> Forward Programming -> Bluejay.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *Bluejay*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 1).

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.

## What Save writes

Save writes the ESC's whole 66-byte parameter block, and only the rows you moved
are changed in it.

The block carries more than this page has a row for: vendor bytes, reserved flags
and legacy encodings that a configurator app wrote. Those are read back from the
ESC and sent straight back out again, byte for byte, so a save that changed one
row leaves every other byte exactly as the ESC reported it. A row the page *does*
show is handled the same way — if you did not move it, its byte goes back
unchanged, even where the number on screen is not a direct copy of the byte.

Two rows are one decision: *96→48 % Threshold* must not sit above
*48→24 % Threshold*. Lowering *48→24 %* pulls *96→48 %* down with it, and
*96→48 %* is capped at *48→24 %*.

The bytes beyond those 66 are the flight controller's own business and are left
alone.

## Choosing the ESC

If the flight controller reports more than one ESC, this page lists them and you
pick the one to program. The list has one entry per ESC that is actually there.

With a single ESC there is nothing to choose, so the list is skipped and the page
goes straight to that ESC.

If the flight controller does not say how many ESCs there are, all four entries are
listed and only *ESC 1* can be opened. The page does not guess.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
