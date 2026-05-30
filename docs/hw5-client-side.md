# HobbyWing Platinum V5 Client-Side Integration

This document describes how the Rotorflight Lua/Ethos Suite client handles HobbyWing Platinum V5 ESC parameters through the `ESC_PARAMETERS_HW5` MSP API.

It is intended as a maintenance guide for future model additions, table updates, and protocol debugging.

## Scope

The HW5 client-side code lives in these files:

- `src/rfsuite/tasks/scheduler/msp/api/ESC_PARAMETERS_HW5.lua`
  - Raw MSP API definition.
  - Parses the firmware-provided HW5 parameter payload.
  - Selects model-specific byte positions.
  - Builds write payloads.
- `src/rfsuite/app/modules/esc_tools/tools/escmfg/hw5/profile.lua`
  - Model-specific UI option tables.
  - Model-specific visible page fields.
  - Runtime profile selection from ESC identity.
- `src/rfsuite/app/modules/esc_tools/tools/escmfg/hw5/pages/*.lua`
  - Basic, advanced, and other ESC setup pages.
  - Load the profile helper and apply page-specific filtering.
- `src/rfsuite/app/lib/ui.lua`
  - Generic page read/write binding.
  - Copies parsed MSP values into form fields.
  - Important: zero is a valid field value and must not be treated as missing.

Firmware owns the real ESC serial protocol and exposes the client-facing MSP read/write shape. The Lua client should not attempt to speak the HobbyWing serial protocol directly.

## MSP Commands

The Lua API uses:

| MSP API | Command | Direction | Purpose |
| --- | ---: | --- | --- |
| `ESC_PARAMETERS_HW5` | `217` | read | Read combined HW5 device info and parameter bytes |
| `ESC_PARAMETERS_HW5` | `218` | write | Write updated HW5 parameter bytes |

The MSP payload starts with a two-byte Rotorflight parameter header. For the HW5 client, `mspHeaderBytes = 2`.

The HW5 ESC signature byte is:

```text
0xFD
```

The client uses this as `esc_signature`.

## Client Payload Shape

Lua receives a flattened MSP-visible payload. It is not the raw HobbyWing `0x3538` serial frame.

Current logical shape:

| Lua position | Field | Size |
| ---: | --- | ---: |
| 1 | `esc_signature` | 1 |
| 2 | `esc_command` | 1 |
| 3 | `firmware_version` | 16 |
| 19 | `hardware_version` | 16 |
| 35 | `esc_type` | 16 |
| 51 | `mode_name` | 15 |
| 66+ | model-specific item bytes | 1 each |

The base strings are fixed-position fields:

```lua
BASE_POS = {
    esc_signature = {start = 1, size = 1},
    esc_command = {start = 2, size = 1},
    firmware_version = {start = 3, size = 16},
    hardware_version = {start = 19, size = 16},
    esc_type = {start = 35, size = 16},
    mode_name = {start = 51, size = 15}
}
```

Item byte positions are calculated from:

```lua
position = BASE_POS.mode_name.start + BASE_POS.mode_name.size + itemIndex - 1
```

With the current base positions, item 1 is Lua byte position `66`.

## Firmware Relationship

The firmware reads the full writable HW5 block from the ESC using HobbyWing `0x3538`. The full `0x3538` read includes bytes that the MSP client does not expose directly.

Important firmware behavior:

- It caches the first writable half of the full HW5 `0x3538` read.
- It exposes device info plus the MSP-visible parameter bytes to Lua.
- It preserves hidden bytes when the Lua client writes only visible fields.
- It sends a software reset after successful write/readback so settings apply.

The Lua client therefore sends back the same flattened MSP-visible shape it read, with only edited visible fields changed.

Do not add a Lua-side HobbyWing commit command. The firmware handles the serial write and reset sequence.

## Read Flow

Page load flow:

