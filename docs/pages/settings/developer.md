---
title: Developer
sidebar_label: Developer
sidebar_position: 50
---

# Developer

Developer settings and logging toggles.

## Where to find it

*System* → *Settings* → *Developer*

Always available offline without an active flight controller connection. Read-only while the model is armed. Hidden until *System* → *Settings* → *Developer* mode is active.

## Settings

| Setting | What it does |
| --- | --- |
| Debug logs | Configures Debug logs. |
| Log MSP data | Configures Log MSP data. |
| Memory logs | Logs memory usage on menu/page changes and when closing the tool. |
| Simulated API version | Configures Simulated API version. |

## Notes

- The Rotorflight menu is available on the first tool launch with memory logging either on or off. Disabling ActiveLook does not require opening the tool twice.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
