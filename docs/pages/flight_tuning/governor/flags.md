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
| TTA Banking | Electric governor with a motorised tail: hold the headspeed TTA adds above the target and wind it down as the yaw stick comes back. Limit, rate and release are on [Tail Rotor](../advanced/tail_rotor.md). Needs MSP API 12.11 (rotorflight-firmware#606); greyed out on older firmware. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
