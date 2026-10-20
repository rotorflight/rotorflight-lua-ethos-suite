---
title: Low Fuel
sidebar_label: Low Fuel
sidebar_position: 50
---

# Low Fuel

Settings -> ActiveLook -> Low Fuel.

## Where to find it

*System* → *Settings* → *ActiveLook* → *Low Fuel*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Low Fuel Warning | Shows a short LOW FUEL message over the Inflight layout when the smart fuel level reaches the *Consumption Warning %* from the battery settings. Off by default. |
| Warning Duration | How long the LOW FUEL message stays on the display, from 3 to 30 seconds (default 8). It is shown indented below Low Fuel Warning and is greyed out, so it cannot be changed, while the warning is off. |
| Repeats | How many times the message is shown in total while the pack stays low, from 1 to 10 (default 1, shown once). The pause between two shows is as long as the Warning Duration. Greyed out while the warning is off. |
| Symbol | Shows the fuel-pump symbol for Nitro (image 11) or the battery symbol for Electric (image 21) beside the remaining percentage (default on). Turn it off if the active glasses configuration shows no symbol or a different image. Greyed out while the warning is off. |

## Preview

Opening this page previews the LOW FUEL warning on the connected glasses,
just like the Preflight, Inflight and Postflight pages preview their layouts.
The preview uses current telemetry and the saved Symbol setting. Changes to
Symbol take effect on the glasses only after Save. The preview stays visible
while the page is open, even if Low Fuel Warning is off or the battery is not low;
Warning Duration and Repeats do not limit this preview. Save applies changed
settings and keeps the preview active. Leaving the page restores the automatic
flight-state display. ActiveLook must be enabled and its display switch must
allow the display.

## Notes

- Changes are stored in `[activelook]` in `SCRIPTS:/rfsuite.user/settings.ini` on Save. They are RFSuite settings, not flight controller EEPROM settings.
- The symbol is drawn as a bitmap command inside the text layout, so layout replacement also removes it. The selected image (11 or 21) must exist in the glasses' active configuration; no image is uploaded. Its vertical position uses the same Y coordinate as the percentage text.
- What the overlay shows and when it appears is described in [ActiveLook](../../../dashboard/activelook.md).

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*

The displayed percentage is the current Smart Fuel value, updated throughout the warning. No reserve is added back. Missing readings show a dash. Smart Fuel is limited to 0% by the central calculation once the consumption-warning reserve is reached.

When Symbol is enabled, the selected image blinks slowly (one second on, one second off), including in the settings preview. The percentage stays in the same position while the icon is hidden. The existing wakeup handles timing; redraws occur only when the blink state or displayed values change.

The warning symbol uses the same engine-type detection as the dashboard and audio alerts: the Smart Fuel model type selects Electric or Nitro explicitly; Auto uses the configured battery cell count/capacity. Both symbols blink at the same rate.
