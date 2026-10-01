---
title: Settings
sidebar_label: Settings
sidebar_position: 20
---

# Settings

Settings -> Dashboard -> Settings. Mirrors the original suite's dashboard-settings page shape: a tile grid of dashboard themes that expose a configure.lua, with each tile opening that theme's own configuration form.

## Where to find it

*System* → *Settings* → *Dashboard* → *Settings*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- The theme configuration tile is named **Bastion** and loads from
  `widgets/dashboard/themes/bastion`. Previously saved limits remain under
  `dashboard.aegis`; the folder rename does not reset these settings. Install
  the matching branch routing and restart the scripts after updating.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
