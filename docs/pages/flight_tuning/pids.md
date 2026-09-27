---
title: PIDs
sidebar_label: PIDs
sidebar_position: 10
---

# PIDs

PID editor page. Loaded on demand (plain loadfile) only when the user opens "PIDs" from the system tool's main menu -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *PIDs*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Roll P | Configures Roll P. |
| Roll I | Configures Roll I. |
| Roll D | Configures Roll D. |
| Roll F | Configures Roll F. |
| Roll O | Configures Roll O. |
| Roll B | Configures Roll B. |
| Pitch P | Configures Pitch P. |
| Pitch I | Configures Pitch I. |
| Pitch D | Configures Pitch D. |
| Pitch F | Configures Pitch F. |
| Pitch O | Configures Pitch O. |
| Pitch B | Configures Pitch B. |
| Yaw P | Configures Yaw P. |
| Yaw I | Configures Yaw I. |
| Yaw D | Configures Yaw D. |
| Yaw F | Configures Yaw F. |
| Yaw B | Configures Yaw B. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Parameters are scoped to the currently active PID profile.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
