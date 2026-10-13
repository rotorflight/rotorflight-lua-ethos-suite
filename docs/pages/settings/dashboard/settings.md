---
title: Settings
sidebar_label: Settings
sidebar_position: 20
---

# Settings

Open **System → Settings → Dashboard → Settings → Bastion** to configure the
theme's instrument presentation. Select the active appearance separately on
the [Themes](theme.md) page.

The settings page works offline while the Suite background task runs. A tile
appears when the theme is registered, its configure module exists, and the
window meets its minimum size. **Bastion** requires at least 784 × 294 pixels;
800 × 480 full-screen and 784 × 294 compact layouts are supported.

## Saving and units

- Save writes this theme's instrument values to the `dashboard.bastion` section
  of `SCRIPTS:/rfsuite.user/settings.ini` on the radio.
- These values apply to models using this theme. They do not write
  flight-controller EEPROM or change the controller's protection limits.
- Reload discards unsaved form edits and restores the values loaded for the
  page or last saved during this visit.
- Temperature fields follow **System → Settings → General**. Stored thresholds
  remain Celsius, so changing display units does not reinterpret saved values.

The available fields are provided by the theme's configuration module.

## KSE5

**KSE5** sets the value at which each of its rings is full. A zero or missing
value falls back to the default.

- **Headspeed → Max** — 500 to 6000 rpm, default 3000.
- **Current → Max** — 10 to 500 A, default 150. The ring turns to the warning
  colour above 70 % of this value and to the critical colour above 90 %.
- **ESC Temp → Max** — 40 to 150 °C, default 100, with the same colour steps.

Values are stored in the `dashboard.kse5` section of `settings.ini`.

See the [Bastion guide](../../../dashboard/bastion.md) for its appearance,
installation, and [phase previews](../../../dashboard-themes/Bastion/README.md).
