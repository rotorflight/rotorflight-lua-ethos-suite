---
title: Alerts
sidebar_label: Alerts
sidebar_position: 60
---

# Alerts

Configures Smart Fuel, ESC status, temperature and governor overlays managed by the ActiveLook alert engine.

## Where to find it

*System* -> *Settings* -> *ActiveLook* -> *Alerts*.

Available offline without a flight controller connection. Read-only while the model is armed, like the other ActiveLook settings pages. Smart Fuel settings appear first, followed by ESC temperature, ESC Status, Lost headspeed, RF link and Governor status.

## Settings

Audio inheritance is available for Smart Fuel and ESC temperature. RF link has no matching suite audio threshold or repeat budget; its values remain independent. Lost headspeed and Governor status use state changes rather than numeric audio limits, so they have no audio-inheritance switch. Display duration always remains an independent ActiveLook setting.

Each alert has its own expandable panel, like Settings -> General. Smart Fuel is initially expanded; ESC temperature, ESC Status, Lost headspeed, RF link and Governor status start collapsed. Tap a panel heading to expand or collapse its settings. Opening a group closes the previous group and previews that alert on the glasses; closing the active group restores automatic display. All settings within a panel share the same indentation.

| Setting | What it does |
| --- | --- |
| Smart Fuel Warning | Shows a short LOW FUEL message over the Inflight layout when Smart Fuel reaches 0% (the battery consumption-warning reserve). Off by default. |
| Repeats | How many times the message is shown in total while the pack stays low, from 1 to 10 (default 1, shown once). The pause between two shows is as long as the Display duration. Greyed out while the warning is off or Use audio repeats is on. Turning audio inheritance off restores the saved independent count. |
| Use audio repeats (Smart Fuel) | Inherits the audio Smart Fuel repeat count (`events.smartfuelrepeats`), even when audio announcements are off. Off by default. Repeats becomes read-only and displays the inherited count. The warning point remains Smart Fuel 0%, as in audio. |
| Display duration | How long the LOW FUEL message stays on the display, from 3 to 30 seconds (default 5). It is greyed out, so it cannot be changed, while Smart Fuel Warning is off. |
| Icon | Shows the fuel-pump icon for Nitro (image 11) or the battery icon for Electric (image 21) beside the remaining percentage (default on). Turn it off if the active glasses configuration shows no icon or a different image. Greyed out while the warning is off. |
| ESC temp warning | Enables the ESC-temperature warning. Off by default. Requires a connected flight controller and armed Inflight telemetry. |
| Use audio limits & repeats (ESC) | Inherits both the audio temperature threshold (`events.escalertvalue`, normally 90 C) and repeat count (`events.temp_esc_repeats`). Both fields become read-only and display the inherited values. Audio announcements need not be enabled. On by default; disabled while the ESC warning is off. Turning inheritance off restores both saved independent values. |
| ESC temp limit | An independent 60-300 C threshold when Use audio limits & repeats is off. Displayed and edited in the selected temperature unit; stored and compared in C. Disabled when using the audio limit or when the warning is off. |
| Repeats (ESC) | Total temperature warning displays per hot episode, 0-10; default 2. A value of 0 means unlimited warning displays while the hot condition remains active; it does not suppress the alert. The pause between displays equals Display duration. Disabled when the ESC warning is off or Use audio limits & repeats is on. |
| Display duration (ESC) | Display time per temperature warning, 3-30 seconds; default 5. Pauses while a higher-priority warning is visible. Disabled when the ESC warning is off. |
| Icon (ESC) | Shows blinking thermometer ID 18 beside the temperature. On by default; independently switchable from the Smart Fuel icon. Greyed out while the ESC warning is off. Save applies it to live warnings and preview. |
| ESC Status Warning | Enables decoded ESC status overlays only while connected, armed and Inflight. Off by default, including when loading older settings. |
| Show messages | Selects Errors and warnings (default), Errors only, or Warnings only. Disabled while ESC Status Warning is off. Older settings with both severity filters off are normalized to ESC Status Warning off and Errors and warnings, preserving the absence of automatic alerts. |
| Display duration (ESC Status) | Visible time per display, 3–30 seconds, default 5. Pauses during higher-priority warnings or manual preview. Disabled while ESC Status Warning is off. |
| Repeats (ESC Status) | Total displays per continuous fault episode, 1–10, default 2; the gap equals Display duration. Recovery, missing data or filtering stops repeats; flight end, disarm or disconnect clears the event. Disabled while ESC Status Warning is off. |
| Lost headspeed | Enables a critical Governor LOST HS (state 6) overlay. RF link and ESC status errors have higher priority, so LOST HS does not interrupt either warning; it takes priority over the remaining alerts. Off by default. Requires a valid state transition while connected, armed and Inflight. |
| Display duration (LOST HS) | Critical overlay time, 3-30 seconds; default 5. Same-state telemetry does not restart it; leaving and re-entering LOST HS can trigger a new warning. Disabled when Lost headspeed is off. |
| RF link warning | Enables RF LINK LOW; off by default. Uses the suite Link sensor (RSSI in dB or VFR/LQ in percent), only while connected, armed and Inflight. Highest alert priority. |
| RSSI limit | RSSI threshold, 1-100 dB; default 42. Triggers at or below the threshold for two seconds; rearms after recovery by 5 dB. Used only for dB telemetry. |
| VFR/LQ limit | Percentage threshold, 1-100%; default 80%. Used when the resolved Link sensor reports percent. |
| Repeats (RF) | Total displays per low-link episode, 1-10; default 2. The gap equals the display duration. |
| Display duration (RF) | 3-30 seconds; default 5. |
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
2. ESC status ERROR.
3. Governor LOST HS.
4. ESC temperature.
5. ESC status WARNING.
6. Smart Fuel.
7. Governor status information.

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

