---
title: Info
sidebar_label: Info
sidebar_position: 40
---

# Info

Tools -> Diagnostics -> Info page.

## Where to find it

*System* → *Tools* → *Diagnostics* → *Info*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Background task

The three rows at the bottom show the health of the background task, which owns the link to the flight controller, the session and the telemetry.

| Row | What it shows |
| --- | --- |
| *Background task* | *Running* while the task reports a heartbeat, *Not reporting* once the last heartbeat is more than 3 seconds old, and a dash before the first heartbeat. |
| *Heartbeat* | The age of the last heartbeat in seconds. A value that keeps growing means the task has stopped. |
| *Revivals* | How often the suite has rebuilt the task's message queue and scheduler after a stalled tick. A number that rises during a flight means the watchdog is catching a fault. |

The Lua heap and free RAM are on *Diagnostics / Status*.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
