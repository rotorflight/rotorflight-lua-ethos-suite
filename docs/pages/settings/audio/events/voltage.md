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
| *Voltage callout* | What the low-voltage callout says once it fires: *Alert only* (the default, no number), *Pack voltage* (e.g. "22.4 volts") or *Cell voltage* (the average cell, e.g. "3.65 volts"). Greyed out while *Low voltage alert* is off. |
| *Hold time* | Seconds the pack must stay below the warning cell voltage before the alert fires, 0.0 to 10.0, default 2.0. This is what filters a momentary voltage sag. Greyed out while *Low voltage alert* is off. |
| *Repeat interval* | Seconds between repeats of a standing low-voltage callout. Range 5 to 120, default 10. Greyed out while *Low voltage alert* is off. |
| *BEC voltage alert* | Calls out when the BEC supply falls below its threshold. |
| *BEC threshold* | The voltage that counts as low, in volts to one decimal. Range 3.0 to 15.0, default 6.5. Greyed out while *BEC voltage alert* is off. |
| *RX voltage alert* | Calls out when the receiver supply falls below its threshold. |
| *RX threshold* | The voltage that counts as low, in volts to one decimal. Range 3.0 to 15.0, default 7.4. Greyed out while *RX voltage alert* is off. |

## Notes

- Changes are saved to the radio's settings store, not to the flight controller. Nothing here
  is written to flight controller EEPROM.
- The low-voltage alert waits out voltage sag. An aggressive 3D maneuver pulls the pack below
  the warning cell voltage for a fraction of a second and it recovers immediately; the alert
  only fires once the reading has stayed below the threshold for *Hold time*. Set *Hold time*
  to 0 to alarm on the first low reading, as earlier releases did.
- *Cell voltage* is the average cell: the pack voltage divided by the configured cell count,
  the same value the flight controller broadcasts as *Cell Voltage*. There is no separate
  lowest-cell sensor to read.
- A pack reading below 1 V in total is ignored, so a bench run on USB power with no pack
  attached does not sound the low-voltage alarm on noise.
- Each threshold belongs to the toggle above it and is greyed out while that toggle is off, so
  the stored value is never mistaken for an active one.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*