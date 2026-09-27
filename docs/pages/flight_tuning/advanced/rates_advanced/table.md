---
title: Rate Table
sidebar_label: Rate Table
sidebar_position: 30
---

# Rate Table

Rate Table editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Rates Advanced -> Rate Table -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Rates* → *Rate Table*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Rate Type | Configures Rate Type. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Parameters are scoped to the currently active Rate profile.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
