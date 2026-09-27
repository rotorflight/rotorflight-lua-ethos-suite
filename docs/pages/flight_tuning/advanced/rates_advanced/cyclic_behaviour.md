---
title: Cyclic Behaviour
sidebar_label: Cyclic Behaviour
sidebar_position: 20
---

# Cyclic Behaviour

Cyclic Behaviour editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Rates Advanced -> Cyclic Behaviour -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Rates* → *Cyclic Behaviour*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Cyclic Ring | Configures Cyclic Ring. |
| Cyclic Polarity | Configures Cyclic Polarity. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Parameters are scoped to the currently active Rate profile.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
