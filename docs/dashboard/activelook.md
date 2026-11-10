# ActiveLook

The Rotorflight ActiveLook glasses widget shows up to four configured values
for each flight phase: preflight, inflight and postflight. The EnGo 2 display
area is 304 × 256 pixels; layouts and slot assignments are stored separately
for each phase.

## Configure

Open **System → Settings → ActiveLook** on the transmitter. Settings are available
offline and read-only while the model is armed. Changes are stored on Save in
`[activelook]` in `SCRIPTS:/rfsuite.user/settings.ini`, not in FC EEPROM.

The **ETHOS Glasses menu** switch is shown only on ETHOS **26.2.0 or newer** and
only when `system.registerGlasses()` is available. It defaults to **off**; an
existing saved choice is preserved. Enable it, save, and restart the transmitter
to make **Model → Glasses** available. Pair and configure the glasses there.
Changing the switch in either direction shows a restart reminder dialog instead
of a permanent form note. Turning it off, saving and restarting skips the suite's
registration. Other Lua scripts can still register the menu.

**Rotorflight ActiveLook** enables the Rotorflight glasses display. This switch
is disabled while the visible ETHOS Glasses menu switch is off; its saved value
is retained. When the menu switch is unavailable, this restriction does not apply.
Switching the display from off to on shows a setup reminder: open **Model →
Glasses → Screen**, choose the **Full-Screen** layout and assign **Rotorflight
ActiveLook**. Confirming the reminder does not configure ETHOS or save the page.
Use Save as usual. Opening an already enabled page shows no reminder.

The Settings page also selects a Hide Display switch and the display offsets.
The Preflight, Inflight and Postflight pages select layouts and up to four values
per phase. Alerts configures fuel, temperature, RF link and governor overlays.

When the saved menu preference is on and the API exists, `main.lua` registers
support once per loaded suite instance in `init()`, before registering the
existing glasses widget. The suite does not unregister it during the session.
Opening the tool or enabling an additional task is unnecessary for registration.
The existing background task is still needed for Rotorflight telemetry and alerts.
Firmware without the API skips the call and retains its existing behavior.

Startup reads only `register_glasses` from the settings file, without loading or
normalizing the full configuration. This avoids a reproduced startup instruction
limit with larger saved dashboard sections. The full settings reader remains in
use for the normal settings flows; no periodic registration or reader is added.

### Startup validation and memory cost

Run `lua5.4 bin/startup_glasses/verify_startup_glasses.lua` to check the startup
reader against the full INI/settings reader and exercise the real `main.init()`.
The adjacent `.ci.json` registers this harness with the existing CI matrix.
Checks cover section isolation, repeated keys and sections, boolean/numeric
values, invalid and missing values, whitespace, comments, CRLF, file closure,
one-time registration, and no settings read or registration without the API.
Native standard-Lua handles also exercise all three readers without an I/O mock.
Injected open, read and close failures check that startup continues without
registering glasses, reports the failure once, and attempts to close an opened
file even when reading raises an exception.

The readers use standard file-handle methods (`file:read("L")`) rather than the
ETHOS-specific `io.read(file, "L")` spelling. The startup scalar scan is protected
so its file is closed after a read exception. `main.init()` catches reader
exceptions, skips registration for that script lifetime, and continues registering
the other subsystems. A boot diagnostic reports the failure without adding a
periodic retry. A confirmed missing file (`ENOENT`, error code 2) still uses the default-off
preference. Other open failures, including failures without an error code, are
reported by the guarded boot diagnostic instead of silently treated as missing.
Both standard Lua's `true` and ETHOS's empty successful close return are accepted.
These native reads and successful startup were checked in the X20PRO simulator
running ETHOS 26.2.0-RC1 after the robustness follow-up.

A desktop Lua 5.4 measurement with the local settings plus 200 unrelated saved
theme keys gave 17,454 instructions for the full settings load, 4,372 for the
scalar read and 5,152 for the complete updated `init()`. These counts apply only
to that fixture and are not upper bounds for arbitrary files.

This startup optimization has a retained-memory cost even if the glasses menu
is never opened: both changed modules are loaded during boot. Comparing retained
compiled chunks against the pre-registration baseline on desktop Lua 5.4 after
the robustness follow-up gave approximately **1.90 KiB more for
`lib/settings_store.lua`** and **0.62 KiB more for `main.lua`**, or **2.52 KiB total**.
The earlier estimate before error guards was about 1.56 KiB. These are fixed
code-size estimates, not measurements of the complete running suite's heap on
an ETHOS radio; compiler and allocator differences can change the actual cost.

The [official API example](https://ethos-lua-doc.frsky-rc.com/api/system/registerGlasses/)
registers support in `init()` without a wakeup callback. No polling or additional
background task is added. The suite must remain installed and load successfully
after a transmitter restart.

Registration, opening the Glasses page and both saved preference values across
restarts were checked in the X20PRO simulator with ETHOS 26.2.0-RC1 and suite
2.3.1. Full visual verification of the settings interactions remains incomplete:
tool opening encountered an instruction-limit error and subsequent navigation
was restricted with the background task inactive. Bluetooth connectivity and
ENGO2 hardware operation still require validation on compatible hardware.

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