1. A HW5 page declares `ESC_PARAMETERS_HW5` in `apidata.api`.
2. `ui.requestPage()` loads the API and queues MSP command `217`.
3. The API parser `parseRead()` receives the MSP buffer.
4. `parseRead()` extracts:
   - `hardware_version`
   - `esc_type`
   - all fixed base fields
   - model-specific item bytes
   - a `positionmap` used by the generic cache/write path
5. `ui.requestPage()` stores API data in:
   - `tasks.msp.api.apidata.values[apiName]`
   - `tasks.msp.api.apidata.structure[apiName]`
   - `tasks.msp.api.apidata.receivedBytes[apiName]`
   - `tasks.msp.api.apidata.receivedBytesCount[apiName]`
   - `tasks.msp.api.apidata.positionmap[apiName]`
   - `tasks.msp.api.apidata.other[apiName]`
6. `ui.mspApiUpdateFormAttributes()` copies parsed values into page fields.
7. The page `postLoad()` calls `hw5Profile.postLoad(pageKey)` to apply final model-specific choice tables and enable/disable state.

Zero-valued fields are valid. For example:

- `volt_cutoff_type = 0` means Soft Cutoff.
- `bec_voltage = 0` can mean the first BEC option.
- `lipo_cell_count = 0` can mean Auto Calculation.

The form loader must use `value ~= nil`, not a truthy check, when copying API values into form fields.

## Write Flow

Page save flow:

1. `ui.saveSettings()` copies current form field values into the API payload data table.
2. It loads `ESC_PARAMETERS_HW5`.
3. The API uses its custom `buildWritePayload()`.
4. `buildWritePayload()` starts from the cached received bytes.
5. It recalculates HW5 item positions from the received `hardware_version` and `esc_type`.
6. It overlays only currently editable page fields.
7. It returns the full MSP-visible byte stream for command `218`.

The custom HW5 write builder exists because HW5 item order is model-specific. A stale generic `positionmap` can write a valid UI value to the wrong byte after swapping between ESC models. The HW5 write builder recalculates positions from the current received buffer at save time.

Only visible/editable form fields are overlaid. Hidden fields are preserved from the readback buffer.

## Model-Specific Item Layouts

The HW5 protocol is not one universal layout. Different models use different item order.

The API parser keeps layout separate from UI option tables:

- `ESC_PARAMETERS_HW5.lua` owns raw byte position layout.
- `profile.lua` owns display tables and page field visibility.

### Default Layout

Used by known standard V5 models such as:

- `HW1104_V100456NB`
- `HW1106_V100456NB`
- `HW1106_V200456NB`
- `HW1106_V300456NB`
- `HW1121_V100456NB`
- `HW1121_V00456NB`
- `HW198_V1.00456NB`

Layout:

| Item | Field |
| ---: | --- |
| 1 | `flight_mode` |
| 2 | `lipo_cell_count` |
| 3 | `volt_cutoff_type` |
| 4 | `cutoff_voltage` |
| 5 | `bec_voltage` |
| 6 | `startup_time` |
| 7 | `gov_p_gain` |
| 8 | `gov_i_gain` |
| 9 | `auto_restart` |
| 10 | `restart_time` |
| 11 | `brake_type` |
| 12 | `brake_force` |
| 13 | `timing` |
| 14 | `rotation` |
| 15 | `active_freewheel` |
| 16 | `startup_power` |

This layout is confirmed by HobbyWing USB Link files such as:

```text
C:\Program Files (x86)\HobbyWing USB Link\Lcd\Platinum_V5 HW1121_V100456NB E.ini
```

### OPTO Layout

Known OPTO profiles omit BEC voltage and shift later fields left.

Layout:

| Item | Field |
| ---: | --- |
| 1 | `flight_mode` |
| 2 | `lipo_cell_count` |
| 3 | `volt_cutoff_type` |
| 4 | `cutoff_voltage` |
| 5 | `startup_time` |
| 6 | `gov_p_gain` |
| 7 | `gov_i_gain` |
| 8 | `auto_restart` |
| 9 | `restart_time` |
| 10 | `brake_type` |
| 11 | `brake_force` |
| 12 | `timing` |
| 13 | `rotation` |
| 14 | `active_freewheel` |
| 15 | `startup_power` |

