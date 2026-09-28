---
title: Telemetry
sidebar_label: Telemetry
sidebar_position: 30
---

# Telemetry

Telemetry page. Loaded on demand from Setup -> Telemetry.

## Where to find it

*Configuration* → *Setup* → *Telemetry*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Changes are written to the flight controller EEPROM upon Save.
- **Save preserves sensor slots this page does not manage.** The flight
  controller has 40 telemetry slots. Any slot holding a sensor the page has no
  switch for — a native CRSF sensor, for instance — keeps its sensor *and its
  position* when you save, instead of being cleared. Ticked switches are
  written into the remaining slots in page order.
- **A maximum of 40 sensors can be active in total**, counting the preserved
  slots. If your switches plus the preserved ones would exceed 40, the save is
  refused and a dialog says so, rather than silently dropping sensors.
- **Some sensors cannot be switched off while the flight controller is in
  native CRSF telemetry mode**: *Altitude*, *Attitude (Combined)* and *Flight
  mode*, and the per-axis children *Pitch Attitude*, *Roll Attitude* and *Yaw
  Attitude*. The flight controller sends those as whole CRSF frames in that
  mode whether a slot selects them or not, so their switches read as on, stay
  greyed out and ignore taps. This is not a fault — those sensors really are
  being sent. The lock applies only in native mode: in custom mode all of them
  are ordinary selectable sensors, and the page gives them back.
- **Saving sets the flight controller's CRSF telemetry mode to *Custom*.** The
  suite reads custom telemetry only, so it cannot show sensors otherwise. The
  flight controller's mode is *Native* or *Custom* and this page has no control
  for it; until the first save from this page it is whatever the flight
  controller was configured with (default *Native*). The current mode is shown
  under *Diagnostics* → *ELRS Link*.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
