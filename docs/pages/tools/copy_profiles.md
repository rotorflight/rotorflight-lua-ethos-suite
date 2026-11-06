---
title: Copy Profiles
sidebar_label: Copy Profiles
sidebar_position: 10
---

# Copy Profiles

Tools -> Copy Profiles page.

## Where to find it

*System* → *Tools* → *Copy Profiles*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Profile Type | Configures Profile Type. |
| Source Profile | Configures Source Profile. |
| Dest. Profile | Configures Dest. Profile. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- The Source and Dest. Profile lists offer the profiles the flight controller has for the chosen type: PID profiles or rate profiles. Save stays off until the flight controller has reported its counts, and while source and destination are the same profile. If the counts cannot be read, the page says so; Reload asks again.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
