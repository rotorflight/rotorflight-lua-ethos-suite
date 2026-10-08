---
title: Voltage
sidebar_label: Voltage
sidebar_position: 10
---

# Voltage

Callouts for the three supply rails the suite watches: the flight pack, the BEC and the receiver.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Voltage*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Low voltage alert* | Calls out the pack when it drops below the warning cell voltage the flight controller reports. |
| *Repeat interval* | Seconds between repeats of a standing low-voltage callout. Range 5 to 120, default 10. Greyed out while *Low voltage alert* is off. |
| *BEC voltage alert* | Calls out when the BEC supply falls below its threshold. |
| *BEC threshold* | The voltage that counts as low, in volts to one decimal. Range 3.0 to 15.0, default 6.5. Greyed out while *BEC voltage alert* is off. |
| *RX voltage alert* | Calls out when the receiver supply falls below its threshold. |
| *RX threshold* | The voltage that counts as low, in volts to one decimal. Range 3.0 to 15.0, default 7.4. Greyed out while *RX voltage alert* is off. |

## Notes

- Changes are saved to the radio's settings store, not to the flight controller. Nothing here
  is written to flight controller EEPROM.
- A pack reading below 1 V in total is ignored, so a bench run on USB power with no pack
  attached does not sound the low-voltage alarm on noise.
- Each threshold belongs to the toggle above it and is greyed out while that toggle is off, so
  the stored value is never mistaken for an active one.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*