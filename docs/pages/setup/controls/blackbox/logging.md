---
title: Logging
sidebar_label: Logging
sidebar_position: 20
---

# Logging

Controls -> Blackbox -> Logging page.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Blackbox* → *Logging*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Notes

- Samples are buffered on the radio and written to the card every few seconds. If the card cannot be written the buffer is kept and retried rather than dropped, and each failure streak prints one line to the script log. What that looks like is described under *Logs* → [When the card cannot be written](../../../../logs.md). (#2385, `src/rfsuite/tasks/logging.lua`)

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