The page profile hides `bec_voltage` for OPTO variants.

### HW1132 Layout

`HW1132_V100456NB` is non-default. It swaps the cutoff/BEC/cutoff-type order.

Layout:

| Item | Field |
| ---: | --- |
| 1 | `flight_mode` |
| 2 | `lipo_cell_count` |
| 3 | `cutoff_voltage` |
| 4 | `bec_voltage` |
| 5 | `volt_cutoff_type` |
| 6 | `startup_time` |
| 7 | `gov_p_gain` |
| 8 | `gov_i_gain` |
| 9 | `auto_restart` |
| 10 | `restart_time` |
| 11 | `brake_type` |
| 12 | `brake_force` |
| 13 | `timing` |
| 14 | `rotation` |
| 15 | `active_freewheel` |
| 16 | `startup_power` |

Known HW1132 raw write sequence:

```text
... AIRPLANE_ESC ... 00 00 07 01 00 0F ...
                      ^  ^  ^  ^  ^  ^
                      |  |  |  |  |  startup_time
                      |  |  |  |  volt_cutoff_type
                      |  |  |  bec_voltage
                      |  |  cutoff_voltage
                      |  lipo_cell_count
                      flight_mode
```

The HobbyWing USB Link install inspected during development did not include a `HW1132` INI file, so this layout is based on captured OEM/write behavior.

### HW1128 Layout

`HW1128_V100456NB` is a shorter profile.

Layout confirmed by:

```text
C:\Program Files (x86)\HobbyWing USB Link\Lcd\Platinum_V5 HW1128_V100456NB E.ini
```

Layout:

| Item | Field |
| ---: | --- |
| 1 | `lipo_cell_count` |
| 2 | `volt_cutoff_type` |
| 3 | `cutoff_voltage` |
| 4 | response time, not currently exposed |
| 5 | `brake_type` |
| 6 | `brake_force` |
| 7 | `timing` |
| 8 | `rotation` |
| 9 | `active_freewheel` |
| 10 | `startup_power` |

The current UI profile hides unsupported/unmapped fields and preserves item 4 through delta-style writes.

## UI Profiles And Choice Tables

`profile.lua` handles model-specific display tables and page visibility.

Examples:

- `HW1121_V100456NB` and `HW1121_V00456NB`
  - LiPo: Auto, 3S through 8S.
  - BEC: 5.0V through 12.0V.
  - Brake type: Disabled, Normal, Reverse.
- `HW1132_V100456NB`
  - BEC: 6.0V, 7.4V, 8.4V.
- `HW1128_V100456NB`
  - LiPo: Auto, 2S through 4S.
  - Cutoff voltage: Disabled, 2.5V through 3.8V.
  - Rotation: Forward, Reverse, 4D, 4D Reverse.

All choice tables use raw zero-based ESC values. Therefore profile code sets:

```lua
field.tableIdxInc = -1
```

`convertPageValueTable(table, -1)` turns Lua table index 1 into raw value 0.

If a select box displays the wrong label, check both:

1. The raw byte layout in `ESC_PARAMETERS_HW5.lua`.
2. The display table selected in `profile.lua`.

For example, HW1132 raw BEC value `1` should display as `7.4V` using the HW1132 table. If the default BEC table is selected, raw `1` displays as `5.1V`.

## Profile Selection

ESC identity is extracted from the read payload by the HW5 init module:

- model: bytes 35 to 50, usually `Platinum_V5`
- version: bytes 19 to 34, usually hardware such as `HW1121_V100456NB`
- firmware: bytes 3 to 18, such as `PL-04.1.06`

`profile.lua` primarily selects by `escDetails.version`.

Fallback matching exists for hardware families:

```text
HW1132* -> HW1132_V100456NB
HW1128* -> HW1128_V100456NB
HW1121* -> HW1121_V100456NB
```

