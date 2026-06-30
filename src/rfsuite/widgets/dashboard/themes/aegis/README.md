# Aegis Dashboard Theme

**Current radio-tested version: v1.7**

A ground-up dashboard theme for Rotorflight ETHOS Suite, designed first for the FrSky X20 Pro at 800×480.

## Design goals

- Fast readability while flying
- Native ETHOS/RFSuite background integration
- Thin, meaningful accents instead of large colored blocks
- Custom vector instruments with no required image assets
- Color reserved for system state: cyan information, green healthy, amber caution, red critical
- One consolidated renderer per screen to keep widget overhead low

## Screens

- **Preflight:** readiness shield, Smart Fuel, BEC, ESC temperature, radio link, profiles, pack voltage, and arm/governor state
- **Inflight:** central headspeed instrument, timer, ESC temperature, throttle, Smart Fuel, current, BEC, link, consumption, and arm/governor state
- **Postflight:** automatic flight grade and nine-stat debrief grid using telemetry min/max values

## Current refinements

- Correct RFSuite header API usage
- Persistent custom-widget telemetry caching
- Exact preflight warning reason shown on screen
- BEC caution default adjusted for a normal 7.2 V BEC
- Header center text changed to `ETHOS // ROTORFLIGHT`
- Dashboard surfaces matched to the native header background
- Arm/governor badge placed below Smart Fuel
- Consumed-capacity readout split into two centered rows in the throttle panel

## Target

FrSky X20 Pro, 800×480. Aegis remains separate from the MWRC theme.
