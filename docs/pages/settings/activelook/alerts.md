---
title: Alerts
sidebar_label: Alerts
sidebar_position: 60
---

# Alerts

Configures Smart Fuel, temperature and governor overlays managed by the ActiveLook alert engine.

## Where to find it

*System* -> *Settings* -> *ActiveLook* -> *Alerts*.

Available offline without a flight controller connection. Read-only while the model is armed, like the other ActiveLook settings pages. Smart Fuel settings appear first, followed by ESC temperature, Lost headspeed, RF link and Governor status.

## Settings

Audio inheritance is available for Smart Fuel and ESC temperature. RF link has no matching suite audio threshold or repeat budget; its values remain independent. Lost headspeed and Governor status use state changes rather than numeric audio limits, so they have no audio-inheritance switch. Warning Duration always remains an independent ActiveLook setting.

Each alert has its own expandable panel, like Settings -> General. Smart Fuel is initially expanded; ESC temperature, Lost headspeed, RF link and Governor status start collapsed. Tap a panel heading to expand or collapse its settings. Opening a group closes the previous group and previews that alert on the glasses; closing the active group restores automatic display. All settings within a panel share the same indentation.

| Setting | What it does |
| --- | --- |
| Smart Fuel Warning | Shows a short LOW FUEL message over the Inflight layout when Smart Fuel reaches 0% (the battery consumption-warning reserve). Off by default. |
| Repeats | How many times the message is shown in total while the pack stays low, from 1 to 10 (default 1, shown once). The pause between two shows is as long as the Warning Duration. Greyed out while the warning is off or Use audio repeats is on. Turning audio inheritance off restores the saved independent count. |
| Use audio repeats (Smart Fuel) | Inherits the audio Smart Fuel repeat count (`events.smartfuelrepeats`), even when audio announcements are off. Off by default. Repeats becomes read-only and displays the inherited count. The warning point remains Smart Fuel 0%, as in audio. |
| Warning Duration | How long the LOW FUEL message stays on the display, from 3 to 30 seconds (default 5). It is greyed out, so it cannot be changed, while Smart Fuel Warning is off. |
| Icon | Shows the fuel-pump icon for Nitro (image 11) or the battery icon for Electric (image 21) beside the remaining percentage (default on). Turn it off if the active glasses configuration shows no icon or a different image. Greyed out while the warning is off. |
| ESC temp warning | Enables the ESC-temperature warning. Off by default. Requires a connected flight controller and armed Inflight telemetry. |
| Use audio limits & repeats (ESC) | Inherits both the audio temperature threshold (`events.escalertvalue`, normally 90 C) and repeat count (`events.temp_esc_repeats`). Both fields become read-only and display the inherited values. Audio announcements need not be enabled. On by default; disabled while the ESC warning is off. Turning inheritance off restores both saved independent values. |
| ESC temp limit | An independent 60-300 C threshold when Use audio limits & repeats is off. Displayed and edited in the selected temperature unit; stored and compared in C. Disabled when using the audio limit or when the warning is off. |
| Repeats (ESC) | Total temperature warning displays per hot episode, 0-10; default 2. A value of 0 means unlimited warning displays while the hot condition remains active; it does not suppress the alert. The pause between displays equals Warning Duration. Disabled when the ESC warning is off or Use audio limits & repeats is on. |
| Warning Duration (ESC) | Display time per temperature warning, 3-30 seconds; default 5. Pauses while a higher-priority warning is visible. Disabled when the ESC warning is off. |
| Icon (ESC) | Shows blinking thermometer ID 18 beside the temperature. On by default; independently switchable from the Smart Fuel icon. Greyed out while the ESC warning is off. Save applies it to live warnings and preview. |
| Lost headspeed | Enables a critical Governor LOST HS (state 6) overlay. RF link warnings have higher priority, so LOST HS does not interrupt an RF warning; it takes priority over the remaining alerts. Off by default. Requires a valid state transition while connected, armed and Inflight. |
| Warning Duration (LOST HS) | Critical overlay time, 3-30 seconds; default 5. Same-state telemetry does not restart it; leaving and re-entering LOST HS can trigger a new warning. Disabled when Lost headspeed is off. |
| RF link warning | Enables RF LINK LOW; off by default. Uses the suite Link sensor (RSSI in dB or VFR/LQ in percent), only while connected, armed and Inflight. Highest alert priority. |
| RSSI limit | RSSI threshold, 1-100 dB; default 42. Triggers at or below the threshold for two seconds; rearms after recovery by 5 dB. Used only for dB telemetry. |
| VFR/LQ limit | Percentage threshold, 1-100%; default 80%. Used when the resolved Link sensor reports percent. |
| Repeats (RF) | Total displays per low-link episode, 1-10; default 2. The gap equals the display duration. |
| Warning Duration (RF) | 3-30 seconds; default 5. |
| Icon (RF) | Shows RF icon ID 16 beside the Link value, blinking one second on/off. On by default; independently switchable. Disabled while RF link warning is off. The saved choice applies to automatic warnings and preview. |
| Governor status | Enables short AUTOROTATION (7) and BAILOUT (8) transition messages while armed or Inflight. Off by default. |
| Status duration | Governor information display time, 1-5 seconds; default 2. Disabled when Governor status is off. |

