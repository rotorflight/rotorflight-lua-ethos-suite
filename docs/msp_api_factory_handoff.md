# MSP API Factory Migration Handoff

Date: 2026-02-27
Branch: `apiv2`

## What Was Completed

- Migrated all MSP API modules in `src/rfsuite/tasks/scheduler/msp/api/` to `factory.create(...)`.
- Added shared factory at `src/rfsuite/tasks/scheduler/msp/api/_factory.lua`.
- Updated factory to support:
  - shared read/write plumbing
  - dynamic read payload builders
  - write validation and write-structure guards
  - custom read/write hooks
  - dynamic timeout resolvers for read/write
  - custom UUID resolvers for read/write
  - optional extra exported fields per API module
- Kept compatibility methods expected by callers:
  - `read`, `write`, `data`, `readValue`, `setValue`, `readComplete`, `writeComplete`, `resetWriteStatus`
  - `setCompleteHandler`, `setErrorHandler`, `setUUID`, `setTimeout`, `setRebuildOnWrite`

## High-Risk Paths Explicitly Preserved

- `ESC_PARAMETERS_AM32` normalization/encoding and timeout behavior.
- `RXFAIL_CONFIG` staged write sequencing.
- INI-backed APIs (`BATTERY_INI`, `FLIGHT_STATS_INI`) via custom read/write hooks.
- Read-payload APIs (`VTXTABLE_*`, `RPM_FILTER_V2`, `GET_MIXER_INPUT_*`).

## Validation Performed

- Syntax check for all APIs:
  - `luac -p src/rfsuite/tasks/scheduler/msp/api/*.lua`
  - Passed.

## Recommended Runtime Validation (Radio/Sim)

1. Connect flow:
   - API/FC version, UID, NAME, RTC, RX_MAP, FLIGHT_STATS.
2. Save flow:
   - PID pages (`PID_TUNING`, `PID_PROFILE`), plus eeprom write paths.
3. Complex APIs:
   - `RXFAIL_CONFIG` staged save.
   - `ESC_PARAMETERS_AM32` read/write and timeout behavior.
4. Memory:
   - Enter/exit app repeatedly and compare RAM trend before/after migration.

## Notes

- This commit intentionally scopes to MSP API migration + handoff note only.
- Existing unrelated repository changes were not included.