This avoids defaulting to a wrong table when the exact hardware string differs slightly.

OPTO detection checks the model or firmware text for `OPTO` and maps to a `_PL_OPTO` profile.

## Adding Or Updating A Model

When adding a new HW5 model:

1. Find the HobbyWing USB Link INI if available:

   ```text
   C:\Program Files (x86)\HobbyWing USB Link\Lcd\Platinum_V5 <hardware> E.ini
   ```

2. Read the `itemN_name`, `itemN_min`, `itemN_max`, and `itemN_value` entries.
3. Determine whether the raw item order matches `DEFAULT_ITEMS`.
4. If the byte order differs, add a new item layout in `ESC_PARAMETERS_HW5.lua`.
5. Update `selectItemLayout()` to select it from `hardware_version` and/or `esc_type`.
6. Add or update a profile in `profile.lua`.
7. Add model-specific choice tables if min/max/options differ.
8. Hide fields not present on the model via `pages = { ... }`.
9. Test read display, save, and readback.

Do not infer a byte layout from UI page order. The UI page order is ergonomic; the ESC byte order is protocol-specific.

## Validation Checklist

For a new or modified HW5 model, verify:

- Initial page load shows the correct active value for every select box, including raw value `0`.
- Changing a value saves and survives re-read.
- The write trace sends changed values in the expected item positions.
- Hidden/unavailable fields are preserved, not zeroed.
- `BEC Voltage` uses the model-specific table.
- `Voltage Cutoff Type` displays Soft/Hard, not `???`.
- Switching between different HW5 ESC models does not reuse stale tables or stale byte positions.

Syntax checks:

```bash
luac -p \
  src/rfsuite/tasks/scheduler/msp/api/ESC_PARAMETERS_HW5.lua \
  src/rfsuite/app/modules/esc_tools/tools/escmfg/hw5/profile.lua \
  src/rfsuite/app/lib/ui.lua
```

Whitespace check:

```bash
git diff --check -- \
  src/rfsuite/tasks/scheduler/msp/api/ESC_PARAMETERS_HW5.lua \
  src/rfsuite/app/modules/esc_tools/tools/escmfg/hw5/profile.lua \
  src/rfsuite/app/lib/ui.lua
```

## Common Failure Modes

### Select Box Shows Blank Or Wrong Active Value

Likely causes:

- Raw value is `0` and code used a truthy check instead of `~= nil`.
- Wrong profile table selected.
- Field is present in UI but not present in model item layout.

### `Voltage Cutoff Type` Shows `???`

Likely causes:

- Parsed byte is actually cutoff voltage due to wrong item layout.
- Default layout was used for a non-default model, or vice versa.
- The field's table does not contain the raw value.

### BEC Displays Wrong Voltage

Likely causes:

- Correct byte parsed but wrong display table selected.
- HW1132 must use `{ "6.0V", "7.4V", "8.4V" }`.
- HW1121/HW1106 V2/V3 typically use 5.0V through 12.0V.

### Save Works Only After Changing A Field

Likely causes:

- Initial form value was not populated.
- Raw `0` was skipped during form binding.
- Form dirty/change state only reflected manual changes.

### Save Does Not Stick

Likely causes:

- Correct display table but wrong byte position on write.
- Stale generic `positionmap` after switching models.
- Hidden bytes were rebuilt instead of preserved.
- Firmware did not complete write/readback/reset.

For HW5, prefer a write trace comparison. A HW1132 BEC change should affect item 4, not item 5.

## Notes From Investigation

The HobbyWing USB Link install contains useful model layout files under:

```text
C:\Program Files (x86)\HobbyWing USB Link\Lcd
```

The SQLite database files are useful for model/version presence, but the `Lcd/*.ini` files are the best source for item order and display options.

The inspected install included `HW1121`, `HW1128`, `HW1104`, `HW1106`, and `HW198` Platinum V5 INI files, but not `HW1132`. HW1132 behavior was established from captured serial/write traces.

