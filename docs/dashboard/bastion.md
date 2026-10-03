# Bastion

A graphite and cyan dashboard with a technical shield motif.

## Select and configure

Select **System → Settings → Dashboard → Themes → Bastion**. Open
**System → Settings → Dashboard → Settings → Bastion** to adjust its display
limits. Global choices and theme settings work offline while the Suite
background task runs. A model-specific selection requires a connected flight
controller with a known MCU ID.

This theme supports full 800 × 480 and compact 784 × 294 layouts. Both the theme
choice and configuration tile are hidden below 784 × 294, including 480 × 320
and 472 × 191 windows. The compact layout omits the native header; full screen
retains the dynamic model name, transmitter battery/RSSI, and centered title.

## Screens

- **Preflight:** current telemetry and setup/status information before flight.
- **Inflight:** live flight instruments, timing, and warning presentation.
- **Postflight:** recorded flight results; unavailable readings remain marked.

See the [three phase previews](../dashboard-themes/Bastion/README.md).
They use simulated telemetry and desktop fonts: **Desktop preview, not radio capture**.

## Saved settings

The selection ID is `system/bastion`. Theme instrument settings are stored in
`dashboard.bastion` within `SCRIPTS:/rfsuite.user/settings.ini`. They are shared
by models using this theme. Global phase choices are saved in the same file;
model overrides are saved in `SCRIPTS:/rfsuite.user/models/<MCU ID>.ini`.

Save changes local radio files, not flight-controller EEPROM or controller
protection settings. Temperature fields use the selected display unit while
stored thresholds remain Celsius. Reload restores the form's loaded or last
saved values. Selecting a per-model appearance does not create per-model
instrument thresholds.

## Installation and verification

Install the complete matching Suite build containing this theme and its loader,
theme-picker, settings-tile, and settings-store registrations. Preserve the
radio's `rfsuite.user` directory and restart scripts or the radio after updating.
Copying the theme folder alone onto a stock build that does not register it is
insufficient. These instructions describe this explicitly registered theme
package; automatic discovery in `radio-all-themes` is a separate installation
path and is not assumed here.

The portable checks in `tests/themes/test_bastion_registration.py` exercise
selection, save/reopen, model overrides, and minimum-size visibility against
production Suite modules. See `tests/themes/README.md` for commands and evidence
limits. Native font appearance, real telemetry transitions, and radio
instruction/memory behavior still need physical-radio verification.

Source: `src/rfsuite/widgets/dashboard/themes/bastion/`.

GPLv3, consistent with the Suite. Preserve source notices and included artwork attribution.
