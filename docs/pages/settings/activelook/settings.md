---
title: Settings
sidebar_label: Settings
sidebar_position: 10
---

# Settings

Settings -> ActiveLook -> Settings.

## Where to find it

*System* → *Settings* → *ActiveLook* → *Settings*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| ETHOS Glasses menu | Registers the ETHOS Model → Glasses menu at startup (default off). Only shown on ETHOS 26.2.0 or newer when the firmware provides `system.registerGlasses()`. Changing it in either direction shows a restart reminder dialog; there is no permanent restart note. Save and restart the transmitter to apply either direction. |
| Rotorflight ActiveLook | Enables the Rotorflight glasses display. Disabled while the visible ETHOS Glasses menu switch is off; existing display preferences are retained. If the ETHOS Glasses menu switch is unavailable, this restriction does not apply. |
| Hide Display | Configures Hide Display. |
| Offset X | Configures Offset X. |
| Offset Y | Configures Offset Y. |

## Notes

- Switching Rotorflight ActiveLook on shows a setup reminder: in Model → Glasses → Screen, select the Full-Screen layout and assign Rotorflight ActiveLook. Confirming the reminder does not configure ETHOS or save the page; use Save as usual. Switching off or opening an already enabled page shows no reminder.
- Changes are stored in `[activelook]` in `SCRIPTS:/rfsuite.user/settings.ini` on Save. They are RFSuite settings, not flight controller EEPROM settings.
- The menu preference defaults to off when absent; an existing saved choice is preserved.
- `register_glasses` controls startup menu registration separately from the Rotorflight ActiveLook display preference. Disabling it leaves the icon visible until a transmitter restart. Another installed script can still register the menu.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*

Turning ActiveLook off clears its current glasses display. Geometry or settings changes also clear the old layout before rebuilding it.
