# ActiveLook

The Rotorflight ActiveLook glasses widget shows up to four configured values
for each flight phase: preflight, inflight and postflight. The EnGo 2 display
area is 304 × 256 pixels; layouts and slot assignments are stored separately
for each phase.

## Configure

Open **System → Settings → ActiveLook** on the transmitter. The Settings page
enables the widget and sets its display offset. The Preflight, Inflight and
Postflight pages each select a layout and assign up to four values to it. The
Alerts page configures Low Fuel, ESC temperature and governor overlays.
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
the same point at which the voice alert plays. The overlay shows `LOW FUEL` for Nitro or `BATTERY EMPTY` for Electric, the
current Smart Fuel percentage with an optional warning icon beside it, the voltage and
the consumed capacity (mAh) for the configured **Warning Duration** (3 to 30
seconds, default 5), then the configured Inflight layout returns. When enabled,
the icon blinks slowly (one second on, one second off); the text stays visible
and retains its position. This also applies to the Low Fuel settings preview.
By default the overlay appears once per flight; **Repeats** sets how many
times it is shown in total while the pack stays low (1 to 10, like the voice
alert's "Low fuel repeats"), with a pause between shows as long as the Warning
Duration. Repeating stops when the fuel level recovers, the model is disarmed or
the link is lost. The first fuel reading
after connecting only seeds the check, so a sensor that has not reported yet
cannot trigger it.

The icon uses image **11** (fuel pump) for Nitro models and image **21**
(battery) for Electric models in the tested glasses configuration. It uses the
same engine-type detection as the dashboard and audio alerts: an explicit
Smart Fuel model type takes precedence; Auto checks the configured battery
cell count or capacity. Nothing is uploaded to the glasses.
Image mappings can differ between configurations; use the **Icon** switch to
disable it if a different image or no image appears. See the
[observed image IDs](../reference/activelook-observed-image-ids.md).
The browser preview still uses the older battery-low reference asset and does
not reproduce the engine-specific icon selection or blinking on the glasses.

## Alert engine

[Settings -> ActiveLook -> Alerts](../pages/settings/activelook/alerts.md) adds opt-in ESC-temperature warnings, critical Governor LOST HS warnings and short governor status messages. All new functions default off. Low Fuel settings are now the first group on this page; their values and current Smart Fuel display are unchanged.

The graphics-independent `lib/activelook_alerts.lua` owns per-widget timing, detection and priorities: RF link > LOST HS > ESC temperature > Low Fuel > governor information. Higher-priority warnings pause lower warnings with their remaining visible time intact. Low Fuel repeats remain bounded and resume after interruption. Governor information is discarded rather than queued behind warnings. Automatic alerts reset at disarm/flight end/link loss. The settings Low Fuel preview remains available and pauses the automatic display budget until it closes.

ESC-temperature warnings reuse the existing audio limit by default, with an optional independent limit. Triggering requires two seconds at/above the limit and rearming requires 5 C of cooling below it. Comparisons use Celsius; display follows the configured temperature unit. LOST HS requires a valid transition into state 6 during connected, armed Inflight operation, then displays current RPM if available. Autorotation (7) and bailout (8) information appears only on actual governor transitions while armed or Inflight.

Rendering still uses the existing glasses layouts, bitmap handling and coordinate corrections. Cached slots and value buffers are reused; unchanged visible content sends no new frame. The permanent fuel indicator returns with the normal Inflight layout after an overlay.

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
`sim/sensors/` folder and layouts/slots plus alert settings from
`rfsuite.user/settings.ini`. Layout/slot edits can still be saved back. Alert
controls change only the desktop preview; they never write simulator or radio
settings.

The preview runs the actual `widgets/activelook.lua`, `lib/activelook_alerts.lua`,
configuration helpers and flight-phase tracker under desktop Lua 5.4 (Lupa).
The browser paints their recorded text and bitmap commands, including the
suite's coordinates, font IDs, rounding, priorities, display durations,
repetitions and remaining-time handling. No separate JavaScript alert engine
or guessed 30% Low Fuel threshold is used. The supplied Smart Fuel percentage
is passed to the widget directly: automatic Low Fuel triggers at 0%.

Select **Alert preview** to force Low Fuel, ESC temperature, LOST HS or governor
status without meeting an alarm condition. Governor status cycles only in this
manual preview; automatic operation follows real telemetry transitions. Low
Fuel uses Nitro image 11 or Electric image 21, ESC uses image 18, and their
independent Icon settings control blinking. The normal Inflight indicator
uses images 2-6. Celsius/Fahrenheit, display offsets and original FrSky grayscale
bitmap shapes are retained. A native-resolution canvas makes details easier
to inspect than the small projection on the photograph.

Use **Automatic** flight phase with no forced alert to test automatic detection
and priorities. **Manual test values** releases telemetry inputs from simulator
polling, allowing intentional state changes, temperature crossings and Smart
Fuel depletion without modifying any sensor files. Temperature inputs are
Celsius; the selected unit changes display formatting only. The raw sensor
profiles are not a live export of the simulator's session: randomized profiles
are independently sampled, and Smart Fuel must be supplied as the already
calculated suite percentage rather than a raw pack-level estimate.

Canvas glyph rasterization and the photographed optical projection remain
browser approximations; these do not prove hardware brightness, firmware
bitmap placement or clearing behaviour. Start and test instructions are in
[`bin/activelook_preview/README.md`](../../bin/activelook_preview/README.md).

Source: `src/rfsuite/widgets/activelook.lua`. The flight phase comes from the
session (`src/rfsuite/lib/flight_stats.lua`), the same one the dashboard shows.

Review: [PR #2598](https://github.com/rotorflight/rotorflight-lua-ethos-suite/pull/2598).

When the ESC Icon setting is enabled, ESC-temperature overlays show the temperature beside bitmap ID 18 (thermometer-like icon in the observed FrSky configuration). The icon blinks one second on, one second off in automatic warnings and previews; space remains reserved so the text does not move. Layout replacement clears the icon when another overlay or phase is shown.

## Bitmap rendering notes

In the tested FrSky configuration, Low Fuel uses the fuel-pump icon (ID 11) for Nitro and the battery icon (ID 21) for Electric.

The investigated Ethos build uses a fixed 40x40 coordinate-flip frame for standalone bitmaps, including images stored as 28x28. The widget accounts for this with `ETHOS_BITMAP_FRAME_PX`.

A hardware test at the initially calculated bottom edge cleared only the first row of the fuel icon. This observation is the reason for the additional bottom clearance (`FUEL_ICON_BOTTOM_CLEARANCE`). See the [coordinate investigation](../reference/activelook-coordinate-mapping.md) for evidence and limits of that calculation.

The opt-in RF LINK LOW warning uses the existing Link telemetry with separate configurable thresholds (RSSI: 42 dB; VFR/LQ: 80%), two-second delay and five native units of recovery hysteresis. It has highest priority and preserves interrupted warning budgets. Missing Link telemetry does not trigger it. The resolved sensor unit selects the threshold; the current CRSF mapping provides no Link sensor.

RF LINK LOW shows bitmap ID 16 beside the live Link value, blinking one second on and one second off in both automatic warnings and preview. Icon space stays reserved while hidden, so the text does not move. Layout replacement removes it on an overlay/phase change.

Smart Fuel covers both power types, matching the voice announcements: Nitro uses Fuel / LOW FUEL, and Electric uses Battery / BATTERY EMPTY. Shared settings use the Smart Fuel name. Both warning headlines use the same smaller heading font (font 1), so BATTERY EMPTY fits and LOW FUEL has the same text size.

The Inflight Smart Fuel indicator is sent as a bitmap command in the same clearAndDisplayExtended call as the telemetry text. There is no separate glasses.bitmap call after clearing the layout. Its position remains unchanged. This removes the separate redraw step; reduced flicker still needs confirmation on the glasses.

Alert display text is localized through the deployment i18n step, including the battery/fuel headline, ESC and RF warnings, lost-headspeed message, Governor states and limit label. Deploy with the desired language (for example --lang de) and restart the radio scripts. German displays AKKU LEER for Electric and KRAFTSTOFF NIEDRIG for Nitro. The browser preview offers a Display language selector and defaults to the supported browser language. Font glyph coverage still depends on the glasses configuration.

The widget reads its flight phase from the session snapshot and uses `lib/flight_stats.lua` for layout-phase mapping. The browser preview and widget tests feed phases through the same session flight-statistics implementation.
