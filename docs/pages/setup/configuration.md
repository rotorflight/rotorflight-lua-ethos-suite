---
title: Configuration
sidebar_label: Configuration
sidebar_position: 10
---

# Configuration

Configuration page. Loaded on demand (plain loadfile) only when the user opens Configuration -> Setup -> Configuration -- see app/tool.lua.

## Where to find it

*Configuration* → *Setup* → *Configuration*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| GPS | Configures GPS. |
| LED_STRIP | Configures LED_STRIP. |
| CMS | Configures CMS. |
| Craft name | Configures Craft name. |
| PID loop speed | Configures PID loop speed. |

## Notes

- Saving changes on this page reboots the flight controller.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
