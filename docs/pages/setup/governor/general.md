---
title: General
sidebar_label: General
sidebar_position: 10
---

# General

Setup -> Governor -> General page.

## Where to find it

*Configuration* → *Setup* → *Governor* → *General*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Mode | Configures Mode. Shows OFF while the flight controller's GOVERNOR feature is off, even when a mode is stored; the stored mode comes back when the feature is on. Picking a mode turns the feature on, and OFF turns it off. |
| Throttle type | Configures Throttle type. |
| Idle throttle | Configures Idle throttle. Range: 0 to 250 %. Default: 0 %. |
| Auto throttle | Configures Auto throttle. Range: 0 to 250 %. Default: 0 %. |
| Handover throttle% | Configures Handover throttle%. Range: 10 to 100 %. Default: 25 %. |
| Throttle hold timeout | Configures Throttle hold timeout. Range: 0 to 250 s. Default: 5 s. |
| Autorotation Timeout | Configures Autorotation Timeout. Range: 0 to 250 s. Default: 0 s. |

## Notes

- Written to the flight controller EEPROM on Save. The flight controller takes these settings into the running governor only at start-up, so a save that changes one of them restarts the flight controller; without the restart the new value would be stored but not flown until the next power-up (#2780). A save that changes nothing does not restart. The restart is skipped while the model is armed. Turning the GOVERNOR feature on or off restarts it too (#2649).

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
