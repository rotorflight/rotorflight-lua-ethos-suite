---
title: Preferences
sidebar_label: Preferences
sidebar_position: 50
---

# Preferences

Setup -> Power -> Preferences page.

## Where to find it

*Configuration* → *Setup* → *Power* → *Preferences*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| ESC Current Limit | The current limit of the speed controller, in whole amps. 0 means not set. Used by the dashboard's ESC load box. |

## Notes

- AM32, Scorpion and YGE speed controllers store their own current limit. Opening their page under *ESC & Motors* → *Forward Programming* fills this value in automatically. Other speed controllers have no such field: type the limit in here.
- With no limit set, an ESC load box shows `--` instead of a percentage.
- Changes are stored on the radio for the connected flight controller when you press Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
