---
title: Failsafe
sidebar_label: Failsafe
sidebar_position: 30
---

# Failsafe

Controls -> Failsafe page. Edits MSP_RXFAIL_CONFIG channel fallback mode/value pairs.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Failsafe*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- The page lists one row per channel the flight controller reports: 16 rows on CRSF (up to AUX 11),
  18 on other links (up to AUX 13). Channels the board does not have are not shown.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
