# AGENTS.md

This file is for automated coding agents working in this repository.
Follow these rules before making code changes.

## 1) Primary Goal

Keep behavior correct while minimizing runtime memory churn and CPU load on Ethos radios.

## 2) Architecture Quick Map

- Entry point: `src/rfsuite/main.lua`
- App/UI: `src/rfsuite/app/`
- Background scheduler/tasks/MSP: `src/rfsuite/tasks/`
- Dashboard widgets/objects: `src/rfsuite/widgets/`
- Shared utilities: `src/rfsuite/lib/`
- Menu source and generator: `bin/menu/`
- i18n sources and generators: `bin/i18n/`

Reference docs:
- `docs/system-architecture.md`
- `docs/menu-structure.md`
- `docs/i18n-locales.md`

## 3) Non-Negotiables For Agent Changes

- Do not regress memory behavior in wakeup/render paths.
- Do not hand-edit generated artifacts when a generator is the source of truth.
- Keep deltas focused and minimal.
- Prefer explicit cleanup on page/module close.
- Preserve offline/post-connect behavior in menu and task logic.

## 4) GC Churn Guardrails (Critical)

Treat all high-frequency paths (`wakeup`, `paint`, scheduler callbacks) as hot paths.

Avoid:
- Allocating new tables/arrays every wakeup.
- Rebuilding formatted strings every wakeup when input values did not change.
- Recreating closures/handlers repeatedly for static buttons.
- Repeated `lcd.loadMask`/image loads without cache.
- Repeated `field:enable(...)` calls when state is unchanged.
- Replacing a live queue table (`queue = {}`) where clearing in-place is enough.

Prefer:
- Reuse buffers/tables and clear them in-place.
- Cache computed values and update only when quantized display values change.
- Cache color/mask/image resolution outputs when inputs are stable.
- Prebuild tiny animation states (for example loading dots table) instead of `string.rep`.
- Reuse handler functions per menu/module key instead of creating per rebuild.
- Gate UI/state updates behind change detection (`if last ~= current then ... end`).

## 5) Cleanup Rules

When closing a page/module/app:
- Close progress/save dialogs.
- Close file handles.
- Clear page-specific caches.
- Clear image/mask caches when leaving app or page flows that own them.
- Nil large transient references if they are no longer needed.

When clearing collections:
- Prefer wiping keys in-place for reusable tables.
- Only replace the whole table when index-reset semantics are intentional.

## 6) Menu System Rules

Menu source of truth:
- `bin/menu/manifest.source.json`

Generated runtime manifest:
- `src/rfsuite/app/modules/manifest.lua`

Commands:
- `python bin/menu/generate.py`
- `python bin/menu/generate.py --check`

Rules:
- Do not manually edit `src/rfsuite/app/modules/manifest.lua`.
- If menu structure changes, update source JSON and regenerate.
- Keep `docs/menu-structure.md` aligned with structural changes.

## 7) i18n Rules

i18n source of truth:
- `bin/i18n/json/<locale>.json`

Generated runtime locale files:
- `src/rfsuite/i18n/<locale>.json`

Commands:
- `python bin/i18n/update-missing-translations.py [--only <locale...>]`
- `python bin/i18n/update-max-lengths.py [--only <locale...>]`
- `python bin/i18n/build-single-json.py [--only <locale...>]`

Rules:
- Do not hand-edit generated files in `src/rfsuite/i18n/` if a source JSON change is intended.
- Keep translation key structure consistent with `en.json`.

## 8) MSP/API/Scheduler Notes

- Prefer API/task integration patterns already used in `tasks/scheduler/msp/`.
- Be careful with queue behavior and duplicate suppression semantics.
- Avoid adding logging/diagnostics in hot paths unless guarded by explicit debug preferences.

## 9) Change Validation Checklist

Before finishing:
- Verify no generated file drift (`menu`/`i18n`) if source files were touched.
- Check for hot-path allocations introduced by the change.
- Confirm close/cleanup path exists for new dialogs, handles, or caches.
- Run targeted sanity checks for affected module flows.

## 10) Scope Control

If the repository is already dirty:
- Do not modify unrelated files.
- Touch only files needed for the requested task.

