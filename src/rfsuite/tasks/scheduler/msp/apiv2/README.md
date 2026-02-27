# MSP API v2 Migration

`msp.apiv2` is a compatibility engine for migrating API modules one at a time.

## How it works

- `msp.api` remains the single runtime API entrypoint used by the app.
- Engine selection is done by `msp.setApiEngine("v1" | "v2")`.
- In `v2` mode:
  - If `tasks/scheduler/msp/apiv2/api/<API_NAME>.lua` exists, it is used.
  - Otherwise it transparently falls back to `msp.apiv1`.

## Porting a module

1. Create `tasks/scheduler/msp/apiv2/api/<API_NAME>.lua`.
2. Return a module table compatible with current API contract (`read` and/or `write`, plus existing handler helpers as needed).
3. Enable engine:
   - `msp.setApiEngine("v2")`
4. Validate behavior and memory.

Optional explicit registration:

- `msp.apiv2.register("API_NAME", "custom_file.lua")`
- `msp.apiv2.unregister("API_NAME")`

## Initial v2 startup coverage

The following APIs are already ported for connection/bootstrap flows:

- `API_VERSION`
- `FC_VERSION`
- `UID`
- `NAME`
- `RTC`
- `RX_MAP`
- `FLIGHT_STATS`
