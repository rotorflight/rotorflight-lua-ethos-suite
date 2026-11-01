---
title: Motor & ESC
sidebar_label: Motor & ESC
sidebar_position: 60
---

# Motor & ESC

Step 9 of the Model setup wizard. It sets the ESC protocol, where the headspeed comes from
(when a governor runs), the motor poles and the gear ratios.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 9 *Motor & ESC*. The step starts with a safety
card: the servos stay unplugged and the blades come off, and Start follows once both are
confirmed. Then the protocol screen, the headspeed source (only when a governor runs), the
motor poles, the main gear ratio, the tail gear ratio (only for a pitch tail) and a summary.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

The main gear ratio screen has a *Gear train* drop-down: *One stage* (the normal case),
*Two stages*, for a gearbox with an intermediate gear, such as the SAB Goblin, or *Ratio only*, when
you know the ratio but not the teeth. The picture
draws the gears to their tooth counts, with the gear you set last in blue and the ratio above
it. A two-stage gear train is drawn from the side, as a gearbox drawing: the shafts stand upright,
the two stages sit one above the other, and each gear is a bar as long as its diameter. The tail ratio has its own screen, so the two are not mixed up. Each stage's two counts sit side by
side, as "22 : 60" (pinion : intermediate gear), to save room.

## Settings

| Setting | What it does |
| --- | --- |
| ESC protocol | A drop-down with PWM, DShot150 and DShot300 first, then every other protocol: DShot600, Castle, OneShot, ProShot, DISABLED and the rest. SRXL2 is added from API 12.10. Use PWM if you are not sure. DShot600 picks up noise on long ESC leads. |
| Headspeed source | Only when a governor runs. Wire: an RPM sensor or the ESC's own RPM output. Bidirectional DShot: the ESC sends the RPM back on the DShot signal. Set by the protocol: DShot300 and DShot600 choose bidirectional DShot, the others a wire. You can change it. |
| Motor poles | Magnet poles of the main motor, from its data sheet (often 10 or 12). The picture shows the bell with that many magnets. |
| Gear train | One stage, or two stages with an intermediate shaft (for example a SAB Goblin). Two stages show four counts: the pinion, the intermediate gear that meshes with the pinion, the intermediate gear that meshes with the main gear, and the main gear. |
| Pinion teeth, Main gear teeth | Teeth on the motor pinion and the main gear. In one stage they give the main ratio, shown as n:1. |
| Intermediate, pinion side / main gear side | Teeth of the two gears on the intermediate shaft: the one that meshes with the pinion, and the one that meshes with the main gear. Both sit on one shaft. |
| Gear train (tail) | One stage: the tail drive gear sits on the main shaft. Two stages: a pulley on an intermediate shaft drives the tail, as on the SAB Goblin or a T-Rex. Works with a one-stage or a two-stage main gear. The ratio is always counted from the main rotor shaft, as drive : tail: a 100 : 21 pulley pair reads 4.76. |
| Intermediate : main gear, drive : tail rotor pulley | Intermediate shaft only: the intermediate gear that meshes with the main gear, then the main gear (the same values as on the main gear screen). Then the drive pulley on the intermediate shaft and the tail rotor pulley. They give the tail ratio. Pitch tail only. |
| Tail gear in, Tail gear out | Main shaft: teeth on the tail drive gear and on the tail rotor shaft gear. They give the tail ratio. Pitch tail only. |

## Ratio only

If you know only the overall ratio (the SAB manual's 9.7:1, for example), choose *Ratio only* and
enter the ratio to two decimals. No teeth are needed, so the picture shows the gear train as a fixed
drawing without counts. The flight controller needs whole counts: the wizard stores the smallest
whole pair at that exact ratio, for 9.70 that is 10 and 97 (97 / 10 = 9.70). The same choice is on
the tail screen, where the ratio is drive : tail (a 100 : 21 pulley pair reads 4.76).

## Two-stage gear trains

The flight controller stores the ratio as two numbers: the pinion times the intermediate gear on
the main side, and the intermediate gear on the pinion side times the main gear. The ratio is
the second divided by the first, so for the SAB Goblin 700 (pinion 22, intermediate 60 and 19,
main gear 68) the stored numbers are 22 x 19 = 418 and 60 x 68 = 4080: a ratio of 9.76:1. The
SAB manual gives 9.7.

When you switch to two stages, both intermediate gears take the main gear's count, so each is 1:1 with the main gear. The main ratio and a tail drive from the intermediate shaft stay the same. Enter the real intermediate teeth afterwards.

A gear that is not set (0 in the flight controller) reads as 1, so an unset gear train is 1:1. Switching back to one stage divides the two numbers by their common factor. The ratio stays the same, but the numbers are then the reduced products, not the teeth: the Goblin example gives 209 and 2040.

The four counts are kept while the wizard stays open. When you come back later, the flight
controller only shows the two products. The drop-down then reads *One stage*, and the two
numbers are the products, not the teeth. The ratio is still correct, but the counts are not
shown again.

## Tail drive from the intermediate shaft

With a tail that hangs on an intermediate shaft, the main gear drives that shaft through the
intermediate gear on the main side, and a pulley on the shaft drives the tail. With a two-stage main
gear the wizard takes the main gear and the main-side intermediate gear from the main train. With a
one-stage main gear (a T-Rex) you enter the intermediate gear that meshes with the main gear. The
flight controller stores the two products: the main gear times the drive pulley, and the
main-side intermediate gear times the tail rotor pulley. The ratio is the same as for a tail on the
main shaft, and it follows when the main gear changes. Like the main train, these counts are kept
while the wizard stays open.

## Notes

- DShot150 has no bidirectional DShot, so the flight controller gets no RPM from it. While
  DShot150 is set, the headspeed source shows that the governor needs DShot300 or an RPM
  sensor, and bidirectional DShot cannot be chosen. An ESC that does not answer bidirectional
  requests may not arm.
- A governor needs a fast RPM signal: an RPM sensor, or bidirectional DShot telemetry. Serial
  ESC telemetry is too slow for it.
- Leaving Castle turns the ESC sensor off, unless a serial ESC telemetry protocol is set.
- The protocol and the gear ratios apply after the restart at step 10, Connect servos.

## Related

- [Governor](governor.md): the mode, and the headspeed the RPM source holds.
- [ESC throttle](../../setup/esc_motors/throttle.md) and [ESC telemetry](../../setup/esc_motors/telemetry.md): the ESC settings on their own pages.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
