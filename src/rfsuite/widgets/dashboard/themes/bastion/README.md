# Bastion

A graphite and cyan dashboard with a technical shield motif.

- **Preflight:** current telemetry and setup/status information before flight.
- **Inflight:** live flight instruments, timing, and warning presentation.
- **Postflight:** recorded flight results; unavailable readings remain marked.

Full 800 × 480 and compact 784 × 294 layouts are supported. The theme and its
configuration tile require at least 784 × 294 pixels; smaller windows hide
both choices. The current model name and native transmitter header remain
visible in full screen, with a smaller MWRC signature beside the centered title.

## Installation and settings

Install the complete matching Suite build with this theme's registrations,
preserve `rfsuite.user`, and restart scripts or the radio. Copying this folder
alone onto a stock build that does not register it is insufficient. Select
**System → Settings → Dashboard → Themes → Bastion** and configure display
limits under **Dashboard → Settings → Bastion**.

The folder and internal ID are `bastion`; the saved selection is
`system/bastion`. Instrument settings use `dashboard.bastion` in the radio's
`SCRIPTS:/rfsuite.user/settings.ini`. Save does not write flight-controller
EEPROM. Temperature thresholds remain stored in Celsius and display in the
selected Celsius/Fahrenheit units.

See the [theme guide](../../../../../../docs/dashboard/bastion.md) for
model overrides, installation details, and previews. Desktop previews use
simulated telemetry and approximate fonts; physical-radio acceptance is separate.

GPLv3, consistent with the Suite. Preserve source notices and included artwork attribution.
