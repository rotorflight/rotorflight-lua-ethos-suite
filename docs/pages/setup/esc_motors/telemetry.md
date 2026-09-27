---
title: Telemetry
sidebar_label: Telemetry
sidebar_position: 20
---

# Telemetry

Setup -> ESC & Motors -> Telemetry page.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Telemetry*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Telemetry Protocol | Configures Telemetry Protocol. |
| Half Duplex | Configures Half Duplex. |
| Pin Swap | Configures Pin Swap. |
| Voltage Correction | Configures Voltage Correction. Range: -99 to 125 %. Default: 1 %. |
| Current Correction | Configures Current Correction. Range: -99 to 125 %. Default: 1 %. |
| Consumption Correction | Configures Consumption Correction. Range: -99 to 125 %. Default: 1 %. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
