---
title: Tail Rotor
sidebar_label: Tail Rotor
sidebar_position: 60
---

# Tail Rotor

Tail Rotor profile editor page. Loaded on demand (plain loadfile) only when the user opens "Tail Rotor" from the system tool's main menu -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Advanced* → *Tail Rotor*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Yaw Precomp Cutoff | Configures Yaw Precomp Cutoff. Range: 0 to 250 Hz. Default: 5 Hz. |
| Yaw Cyclic FF Gain | Configures Yaw Cyclic FF Gain. Range: 0 to 250. Default: 0. |
| Yaw Collective FF Gain | Configures Yaw Collective FF Gain. Range: 0 to 250. Default: 30. |
| Yaw Stop Gain (CW) | Configures Yaw Stop Gain (CW). Range: 25 to 250. Default: 120. |
| Yaw Stop Gain (CCW) | Configures Yaw Stop Gain (CCW). Range: 25 to 250. Default: 80. |
| Inertia Precomp (Gain) | Configures Inertia Precomp (Gain). Range: 0 to 250. Default: 0. |
| Inertia Precomp (Cutoff) | Configures Inertia Precomp (Cutoff). Range: 0 to 250 Hz. Default: 25 Hz. |
| Tail Torque Assist (Gain) | Configures Tail Torque Assist (Gain). Range: 0 to 250. Default: 0. |
| Tail Torque Assist (Limit) | Configures Tail Torque Assist (Limit). Range: 0 to 250 %. Default: 20 %. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
