# ActiveLook standalone bitmap and layout coordinates

## Evidence

Investigated on 2026-10-20 using the locally cached Ethos X20PRO_EU WASM simulator, HTTP last-modified 2026-10-16 06:13:23 GMT.

SHA-256: `47aa9521def4a5f866078b5ba48313e3b6cc9bb9b47445b026d1d15e047c49b3`.

This is a binary-derived finding for that build, not a claim based on public Ethos source code. WebAssembly table slots were linked to the Lua registration strings in initialized memory. Function numbers below refer to the original WASM function indices and may change in another build.

## Verified conversion

- Lua `glasses.getWindowSize`: table slot 800, function 4435. It returns the current glasses window width and height (accessors 4436/4437).
- Lua `glasses.bitmap`: table slot 803, function 4453. It adds the current window origin (accessors 4439/4440) to the requested x/y. It then calls function 5737 with width=40 and height=40, regardless of image ID.
- Function 5737 converts to native ActiveLook coordinates as `nativeX = 304 - (windowX + x) - 40` and `nativeY = 256 - (windowY + y) - 40`, then transmits the image. Its separate simulator paint path uses a loaded image; that is not evidence that the hardware coordinate mismatch is visually simulated.
- Lua `clearAndDisplayExtended`: table slot 798, function 4819. Explicit x/y fields add the window origin to the supplied values; they override the saved layout position for that call.
- Its layout command builder, function 5772, transmits command 0x6A and converts its position as `nativeX = 304 - (windowX + x) - layoutWidth` and `nativeY = 256 - (windowY + y) - layoutHeight`.
- The suite creates a layout of size `windowWidth - 16` by `windowHeight - 16`, then displays/clears it at local `(0,0)`. Its saved `(8,8)` creation position does not define the position of those Extended calls.

The 28x28 inventory dimensions are recorded in [the frsky manifest](activelook-frsky-v8/manifest.json). The initial model assumed that native image coordinates described the top-left corner and predicted a visual shift of +12 pixels in both axes. **The subsequent device test contradicted the predicted bottom boundary.** The binary formulas above remain observed facts; the inferred physical bounds are not validated.

## Current hardware adjustment

For a 304x256 window, the original model placed the standalone call at (0,200). The pilot reports that only approximately the top pixel row was erased at a phase change. This indicates that most of the image was still below the effective clearing area; it does not establish the exact physical boundary or its cause.

The current diagnostic placement adds 28 pixels of bottom clearance: `maxY = windowHeight - 16 - 40 - 28`, giving Y=172 for a 256px-high window. Positive display offsets cannot move the icon below this bound. This is an adjustment based on the device observation and still needs confirmation; it is not a fully verified map of the maximum erasable rectangle.

## Hardware observations and limits

The pilot reports: ID 0 did not erase icon 6; padded-layout clearing left a horizontal residue; full-display clearing removed it; and the suite cleared a standalone fuel icon requested at (80,120). Those observations are consistent with a position-dependent clipping issue. The first derived bottom-left bound failed on the connected glasses, clearing only approximately the top icon row. The revised 28px-clearance position still requires confirmation. They do not establish a protected status border or the source of the glasses' battery overlay.

## Public protocol reference

[ActiveLook API, layout commands](https://github.com/ActiveLook/Activelook-API-Documentation/blob/main/ActiveLook_API.md#49-layout-commands) documents temporary positioning for the Extended commands. [Image coordinates](https://github.com/ActiveLook/Activelook-API-Documentation/blob/main/ActiveLook_API.md#558-coordinates) and the optical orientation explain why the native and visual rectangles need to be compared after the conversion.
