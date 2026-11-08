---
title: Link
sidebar_label: Link
sidebar_position: 55
---

# Link

Callouts for the flight controller going quiet while the radio link is up, and answering again.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *Link*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Telemetry lost* | Calls out the flight controller when it stops sending **while the model is armed** and the radio link is up, and again once telemetry recovers. On by default. |
| *Vibrate* | Vibrates the radio when the flight controller goes quiet while armed. On by default. Each silence is announced once, so it has no repeat count. |

## Notes

- A link that drops is not announced here. The radio announces a lost RF link itself, so this
  page only covers the case the radio cannot see: the link is up and the flight controller has
  stopped sending.
- The silence is counted after 6 seconds without a flight controller frame, while the link is up.
  Only CRSF (ELRS) telemetry is watched; on other protocols nothing is announced here.
- One switch governs both halves, because the recovery is gated on the silence: the flight
  controller answering again is only announced if its silence was announced, and only while that
  silence is still the same flight.
- A silence while disarmed stays completely silent, for example on the bench or after landing.
  The same silence with the rotors turning is the one event here a pilot must not have to notice
  for himself.
- A model that answers again more than 120 seconds later gets no recovery callout — that is a
  new flight, and "telemetry recovered" belongs to the one that was interrupted.
- The dedicated *Telemetry lost* / *Telemetry recovered* sounds are not in the packs yet, and
  neither has a neighbour worth borrowing: every shipped alert word names a different event, and
  saying a lost link in the words of an empty battery is worse than saying nothing. Until a
  pack carries them the haptic is what sounds, and the words follow as soon as a pack has them.
- Changes are saved to the radio's settings store, not to the flight controller. Nothing here
  is written to flight controller EEPROM.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
