---
title: Swashplate
sidebar_label: Swashplate
sidebar_position: 40
---

# Swashplate

Step 6 of the Model setup wizard. It sets the swashplate type, the main rotor direction and
the tail type.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 6 *Swashplate*. The step shows the
servo layout for the chosen type.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Swashplate type | 120°, 135°, 140°, 90° L, 90° V or Direct. 120° is the most common. The picture shows where the servos sit, seen from above with the nose at the top. |
| Main rotor direction | Clockwise or Counter-CW, seen from above. |
| Tail type | Pitch (servo), Motor, or Motor, 2-way (bidirectional). |
| Tail pin | Where the tail is driven: Servo 4, Motor 2, Own pin, or None. It moves on save where the firmware supports it. |

## Notes

- Swashplate type and tail type apply after the restart at step 9, Connect servos.
- A new tail type resets the yaw mixer rate: 250 for a pitch tail, 1000 for a motor tail,
  keeping its sign.
- When the tail changes between servo and motor, Tail Torque Assist is set to match on every
  PID profile, as the Configurator does on commit.
- The tail pin shows "Set in Mixer" when its current output does not fit the tail type, so the
  wizard cannot move it. Set it in the Mixer then.

## Related

- [Swash](../../setup/mixer/swash.md) and [Tail](../../setup/mixer/tail.md): the same
  settings on their own pages.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
