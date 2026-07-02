Version: v1.6

# Aegis Dashboard Theme

A ground-up dashboard theme for Rotorflight ETHOS Suite, designed first for the FrSky X20 Pro at 800×480.

## Design goals

- Fast readability while flying
- Dark graphite instrument-panel styling
- Thin, meaningful accents instead of large colored blocks
- Custom vector instruments with no required image assets
- Color reserved for system state: cyan information, green healthy, amber caution, red critical
- One consolidated renderer per screen to keep widget overhead low

## Screens

- **Preflight:** readiness shield, Smart Fuel, BEC, ESC temperature, radio link, profiles and pack voltage
- **Inflight:** central headspeed instrument, timer, ESC temperature, throttle, Smart Fuel, current, BEC, link and consumption
- **Postflight:** automatic flight grade and nine-stat debrief grid using telemetry min/max values

## Initial target

FrSky X20 Pro, 800×480. This first revision is a radio-test prototype and is intentionally separate from the MWRC theme.

## v1.1 load fix

The header builder now follows the RFSuite theme API: `header_boxes` is a function and calls `standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)`. This fixes the initial theme load failure on the radio.


## v1.2 telemetry fix

The full-screen function box is now cached persistently. This preserves its wakeup cache between dashboard `boxes()` calls, allowing live telemetry and postflight statistics to reach the paint callback.


## v1.3 radio-layout fixes

Preflight shows the exact reason for CAUTION/CHECK. The default BEC caution threshold is now 7.0 V, and inflight footer spacing has been adjusted from X20 Pro radio photos.


## v1.4 refinements

- The standard RFSuite header now uses the Aegis graphite panel palette, so it matches the dashboard instruments.
- Preflight and inflight show a persistent color-coded arm/governor badge.
- States include DISARMED, ARMED / OFF, ARMED / IDLE, SPOOLUP, ACTIVE, AUTOROT, BAILOUT, and related governor states.


## v1.5 visual integration

Aegis uses the native RFSuite header surface across the whole dashboard,
replaces the stock center logo with `ETHOS // ROTORFLIGHT`, and places the
arm/governor state directly below Smart Fuel on the live screens.
