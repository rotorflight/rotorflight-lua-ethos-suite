---
title: Tail rotor
sidebar_label: Tail rotor
sidebar_position: 120
---

# Tail rotor

Step 12 of the Model setup wizard. For a variable-pitch tail it sets the centre, the direction,
the calibration and the end stops. For a motor tail it runs a short spin test and sets the
idle.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 12 *Tail rotor*. The screens depend on the
tail type chosen in the Swashplate step.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

Variable-pitch (servo) tail:

| Setting | What it does |
| --- | --- |
| Centre trim | The tail is held at zero. Adjust until the tail blades have zero pitch. |
| Tail direction | Push the yaw stick right. The tail blades should push the tail left, turning the nose right. Answer Correct, or Wrong way. |
| Tail calibration | The tail is held at 22.5 degrees each way. Measure the tail blade pitch and adjust until it reads 22.5. Without a pitch gauge: fold a square of paper corner to corner (45 degrees). Seen from the tail tip, the fold fits flush between the blades. |
| CW limit, CCW limit | Set the end stops, from 0 to 60 degrees each way. The tail is held at full travel one way, and you lower the limit until the slider stops short of binding. |

Motor tail:

| Setting | What it does |
| --- | --- |
| Tail motor test | Take the tail blades off. Spin the tail motor at the test power (Spin). On a bidirectional tail, Reverse spins it the other way. Stop ends the test. |
| Tail idle | The power the tail motor keeps at zero yaw. Run idle spins the motor at the idle setting to check it; Use test sets the idle to the test power. |

## Notes

- A motor tail shows the motor screens instead of the servo screens.
- "No tail motor output (motor 2) on this flight controller" means the motor tail cannot be
  tested here.
- Take the tail blades off for the motor test.

## Related

- [Tail](../../setup/mixer/tail.md): the tail settings on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
