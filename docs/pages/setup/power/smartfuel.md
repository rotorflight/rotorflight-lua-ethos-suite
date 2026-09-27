---
title: SmartFuel
sidebar_label: SmartFuel
sidebar_position: 40
---

# SmartFuel

Setup -> Power -> SmartFuel page.

## Where to find it

*Configuration* → *Setup* → *Power* → *SmartFuel*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Smart Fuel | Configures Smart Fuel. |
| Voltage Drop Rate | Configures Voltage Drop Rate. Range: 0 to 250 mV/s. Default: 10 mV/s. |
| Charge Drop Rate | Configures Charge Drop Rate. Range: 0 to 250 %/s. Default: 50 %/s. |
| Sag Gain | Configures Sag Gain. Range: 0 to 100 %. Default: 40 %. |
| Power Type | Configures Power Type. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
