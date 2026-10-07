---
title: Throttle
sidebar_label: Throttle
sidebar_position: 20
---

# Throttle

Setup -> ESC & Motors -> Throttle page.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Throttle*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Throttle Protocol | Which signal the FC uses to command the ESCs. The list follows the flight controller - see below. |
| Update frequency | Configures Update frequency. |
| Motor Stop PWM Value | Configures Motor Stop PWM Value. |
| 0% Throttle PWM Value | Configures 0% Throttle PWM Value. |
| 100% Throttle PWM value | Configures 100% Throttle PWM value. |
| Unsynced ESC Update | Configures Unsynced ESC Update. |

## Throttle Protocol

The list is built from what the flight controller reports, not from a fixed table.

| Protocol | When it is offered |
| --- | --- |
| PWM, ONESHOT125, ONESHOT42, MULTISHOT | always |
| DSHOT150, DSHOT300, DSHOT600, PROSHOT | always |
| CASTLE | always - see below |
| SRXL2 | only on firmware speaking MSP API **12.10** or newer |
| DISABLED | always |

`SRXL2` appeared in Rotorflight in August 2026. On older firmware it is not offered,
because selecting a protocol the flight controller does not implement is how a model
ends up with motors that will not spin.

`CASTLE` carries no version restriction here. The suite refuses to work with firmware
below MSP API 12.09 at all, which is already past the point CASTLE arrived, so a gate
would never refuse anything.

**The firmware decides what is actually supported by how it was built**, not by its
version number: DSHOT, CASTLE and SRXL2 are each behind a build flag on the flight
controller. Nothing in the protocol tells the transmitter which flags are set, so the
version is a good approximation and not a guarantee. If a protocol turns out to be
unavailable on your flight controller, the firmware says so when you try to arm.

`BRUSHED` is **not** offered. Hobbywing's protocol numbering once had a slot there; the
firmware removed the support in 2022 and kept the number so the ones after it would not
move, and a flight controller configured with it reports the motor output as disabled.

The *PWM Rate* and throttle-window rows apply to the protocols that have a PWM rate and a
throttle window. They are greyed out for the bidirectional serial protocols, where those
numbers mean nothing.

> A pilot whose flight controller still has the old reserved value stored sees a
> Throttle Protocol row that names nothing. Nothing is lost by saving - the value comes
> back unchanged - but it cannot be read on that row.

## Notes

- Changes are written to the flight controller EEPROM upon Save.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
