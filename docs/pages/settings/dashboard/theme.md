---
title: Themes
sidebar_label: Themes
sidebar_position: 10
---

# Themes

Choose the dashboard appearance globally or override each flight phase for a
connected controller under **System → Settings → Dashboard → Themes**.

Global choices work offline while the Suite background task runs. Model
overrides require a connected controller with a known MCU ID. **Use same
theme** copies the preflight choice to inflight and postflight; otherwise each
phase can be selected separately. **Disabled** on a model field uses the
corresponding global selection.

## Bastion

This package registers **Bastion** as `system/bastion`. It supports 800 × 480
full-screen and 784 × 294 compact layouts, and is hidden below 784 × 294 in
both the theme picker and configuration grid. See the
[Bastion guide](../../../dashboard/bastion.md) and
[phase previews](../../../dashboard-themes/Bastion/README.md).

## KSE4 and KSE5

**KSE4** (`system/kse4`) and **KSE5** (`system/kse5`) follow the layouts of
Kyle Stacy's [KSE dashboards](https://github.com/kylestacy2/KSE-Dashboards).
They draw every tile in the Ethos theme's colours, so the radio's theme picks
the palette.

Each theme has its own preflight, inflight and postflight screen.

**KSE4** is a tile dashboard.

- **Preflight**: model image and flight count, a large headspeed tile beside
  the flight timer, and a strip with current, pack voltage, BEC voltage and ESC
  temperature. The bottom row has the governor and a battery or fuel bar.
- **Inflight**: large headspeed and timer tiles, a strip with current, cell
  voltage, ESC temperature and throttle, then the governor and the fuel bar.
- **Postflight**: flight time, consumed mAh and remaining fuel across the top,
  then the flight's peaks and lows: maximum headspeed, current, power,
  throttle and ESC temperature, and minimum cell voltage, BEC voltage and link.

**KSE5** is a ring dashboard.

- **Preflight**: four rings for battery or fuel, headspeed, current and ESC
  temperature. Below them are the model image, the flight count, and tiles for
  the governor, BEC voltage, cell voltage and consumed mAh.
- **Inflight**: a large battery or fuel ring, smaller headspeed and ESC
  temperature rings with the timer and governor below them, and a row with
  current, cell voltage, BEC voltage and throttle.
- **Postflight**: rings for the lowest fuel and the highest headspeed, current
  and ESC temperature, then flight time, consumed mAh, minimum cell and BEC
  voltage, maximum power and minimum link.

Set the full-scale headspeed, current and ESC temperature of the KSE5 rings in
[Dashboard Settings](settings.md). Postflight figures fill in once a flight has
been recorded.

See the [phase previews](../../../dashboard-themes/README.md#kse4).

## Save and reload

Save confirms and writes global choices to `SCRIPTS:/rfsuite.user/settings.ini`
and model overrides to `SCRIPTS:/rfsuite.user/models/<MCU ID>.ini`. These are
local radio files; no flight-controller EEPROM write is made. Reload discards
unsaved selection changes.

Use [Dashboard Settings](settings.md) for the theme's instrument thresholds.
A per-model appearance does not create separate per-model thresholds.

Install the complete matching Suite build containing this theme's registrations,
then restart scripts or the radio. This explicitly registered package does not
assume the automatic discovery available separately in `radio-all-themes`.
