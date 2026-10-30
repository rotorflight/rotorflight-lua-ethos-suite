# ActiveLook desktop preview

From the repository root (Python 3.11 or later):

```sh
python -m pip install -r bin/activelook_preview/requirements.txt
python bin/activelook_preview/server.py --open
```

Open `http://127.0.0.1:8765`. The port is fixed: a second start returns normally with a clear message (without a SystemExit exception in the debugger) instead of opening another server on another port. On Windows the listening socket is exclusive. Stop the running server with Ctrl+C before restarting it to load Lua changes. Older server versions that already run on ports 8766-8775 must be stopped once manually.
Opening `index.html` as a file cannot run the real Lua renderer. If Lupa is
missing, the page reports the install command instead of silently using a
second, approximate implementation.

## Inspect an alert

Choose Low Fuel, ESC Temperature High, RF Link Low, Governor LOST HS or Governor status
under **Alerts > Alert preview**. Previewing does not require the warning to be
enabled, armed telemetry or an actual alarm condition. The display itself must
be enabled; the desktop starts enabled when no simulator settings file exists.

Expand **Preview settings** to change warning activation, duration, repetitions,
limits and Symbol switches. These changes affect this browser preview only.
They are initialized from simulator settings when available. Layout/slot edits
retain the existing explicit **Save to simulator** operation; that operation
saves only layouts/slots. Model type (Auto/Electric/Nitro) and display temperature
unit are desktop overrides. Auto uses the supplied cell count as battery config.

The normal Inflight Fuel indicator is also supported. **Display at native
resolution** shows the same frame without the photograph's small projection.
The original glasses photograph remains bundled and is not modified.

## Test automatic warnings

Select **AUTO** flight phase and **Automatic / flight-phase preview**, then use
**Manual test values** as the telemetry source. Enable the warnings you want to
test under Preview settings. Supply armed telemetry and governor ACTIVE (4) or
throttle above 35% to enter Inflight. Supply at least one non-empty Smart Fuel
sample before changing it to zero. Hold ESC temperature above its limit for two
seconds, or change governor from ACTIVE to LOST HS (6). Higher priority warnings
interrupt and then resume the lower ones according to the actual suite engine.

Manual preview selection pauses automatic display budgets like the radio's
Settings page. Only the governor manual preview cycles AUTOROTATION /
BAILOUT every two seconds. Automatic governor information is driven by real
telemetry state changes and expires after the configured duration.

Temperature inputs and thresholds are Celsius; display follows C/F. Use audio
limit reads the simulator's `events.escalertvalue` (90 C fallback). Smart Fuel
is the suite's final percentage, not raw battery capacity; there is no artificial
30% threshold or reserve added to the displayed value. Missing numeric inputs
can be cleared to show a dash. Simulator profiles are independently sampled,
not a readout of the running simulator's internal session or derived Smart Fuel.

## Implementation and verification

`renderer.lua` substitutes only bus/settings/clock and glasses I/O. It loads the
actual widget, configuration, alert engine, engine-type detection and flight
tracker from `src/rfsuite`. It records text/bitmap commands; the browser does not
recalculate layout geometry. Suite defaults are read directly from the Lua module.
Runtime sessions are isolated per browser tab, capped at eight and evicted after
ten minutes of inactivity. All endpoints stay on loopback; rendering does not
write settings or contact the radio.

The bitmap atlas is the original grayscale FrSky reference under
`docs/reference/activelook-frsky-v8/`. It is served directly, not deployed or
reuploaded to glasses. Its licensing/evidence limitations are described in that
folder's README. Browser font rasterization, brightness and the optical photo
projection are approximations. Native firmware bitmap conversion/erasure still
needs validation on real ENGO glasses.

Run the desktop integration tests after installing requirements:

```sh
python -m unittest discover -s bin/activelook_preview -p "verify_*.py"
lua5.4 bin/activelook_alerts/verify_activelook_alerts.lua
```

The Python tests execute the real widget and cover all overlays, C/F, Nitro /
Electric, symbols on/off, blink timing, priority interruption/resume, automatic
governor edges, missing data, unchanged-frame suppression, client isolation,
HTTP validation and continued availability of the background photo.

RF Link Low uses the existing suite Link sensor. Choose its unit under Preview-only Values to test RSSI dB (42 default threshold) or VFR/LQ percent (80 default threshold). The Lua runtime selects the matching limit, waits two seconds and rearms after recovery by five native units. This warning is opt-in and has highest priority. Real CRSF sessions currently have no Link sensor mapping; missing values do not trigger an alarm.

Display language selects the same alert translations used by the deployment. The initial selection follows the supported browser language, falling back to English. Text centering counts UTF-8 characters; actual glyph coverage depends on the glasses font.
