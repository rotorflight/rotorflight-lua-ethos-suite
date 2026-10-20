# ActiveLook

The Rotorflight ActiveLook glasses widget shows up to four configured values
for each flight phase: preflight, inflight and postflight. The EnGo 2 display
area is 304 × 256 pixels; layouts and slot assignments are stored separately
for each phase.

## Configure

Open **System → Settings → ActiveLook** on the transmitter. The Settings page
enables the widget and sets its display offset. The Preflight, Inflight and
Postflight pages each select a layout and assign up to four values to it.
These settings are available offline and become read-only while the model is
armed.

Settings are stored in `[activelook]` in
`SCRIPTS:/rfsuite.user/settings.ini`. They are RFSuite settings, not flight
controller EEPROM settings.

## Flight phases and statistics

The widget starts in preflight. A fresh disarmed-to-armed transition returns it
to preflight; arming alone does not mean the helicopter is already flying.
Inflight starts when the governor reports an active state (4 through 8), or
when the mapped transmitter throttle exceeds 35. FC `throttle_percent` is used
only while RX_MAP is unavailable. Once inflight has started, the widget stays
in that phase while armed through brief throttle or telemetry gaps. Disarming
after a flight changes the display to postflight; losing the connection after
inflight has started also shows postflight.

Min/max values are collected only while inflight. They are cleared when the
next flight first enters inflight and remain available throughout postflight.
Select a Min/Max entry in a phase's slot assignment to show an extreme.

## Simulator preview

The suite-local EnGo 2 preview reads telemetry profiles from the simulator's
`sim/sensors/` folder and layouts/slots from its `rfsuite.user/settings.ini`.
Changes made in the preview can be saved back; the simulator's Lua settings
remain the source of truth. For randomized sensor profiles, the preview samples
the same configured range but cannot read the exact random sample already held
inside the simulator.

Source: `src/rfsuite/widgets/activelook.lua`. The flight phase comes from the
session (`src/rfsuite/lib/flight_stats.lua`), the same one the dashboard shows.

Review: [PR #2598](https://github.com/rotorflight/rotorflight-lua-ethos-suite/pull/2598).