## ESC status events and preview

The existing `lib/esc_status.lua` decoder consumes session `escSignature` and `escStatusWord`. No separate decoder, polling task or controller write is involved. Identical samples do not restart a display. A changed status word, family, message or severity starts a new event. A one-sample fault retains its first display even if it recovers while interrupted; further repeats require the same continuous condition. The newest ESC event replaces an older ESC event. No OK alarm is emitted. Invalid or missing data is never interpreted as OK. Transient RESTART ESC is not an automatic fault alarm.

Opening ESC Status previews the current decoded text on the glasses even on the bench and with automatic ESC warnings off. Healthy or unsupported status uses a neutral ESC Status heading; absent/invalid telemetry shows NO ESC DATA. Preview pauses display budgets without consuming repeats. Closing the group restores the automatic layout. Error/warning overlays use text only, with the existing compact font and up to two lines; excessively long text is shortened with an ellipsis. No bitmap ID is required.

Manufacturer coverage follows the shared decoder: Kontronik, APD, Hobbywing V5, Scorpion, OpenYGE and Graupner have protocol-specific decoding; opaque protocols can only report a generic fault. Protocols with no status word and unknown signatures produce no automatic alarm. Kontronik flags are documented for telemetry V4; compatibility with V5 has not been established and must be checked before relying on them.

ESC status implementation checked 2026-11-18. A pilot hardware test confirmed that the new status view appears on ENGO 2. No ESC faults were present, so actual warning/error overlays and their interruption/resume remain unverified on hardware.

## ESC status availability and telemetry setup

The ESC Status panel combines the detected protocol and availability in one full-width line: Status available, Generic faults only, No status support, UNKNOWN ESC, Telemetry missing, or Connect to check. Capability comes from the existing decoder registry; missing telemetry never proves that a protocol is unsupported. Preferences remain editable so they can be prepared offline.

The field help for **Show messages** explains the required sensors, without permanent sensor rows or another nested panel. Both **ESC1 Status** and **ESC1 Model ID** must be transmitted and available as radio telemetry sensors. Temperature, voltage and current alone are insufficient. Configure the ESC-to-flight-controller telemetry first under *Setup -> ESC & Motors -> Telemetry* if necessary.

**Set up telemetry** opens the existing *Setup -> Telemetry* page, where the pilot can select ESC1 Status and ESC1 Model ID and explicitly save. The shortcut is enabled only while connected, disarmed and required telemetry is missing. It is greyed out when data is available, the ESC protocol is unsupported or unknown, the model is armed, or the connection is absent. It never changes sensors automatically. The telemetry page retains its normal slot limits, save/reboot behavior and CRSF CUSTOM-mode handling. Back returns to ActiveLook Alerts. Unsaved ActiveLook changes use the normal Save / Discard / Stay prompt before leaving; Save keeps the page open, after which the shortcut can be pressed again.
