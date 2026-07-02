# Rotorflight ETHOS Smooth2

This custom build is based on RFSuite 2.3.0 and is identified in the radio as `2.3.0-smooth2`.

## Applied runtime changes

- Long fragmented MSP replies now refresh the retry timer as valid transport packets arrive.
- RFSuite no longer resends a request while its reply is still making progress.
- S.Port/F.Port uses a 0.90-second fragment-inactivity threshold and a 6.0-second transaction window.
- CRSF/ELRS uses a 0.45-second fragment-inactivity threshold and a 3.0-second transaction window.
- Transport-specific queue pacing and limits are reapplied whenever telemetry transport changes.
- No synchronous SD-card writes occur in the live MSP transport path.
- The captured and verified FrSky versioned MSPv1 behavior remains unchanged.

## Field-test checks

- Battery voltage appears after connection.
- Arm state reports `DISARMED`.
- Status, PID Controller, Governor, Filters, and Telemetry pages load.
- Large configuration replies complete without premature retries.
- Repeated page refreshes do not force a reconnect.

The custom MWRC, Aegis, Singularity, and Zafira dashboard themes remain part of the repository.
