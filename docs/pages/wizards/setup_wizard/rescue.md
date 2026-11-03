---
title: Rescue
sidebar_label: Rescue
sidebar_position: 36
---

# Rescue

Step 5 of the Model setup wizard. It turns rescue on or off, and sets whether rescue flips the
helicopter upright, for every profile.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 5 *Rescue*. One screen with two rows.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Rescue | Off or on. Rescue needs a rescue switch: the Modes step (step 3) assigns it. Without a switch the row is greyed out and the step says so. |
| Flip upright | Whether a rescue from inverted flight flips the helicopter back upright, or does not flip. |

## Notes

- The rescue settings are kept for each profile on the flight controller. The wizard sets the same
  values on every profile, so the flight profile you fly does not matter.
- Rescue uses the accelerometer, so the step needs one, as the Board orientation step (step 1) sets it up.
- The settings are written to the flight controller at once. Discard puts the original values back
  on every profile.

## Related

- [Mode switches](modes.md): the rescue switch.
- [Profiles & gain](profiles.md): the profile switch that the rescue settings apply to.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
