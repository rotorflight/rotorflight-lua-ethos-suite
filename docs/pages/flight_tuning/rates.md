---
title: Rates
sidebar_label: Rates
sidebar_position: 20
---

# Rates

Rates profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Rates -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Rates*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Roll RC Rate | Configures Roll RC Rate. |
| Roll rcRate | Configures Roll rcRate. |
| Pitch RC Rate | Configures Pitch RC Rate. |
| Pitch rcRate | Configures Pitch rcRate. |
| Yaw RC Rate | Configures Yaw RC Rate. |
| Yaw rcRate | Configures Yaw rcRate. |
| Collective RC Rate | Configures Collective RC Rate. |
| Collective rcRate | Configures Collective rcRate. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Parameters are scoped to the currently active Rate profile.
- The largest value of each field depends on the rate table: the firmware keeps a
  limit per table and field, and the page does not go above it. A value saved above
  the limit before the firmware is updated is cut to the limit at the next boot.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
