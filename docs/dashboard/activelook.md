# ActiveLook

The Rotorflight ActiveLook glasses widget shows up to four configured values
for each flight phase: preflight, inflight and postflight. The EnGo 2 display
area is 304 × 256 pixels; layouts and slot assignments are stored separately
for each phase.

## Configure

Open **System → Settings → ActiveLook** on the transmitter. The Settings page
enables the widget and sets its display offset. The Preflight, Inflight and
Postflight pages each select a layout and assign up to four values to it. The
Low Fuel page switches the low fuel warning on and sets how long it stays.
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

## Low fuel warning

The **Low Fuel Warning** switch on the Low Fuel page (off by default) shows a
temporary overlay while inflight. It appears once when the smart fuel level
reaches 0, which is the *Consumption Warning %* from the battery settings and
the same point at which the voice alert plays. The overlay shows `LOW FUEL`, the
current Smart Fuel percentage with an optional warning symbol beside it, the voltage and
the consumed capacity (mAh) for the configured **Warning Duration** (3 to 30
seconds, default 8), then the configured Inflight layout returns. When enabled,
the symbol blinks slowly (one second on, one second off); the text stays visible
and retains its position. This also applies to the Low Fuel settings preview.
By default the overlay appears once per flight; **Repeats** sets how many
times it is shown in total while the pack stays low (1 to 10, like the voice
alert's "Low fuel repeats"), with a pause between shows as long as the Warning
Duration. Repeating stops when the fuel level recovers, the model is disarmed or
the link is lost. The first fuel reading
after connecting only seeds the check, so a sensor that has not reported yet
cannot trigger it.

The symbol uses image **11** (fuel pump) for Nitro models and image **21**
(battery) for Electric models in the tested glasses configuration. It uses the
same engine-type detection as the dashboard and audio alerts: an explicit
Smart Fuel model type takes precedence; Auto checks the configured battery
cell count or capacity. Nothing is uploaded to the glasses.
Image mappings can differ between configurations; use the **Symbol** switch to
disable it if a different image or no image appears. See the
[observed image IDs](../reference/activelook-observed-image-ids.md).
The browser preview still uses the older battery-low reference asset and does
not reproduce the engine-specific symbol selection or blinking on the glasses.

## Simulator preview

The browser preview projects the live display transparently into an ENGO glasses
photograph, following [WingFlight PR #251](https://github.com/WingFlight/wingflight-lua-ethos-suite/pull/251).
The header uses the Rotorflight logo alongside the ActiveLook animation.
The preview controls follow [rotorflight.org](https://rotorflight.org/): its system
font stack (including Segoe UI and Roboto), brand blue `#007cc7` and dark palette.
The projected display uses the separate bundled ActiveLook EnGo 2 font to match
the glasses, rather than the interface font.
The photograph and the CC0 animation/license are included with the preview.

The suite-local EnGo 2 preview reads telemetry profiles from the simulator's
`sim/sensors/` folder and layouts/slots from its `rfsuite.user/settings.ini`.
Changes made in the preview can be saved back; the simulator's Lua settings
remain the source of truth. For randomized sensor profiles, the preview samples
the same configured range but cannot read the exact random sample already held
inside the simulator. The preview also draws the low fuel overlay when the
switch is on in the simulator's settings. It treats the Fuel value as the raw
pack level and shows the overlay when it reaches 30 %, the Consumption
Warning the simulator reports, because the preview cannot read the battery
settings. It shows the overlay in the Auto phase only, not when a phase is
chosen by hand. The preview draws all text at 40 % brightness, the level the
battery-low symbol peaks at; the widget itself sets no text color.

Source: `src/rfsuite/widgets/activelook.lua` and
`src/rfsuite/widgets/dashboard/flightmode.lua`.

Review: [PR #2598](https://github.com/rotorflight/rotorflight-lua-ethos-suite/pull/2598).
