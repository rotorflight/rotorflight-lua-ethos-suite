# Background instruction backoff

On Ethos versions exposing `system.getInstructionsUsage()` (26.1.3+), background
frame drains also stop when the current execution cycle's instruction usage
reaches a conservative threshold: 60% for MSP receive/cleanup and the nested
S.Port reply search, 70% for ELRS custom telemetry. Existing time and frame caps
still apply. Older versions retain their original behaviour without this API.

Checks run before consuming the next frame. Partial MSP replies remain assembled
in memory, unread frames remain in the transport queue, and ELRS requests another
drain on the next background wakeup. Cleanup always resets MSP state even when
its optional stale-frame drain is skipped. No per-check tables, strings or
closures are allocated. Capability references are cached when modules load.

These thresholds reserve headroom for subsequent session updates, alerts and
keepalives; they are initial guardrails, not hardware-measured guarantees. A
single frame decode or native API call cannot be interrupted, instruction usage
does not measure SD-card latency, and sustained overload can still delay replies
or overflow native telemetry queues. Boot loading and task scheduling remain
unchanged. The existing `bin/perf/verify_clock_budgets.lua` harness covers absent
API behaviour, pause/resume, nested S.Port draining and long MSP reply assembly.

### Dashboard object wakeups

The dashboard engine also pauses its object-wakeup loop at 70% instruction
usage when the API is available. It retains the current object cursor and resumes
on the next callback; normal backoff does not count as an object failure or emit
an error. Existing object-count pacing still applies, including on older Ethos
versions without the API. The shared loop also covers initial object preparation
requested by paint; drawing itself is unchanged. Resetting the engine clears the
paused cursor. A single object cannot be interrupted by this check, so the
threshold still needs on-radio validation.
