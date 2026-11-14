---
title: Telemetry
sidebar_label: Telemetry
sidebar_position: 30
---

# Telemetry

Setup -> ESC & Motors -> Telemetry page.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Telemetry*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Telemetry Protocol | The ESC telemetry protocol on the ESC telemetry UART. The list follows the flight controller's API version: *SRXL2* and *Goosky* appear from API 12.10. *RECORD* is on every API, with a different value before and from 12.10 (14 and 15), so the page sends the value the board's API expects. *Goosky* is an alias of *BLHELI32*: Goosky ESCs run AM32 firmware and send BLHeli32 telemetry, so either entry works for them. |
| Half Duplex | Configures Half Duplex. |
| Pin Swap | Configures Pin Swap. |
| Voltage Correction | Configures Voltage Correction. Range: -99 to 125 %. Default: 1 %. |
| Current Correction | Configures Current Correction. Range: -99 to 125 %. Default: 1 %. |
| Consumption Correction | Configures Consumption Correction. Range: -99 to 125 %. Default: 1 %. |

## Notes

- Until the flight controller has reported its API version, only the protocols common to
  every version are listed. The page closes itself if the reported version changes while
  it is open; reopen it to get the list for that version.
- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
