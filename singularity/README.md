# Singularity Dashboard Theme v1

A ground-up Rotorflight ETHOS dashboard theme designed first for the FrSky X20 Pro at 800x480.

## Concept

Singularity is a spacecraft-style telemetry interface built around a central reactor core and event-horizon headspeed instrument. It intentionally avoids conventional dashboard boxes wherever possible.

## Screens

- **Preflight:** launch-readiness reactor core with `CLEAR FOR LAUNCH`, `HOLD`, `ABORT`, or `AWAITING LINK` status; orbiting BEC, ESC, link, profile, pack, and Smart Fuel systems.
- **Inflight:** event-horizon RPM gauge with an inner Smart Fuel energy ring, reactor state, thermal plume, thrust array, reactor load, BEC, link, power, and consumed capacity.
- **Postflight:** mission-integrity core with `MISSION NOMINAL`, `MISSION REVIEW`, or `SYSTEM INSPECTION` and orbiting telemetry debrief nodes.

## Technical approach

- One persistent full-screen custom function box per flight state
- Cached telemetry data shared between wakeup and paint
- Static deterministic starfield
- Vector-only rendering; no bitmap assets required
- Header background matches the theme exactly
- Uses standard RFSuite TX battery and RSSI header widgets with a custom `ETHOS // ROTORFLIGHT` center title

## Status

This is v1 for radio testing. MWRC and Aegis remain unchanged.


## v1.1

- Changed the center header title to `ETHOS // ROTORFLIGHT`.
