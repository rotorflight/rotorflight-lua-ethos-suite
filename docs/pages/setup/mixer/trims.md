---
title: Trims
sidebar_label: Trims
sidebar_position: 40
---

# Trims

Mixer -> Trims page. Edits MIXER_CONFIG swash trims and the tail trim/idle field.

## Where to find it

*Configuration* → *Setup* → *Mixer* → *Trims*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- The Tool button is disabled until the page has loaded its values. In addition, confirming the override dialog before values are read is prevented as defence in depth.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
