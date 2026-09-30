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

## When the card cannot be written

Samples are buffered on the radio and written out every few seconds. If the card
cannot be opened — removed, full, or not writable — the buffer is **kept**, not
discarded, and the next attempt writes it. A card that comes back mid-flight
therefore costs nothing; before, the first failed attempt threw the whole buffer
away, so a brief disturbance cost the samples since the last successful write.

While the card stays unwritable the buffer holds at most 80 samples and then
starts dropping the oldest, so memory use stays bounded either way.

Every such failure prints one line to the script log:

```
[logging] cannot open LOGS:/rfsuite/telemetry/<id>/<file>.csv -- keeping 20 samples
[logging] write to LOGS:/rfsuite/telemetry/<id>/<file>.csv failed -- keeping 43 samples
[logging] log ended with 61 unwritten samples in LOGS:/rfsuite/telemetry/<id>/<file>.csv
```

One line per streak, not one per attempt, so a card that stays away for a whole
flight does not bury the rest of the output. The line is not behind the
*Debug logs* setting — this is lost flight data, not a developer trace.

The last line is the one that matters: a log that ends while the card was
unwritable says so and counts what was lost. That is the only case where samples
cannot be recovered, because there is no next attempt to recover them in.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
