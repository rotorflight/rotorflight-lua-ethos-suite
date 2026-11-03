---
title: Tail rotor
sidebar_label: Tail rotor
sidebar_position: 120
---

# Tail rotor

Step 18 of the Model setup wizard. For a variable-pitch tail it sets the centre, the direction,
the calibration and the end stops. For a motor tail it runs a short spin test and sets the
idle.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 18 *Tail rotor*. The screens depend on the
tail type chosen in the Swashplate step.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed. The step needs a swashplate type to be set first.

## Settings

Variable-pitch (servo) tail, four pages with the EdgeTX suite's pictures. Each value is typed in its field:

| Setting | What it does |
| --- | --- |
| Centre trim | The tail is held at zero. Type the trim, from -25 to +25 degrees, until the tail blades have zero pitch. |
| Direction | Push the yaw stick right. The tail blades should push the tail left, turning the nose right. Wrong way reverses the yaw input; the button then reads Normal, and pressing it again takes the reversal back. |
| Rate | The tail calibration rate, from 10 to 500 percent. The tail is held at 22.5 degrees, the side changed with Swap. Measure the tail blade pitch and adjust until it reads 22.5. Without a pitch gauge: fold a square of paper corner to corner (45 degrees). Seen from the tail tip, the fold fits flush between the blades. |
| CW limit, CCW limit | The end stops, from 0 to 60 degrees each way, on one page. The tail is held at full travel on the side chosen with Swap. Lower each limit until the slider stops short of binding. |

Motor tail:

| Setting | What it does |
| --- | --- |
| Tail motor test | Take the tail blades off. Spin the tail motor at the test power (Spin). On a bidirectional tail, Reverse spins it the other way. Stop ends the test. |
| Tail idle | The power the tail motor keeps at zero yaw. Run idle spins the motor at the idle setting to check it; Use test sets the idle to the test power. |

## Notes

- A motor tail shows the motor screens instead of the servo screens.
- The first page is a safety card: the motor is unplugged, and Start is greyed out until that is
  answered.
- The last page has Save and continue, which ends the step.
- "No tail motor output (motor 2) on this flight controller" means the motor tail cannot be
  tested here.
- Take the tail blades off for the motor test.

## Related

- [Tail](../../setup/mixer/tail.md): the tail settings on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