Temperature must reach the limit for at least two seconds of valid telemetry. A new hot episode requires cooling to at least 5 C below the limit. Missing/non-finite/out-of-range temperature samples cannot start an alert and interrupt the pending trigger delay. The comparison always uses Celsius; the overlay follows the suite's C/F preference. A warning already shown is allowed to finish its configured display time after recovery.

## Live preview

Opening an alert group shows its overlay on the connected glasses, independently of whether that automatic warning is enabled or its trigger condition is met. Only one group can be open. Smart Fuel starts expanded and previews immediately. Closing the active group or leaving the page restores the automatic flight-state display.

Smart Fuel, ESC temperature, RF link and LOST HS use live telemetry. Missing values show a dash. Smart Fuel retains its one-second on/off blink and the engine-specific icon (Nitro 11, Electric 21). Governor status cycles AUTOROTATION and BAILOUT every two seconds, with live RPM. No telemetry or flight-controller state is modified.

The preview stays visible without a duration limit and pauses automatic display budgets. Save applies edited settings and retains the selected preview; unsaved Icon and temperature-limit edits take effect on the glasses after Save. ActiveLook must be enabled and its display switch must allow the display.

## Priority and lifecycle

1. RF link.
2. Governor LOST HS.
3. ESC temperature.
4. Smart Fuel.
5. Governor status information.

A higher-priority warning interrupts a lower one. Interrupted warnings keep their remaining visible time; Smart Fuel repetition gaps begin only after a display completes. Governor information is never queued behind an alarm and is discarded when preempted. First governor telemetry seeds the state without inventing a transition. Disarm, flight end and link loss clear automatic warnings. SPOOLUP does not trigger a status overlay.

The overlay displays localized warning labels and live telemetry; missing values are shown as a dash. A completed overlay returns to the appropriate normal phase layout. The permanent Inflight fuel indicator is hidden during overlays and returns afterward.

Changes are saved to `[activelook]` in `SCRIPTS:/rfsuite.user/settings.ini`; they do not change flight controller settings. All new automatic functions are disabled by default. Engine code lives in `src/rfsuite/lib/activelook_alerts.lua`; graphics remain in `src/rfsuite/widgets/activelook.lua`. See [PR #2630](https://github.com/rotorflight/rotorflight-lua-ethos-suite/pull/2630) for the implementation.

*Documented against RFSuite Ethos 2.3.1, implementation checked 2026-10-21. Hardware verification on ENGO 2 remains required for the new overlays.*

When Icon (ESC) is enabled, ESC-temperature overlays show the temperature beside bitmap ID 18 (thermometer-like icon in the observed FrSky configuration). The icon blinks one second on, one second off in automatic warnings and previews; space remains reserved so the text does not move. Layout replacement clears the icon when another overlay or phase is shown.

RF LINK LOW displays the live Link value and matching threshold. Sensor units select RSSI dB (default threshold 42) or VFR/LQ percent (default 80). Both use two seconds below/at the limit and five native units of recovery hysteresis. Missing, non-finite or out-of-range (outside 0-100) data cancels pending delays/repeats and never triggers a new alarm. The existing S.Port mapping selects RSSI 0xF101 first, then VFR 0xF010 as fallback. The current CRSF mapping has no Link entry, so the alarm remains inactive there without a valid suite Link source. Negative dBm is not guessed or converted. Opening the RF group previews the live value in its actual unit.

Sensor-ID reference: the [FrSky Ethos manual](https://raw.githubusercontent.com/FrSkyRC/ETHOS-Feedback-Community/1.6/doc/%5BEN%5D%20Ethos%20User%20Manual%201.6.0.pdf) identifies RSSI F101 in dB and VFR F010 in percent. Set the relevant threshold for the receiver and RF mode in use; the defaults are editable starting values.

RF LINK LOW shows bitmap ID 16 beside the live Link value, blinking one second on and one second off in both automatic warnings and preview. Icon space stays reserved while hidden, so the text does not move. Layout replacement removes it on an overlay/phase change.

Smart Fuel covers both power types, matching the voice announcements: Nitro uses Fuel / LOW FUEL, and Electric uses Battery / BATTERY EMPTY. Shared settings use the Smart Fuel name. Both warning headlines use the same smaller heading font (font 1), so BATTERY EMPTY fits and LOW FUEL has the same text size.

Independent ESC Repeats accepts 0 for unlimited displays while the condition remains active, including after Save and reload. Disabling ActiveLook clears the current display before the layout is released.

Alert display text is localized through the deployment i18n step, including the battery/fuel headline, ESC and RF warnings, lost-headspeed message, Governor states and limit label. Deploy with the desired language (for example --lang de) and restart the radio scripts. German displays AKKU LEER for Electric and KRAFTSTOFF NIEDRIG for Nitro. The browser preview offers a Display language selector and defaults to the supported browser language. Font glyph coverage still depends on the glasses configuration.
