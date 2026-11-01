---
title: Inflight
sidebar_label: Inflight
sidebar_position: 30
---

# Inflight

Configures Inflight parameters for Rotorflight.

## Where to find it

*System* → *Settings* → *ActiveLook* → *Inflight*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Layout | Selects the arrangement of telemetry slots. |
| Slot 1-4 | Selects the telemetry shown in each active slot. |
| Fuel icon | Shows a 28x28 fuel indicator at the bottom left during Inflight. Off by default. Uses the existing Smart Fuel value directly, without adding the reserve back. IDs 02-06 represent the nearest 0/25/50/75/100% level. Hidden without a fuel reading and while the low-fuel warning overlay is shown. |


## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*

The fuel icon uses Ethos's fixed 40x40 bitmap frame and an additional 56px bottom clearance (raised 30px from the original 26px setting). This placement still needs confirmation on the glasses. Positive offsets are capped at this height. See [coordinate mapping](../../../reference/activelook-coordinate-mapping.md) for the firmware findings and hardware observations.

The fuel bitmap is included in the same `clearAndDisplayExtended` call as the telemetry text. Its position remains unchanged; reduced flicker still needs confirmation on the glasses.

Link, Min Link and Max Link slots use the resolved sensor unit: percent for VFR/LQ and dB for RSSI, consistently with the RF-link warning. Min/Max Smart Fuel choices use the selected menu language.
