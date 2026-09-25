---
title: Battery
sidebar_label: Battery
sidebar_position: 10
---

# Battery

Setup -> Power -> Battery page.

## Where to find it

*Configuration* → *Setup* → *Power* → *Battery*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| @i18n(app.modules.power.max_cell_voltage)@ | Configures @i18n(app.modules.power.max_cell_voltage)@. Range: 0 to 500 V. Default: 420 V. |
| @i18n(app.modules.power.full_cell_voltage)@ | Configures @i18n(app.modules.power.full_cell_voltage)@. Range: 0 to 500 V. Default: 410 V. |
| @i18n(app.modules.power.warn_cell_voltage)@ | Configures @i18n(app.modules.power.warn_cell_voltage)@. Range: 0 to 500 V. Default: 350 V. |
| @i18n(app.modules.power.min_cell_voltage)@ | Configures @i18n(app.modules.power.min_cell_voltage)@. Range: 0 to 500 V. Default: 330 V. |
| @i18n(app.modules.power.cell_count)@ | Configures @i18n(app.modules.power.cell_count)@. Range: 0 to 24. Default: 6. |
| @i18n(app.modules.power.consumption_warning_percentage)@ | Configures @i18n(app.modules.power.consumption_warning_percentage)@. Range: 0 to 60 %. Default: 35 %. |
| Profiles | Configures Profiles. |
| @i18n(app.modules.power.selected)@ | Configures @i18n(app.modules.power.selected)@. |
| @i18n(app.modules.power.capacity)@ | Configures @i18n(app.modules.power.capacity)@. |
| Battery | Configures Battery. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
