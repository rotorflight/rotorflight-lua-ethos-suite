---
title: Behaviour
sidebar_label: Behaviour
sidebar_position: 20
---

# Behaviour

Governor "Flags" profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Governor -> Flags -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Governor* → *Behaviour*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Fallback Precomp | Configures Fallback Precomp. |
| PID Spoolup | Configures PID Spoolup. |
| Voltage Comp | Configures Voltage Comp. |
| Dyn Min Throttle | Configures Dyn Min Throttle. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
