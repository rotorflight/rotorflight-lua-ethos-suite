---
title: Rates
sidebar_label: Rates
sidebar_position: 45
---

# Rates

Step 5 of the Model setup wizard. It gives each rate profile on the profile switch a flying
style: Trainer, Sport or 3D, or leaves it as it is.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 5 *Rates*. One page per rate profile the
profile switch picks (only those; without a profile switch, the active one).

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Servos unplugged, All blades removed | Two toggles on the safety card (No / Yes). Start is enabled once both are Yes. |
| Custom | Ticked when the rates match none of the styles. It is only a state; it does not change the rates. |
| Trainer | Slow and soft, for learning to hover and first circuits. Cyclic 180 °/s, yaw 270 °/s, expo 40 % (yaw 50 %). |
| Sport | The firmware's default rates, for general flying and gentle aerobatics. Cyclic 250 °/s, yaw 400 °/s, expo 40 % (yaw 50 %). |
| 3D | Fast, for 3D and hard aerobatics. Cyclic 400 °/s, yaw 600 °/s, expo 30 % (yaw 40 %). |
| The curve | The rate curve of the profile, drawn from its values, with the full-stick rates and the expo. |

## Notes

- A profile that matches none of the styles is Custom. Picking a style replaces its rates.
- Each style is written to the profile on the spot, so the flight controller has it straight
  away. Save and continue stores it in the EEPROM.
- Discard puts the rates of every profile back as they were.
- The collective pitch is not changed here: the Blade pitch step sets it.
- The Actual rates type (firmware before the Rotorflight type) is not changed here. Set its
  rates on the Rates page.
- The wizard writes the rates and reads them back by selecting each profile in turn. The
  active profile is selected again at the end.

## Related

- [Rates](../../flight_tuning/rates.md): all rate settings, and the rates types.
- [Profiles & gain](profiles.md): the profile switch that picks the profiles.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
