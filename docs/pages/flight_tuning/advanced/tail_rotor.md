---
title: Tail Rotor
sidebar_label: Tail Rotor
sidebar_position: 60
---

# Tail Rotor

Tail Rotor profile editor page. Loaded on demand (plain loadfile) only when the user opens "Tail Rotor" from the system tool's main menu -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *Tail Rotor*

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
| TTA Threshold | Motorised tail. Tail throttle above Tail Idle where TTA starts; 0 starts it at the idle. Range: 0 to 25.0 %. Default: 0 (off). |
| TTA Banking (Limit) | Most headspeed TTA banking may hold above the governor target, in % of headspeed. Range: 0 to 25 %. Default: 10 %. |
| TTA Banking (Rate) | Fastest wind-down of the banked headspeed as the yaw stick comes back, in % of headspeed per second. Range: 1 to 100 %/s. Default: 20 %/s. |
| TTA Banking (Release) | Tail throttle above which the banked headspeed is released as a main throttle cut. Range: 10 to 100 %. Default: 50 %. |

## Notes

- TTA Threshold and the TTA Banking fields need Rotorflight with MSP API 12.11 (rotorflight-firmware#606) and are greyed out on older firmware. Banking itself is turned on with *TTA Banking* on [Governor → Behaviour](../governor/flags.md).
- Changes are written to the flight controller EEPROM upon Save.
- Save writes two messages, one for the PID profile values and one for the governor profile, which also
  carries the head speed and governor gains. If the PID profile is switched while Save runs, it stops
  before the next write it can, so the other profile's settings are not replaced. The check cannot
  catch a switch in the moment between the flight controller's answer and the write. See
  [Saving to the flight controller](../../../reference/saving.md#a-profile-switch-during-a-save).

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
