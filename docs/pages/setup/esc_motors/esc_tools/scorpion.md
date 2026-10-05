---
title: Scorpion
sidebar_label: Scorpion
sidebar_position: 70
---

# Scorpion

Setup -> ESC & Motors -> Forward Programming -> Scorpion.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *Scorpion*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 4).

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.

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
