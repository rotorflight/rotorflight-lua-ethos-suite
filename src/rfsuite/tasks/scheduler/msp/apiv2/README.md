# MSP API v2 Migration

`msp.apiv2` is now a standalone API engine (no `apiv1` fallback).

## How it works

- `msp.api` remains the single runtime API entrypoint used by the app.
- Runtime is fixed to `apiv2`; `v1` selection requests are ignored.
- `tasks/scheduler/msp/apiv2/api/<API_NAME>.lua` is loaded directly.
- Missing modules fail fast and are reported in logs.

## Porting a module

1. Create `tasks/scheduler/msp/apiv2/api/<API_NAME>.lua`.
2. Return a module table compatible with current API contract (`read` and/or `write`, plus existing handler helpers as needed).
3. Validate behavior and memory.

Optional explicit registration:

- `msp.apiv2.register("API_NAME", "custom_file.lua")`
- `msp.apiv2.unregister("API_NAME")`

## Baseline coverage

- All API module files from `tasks/scheduler/msp/api/` are now mirrored under `tasks/scheduler/msp/apiv2/api/`.
- Core helpers are local to v2 at `tasks/scheduler/msp/apiv2/core.lua`.
- You can optimize/replace modules incrementally while keeping API contracts stable.
