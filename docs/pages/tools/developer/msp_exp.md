---
title: MSP Exp.
sidebar_label: MSP Exp.
sidebar_position: 20
---

# MSP Exp.

Developer -> MSP Exp..

## Where to find it

*System* → *Tools* → *Developer* → *MSP Exp.*

Greyed out until the flight controller answers. Read-only while the model is armed. Hidden until *System* → *Settings* → *Developer* mode is active.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Leaving the page with *Menu*, or closing the tool while its progress dialog is
  up, no longer writes to a form that Ethos has already stopped updating. The
  dialog is still closed; only the header refocus it used to attempt afterwards
  is skipped, because there is nothing left to refocus. (#2383,
  `src/rfsuite/app/pages/developer_msp_exp.lua`)

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
