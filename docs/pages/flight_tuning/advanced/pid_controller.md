---
title: PID Controller
sidebar_label: PID Controller
sidebar_position: 20
---

# PID Controller

PID Controller profile editor page. Loaded on demand (plain loadfile) only when the user opens "PID Controller" from the system tool's main menu -- see app/tool.lua.

## Where to find it

*Configuration* → *Flight Tuning* → *PID Controller*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Master Gain (Cyc) | Scales the roll and pitch P, I, D and Offset gains together, keeping their ratios. Feedforward, Boost and precomp are not scaled. Range: 25 to 200 %. Default: 100 %. |
| Master Gain (Y) | Scales the tail P, I and D gains together, keeping their ratios and the CW/CCW stop gain balance. Feedforward, Boost and precomp are not scaled. Range: 25 to 200 %. Default: 100 %. |
| Ground Error Decay | Configures Ground Error Decay. Range: 0 to 250 s. Default: 25 s. |
| Iterm Relax: Type | Configures Iterm Relax: Type. |
| In-flight Error Decay (Time) | Configures In-flight Error Decay (Time). Range: 0 to 250 s. Default: 250 s. |
| In-flight Error Decay (Limit) | Configures In-flight Error Decay (Limit). Range: 0 to 25 °. Default: 12 °. |
| Error Limit (R) | Configures Error Limit (R). Range: 0 to 180 °. Default: 45 °. |
| Error Limit (P) | Configures Error Limit (P). Range: 0 to 180 °. Default: 45 °. |
| Error Limit (Y) | Configures Error Limit (Y). Range: 0 to 180 °. Default: 60 °. |
| HSI Offset Limit (R) | Configures HSI Offset Limit (R). Range: 0 to 180 °. Default: 90 °. |
| HSI Offset Limit (P) | Configures HSI Offset Limit (P). Range: 0 to 180 °. Default: 90 °. |
| Iterm Relax Cutoff (R) | Configures Iterm Relax Cutoff (R). Range: 1 to 100. Default: 10. |
| Iterm Relax Cutoff (P) | Configures Iterm Relax Cutoff (P). Range: 1 to 100. Default: 10. |
| Iterm Relax Cutoff (Y) | Configures Iterm Relax Cutoff (Y). Range: 1 to 100. Default: 10. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- Parameters are scoped to the currently active PID profile.
- Master Gain needs firmware with MSP API 12.10 or later; on older firmware both fields stay greyed out.
- A master gain changed in flight (Cyclic/Yaw Master Gain adjustment functions) does not disturb trim already held by I and Offset; only how fast they build up changes.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
