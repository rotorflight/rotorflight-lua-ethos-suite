---
title: Logs
sidebar_label: Logs
sidebar_position: 10
---

# Logs

System -> Logs browser/viewer.

## Where to find it

*System* → *Logs*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## One flight, one log

A log is opened when the model arms and closed when it disarms. A short loss of
telemetry while the model is still armed — behind an obstacle, or in a fast pass
— no longer splits that flight into two logs, so the peaks the viewer shows are
the peaks of the whole flight.

Two things still end a log and start a new one:

* **Disarming.** A log always ends when the pilot disarms, whether the link
  stayed up or not. Landing, disarming and rearming therefore always produces a
  separate log, whatever happened to the pack in between.
* **A gap longer than 30 seconds.** If the link is gone for longer than that, the
  record is closed rather than resumed. Losing the link for over half a minute is
  not treated as the same flight.

The time shown by the flight timer follows the same rule, so the timer, the log
and the flight count in the statistics agree with each other.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
