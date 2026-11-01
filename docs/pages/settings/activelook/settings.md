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
| Rotorflight ActiveLook | Configures Rotorflight ActiveLook. |
| Hide Display | Configures Hide Display. |
| Offset X | Configures Offset X. |
| Offset Y | Configures Offset Y. |

## Notes

- Changes are stored in `[activelook]` in `SCRIPTS:/rfsuite.user/settings.ini` on Save. They are RFSuite settings, not flight controller EEPROM settings.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*

Turning ActiveLook off clears its current glasses display. Geometry or settings changes also clear the old layout before rebuilding it.
