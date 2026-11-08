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
| PID loop speed | Configures PID loop speed. The four choices are the board's gyro sample rate divided by 1, 2, 3 and 4, shown in kHz with the decimals they need (for example 3.2, 1.6, 1.07 and 0.8 kHz on a 3.2 kHz gyro). |

## Notes

- Saving changes on this page reboots the flight controller.
- While the model is armed, or while its armed state is *unknown after having been armed* (see [Dashboard controls](../../dashboard/controls.md)), Save stays greyed out. The reboot after a save is skipped in that state.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
