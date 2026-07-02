# Aegis v1.7

- Split the inflight consumed-capacity readout into two centered rows.
- The `CONSUMED` label now sits above the numeric `mAh` value, eliminating overlap in the narrow throttle panel.
- No other dashboard elements changed.

# Aegis Changelog

## v1.6
- Repositioned consumed capacity fully inside the throttle card.
- Moved the label and value to the right of the vertical throttle meter.
- Added more clearance above the lower panel border.

## v1.5
- Removed the separate near-black screen and panel fills.
- Dashboard surfaces now use the radio's native top-bar background.
- Replaced the stock center logo with `ETHOS // ROTORFLIGHT` on all three screens.
- Moved the arm/governor state badge below Smart Fuel on preflight and inflight.
- Retained all v1.4 telemetry, warning-detail, and spacing fixes.

# Aegis v1.4

- Matched the standard RFSuite header background and colors to the Aegis widget panels.
- Added a color-coded arm/governor state badge to preflight and inflight.
- The badge combines arming and governor state when possible, for example `ARMED / IDLE`.

# Aegis v1.3

- Preflight now displays the exact active caution/critical item inside the shield.
- Corrected the default BEC caution threshold from 8.0 V to 7.0 V.
- Automatically migrates the original exact 8.0 V default to 7.0 V.
- Raised the inflight consumed-capacity text away from the throttle-card border.
- Raised the BEC/link subtitle to separate it from the Aegis Monitoring footer.
- Retains the v1.1 load fix and v1.2 persistent telemetry-cache fix.

# Aegis changelog

## v1.2
- Fixed live telemetry not appearing.
- Persistently caches the full-screen function box on all three screens.
- Added fallback access to `rfsuite.tasks.telemetry`.
- Retains the v1.1 standard header API load fix.

## v1.1
- Fixed theme load failure caused by the standard header API call.

## v1.0
- Initial radio-test prototype.
