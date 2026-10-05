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
