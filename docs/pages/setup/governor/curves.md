---
title: Bypass Curve
sidebar_label: Bypass Curve
sidebar_position: 40
---

# Bypass Curve

Setup -> Governor -> Bypass Curve page.

## Where to find it

*Configuration* → *Setup* → *Governor* → *Bypass Curve*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Written to the flight controller EEPROM on Save. The flight controller takes these settings into the running governor only at start-up, so a save that changes one of them restarts the flight controller; without the restart the new value would be stored but not flown until the next power-up (#2780). A save that changes nothing does not restart. The restart is skipped while the model is armed.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
