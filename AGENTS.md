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
- `docs/memory-and-module-lifecycle.md` — loadfile() caching, subscription cleanup, why not to reach for collectgarbage()
- `docs/i18n-locales.md`

Note: `docs/system-architecture.md` and `docs/menu-structure.md` (referenced by older commits/comments) were deleted during the Lite-rewrite migration and were never replaced. Section 6 below ("Menu System Rules") describes the pre-rewrite manifest-generator system and may not reflect the current `app/pages/*.lua` + `MENUS` table structure — verify against the actual code before relying on it.

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
- Every `@i18n(key)@` tag must resolve: a missing key is not a build error,
  the pilot just sees the raw tag text on the radio. Check with
  `python bin/i18n/check-tags.py [--lang <locale>]` (exit 1 and file:line
  for each missing key).
- The deploy i18n step records the last deploy's missing keys in
  `.vscode/logs/i18n-unresolved.json` (git-ignored; deleted when a deploy
  resolves everything). If that file exists, tell the user which keys are
  missing and where, even if the current task did not touch them.
- Every string must fit where it is shown on the smallest screen (X18,
  480x320). `max_length` only caps characters; check pixels with
  `python bin/i18n/check-fit.py [--lang <locale...>]` (exit 1 and file:line for
  each string too wide; the `i18n-fit` CI job runs it). Budgets on the X18:
  menu tile 98px, page title 178px (only the page's own name: the header drops
  leading breadcrumb levels), form label 215px, choice 200px. Fix an overflow by
  shortening the text in `bin/i18n/json/`, not by widening the layout. When you
  change English, also set the same `english` in every locale file and supply a
  short translation, or `update-missing-translations.py` resets it to English.

## 8) MSP/API/Scheduler Notes

- Prefer API/task integration patterns already used in `tasks/scheduler/msp/`.
- Be careful with queue behavior and duplicate suppression semantics.
- Avoid adding logging/diagnostics in hot paths unless guarded by explicit debug preferences.

## 9) Change Validation Checklist

Before finishing:
- Verify no generated file drift (`menu`/`i18n`) if source files were touched.
- If you added or changed any `@i18n(...)@` tag, run `python bin/i18n/check-tags.py`
  and fix what it reports.
- If you added or changed any i18n string, or where one is used, run
  `python bin/i18n/check-fit.py` and shorten what it reports.
- Check for hot-path allocations introduced by the change.
- Confirm close/cleanup path exists for new dialogs, handles, or caches.
- Run targeted sanity checks for affected module flows.
- For UI changes, open the affected page in the simulator when the tooling is available
  (Section 11), and include screenshots with the pull request.
- If the change is one a pilot can observe, update that page's file under `docs/pages/` in
  the same pull request, or state on a line of its own why it needs none. The rule is
  [.agents/rules/documentation.md](.agents/rules/documentation.md); the `Documentation rule`
  job in `.github/workflows/pr.yml` fails when neither is there.

## 10) Scope Control

If the repository is already dirty:
- Do not modify unrelated files.
- Touch only files needed for the requested task.

## 11) Testing in the Ethos Simulator

Agents can check UI changes in the Ethos WASM simulator. They can boot the radio, see its screen and operate it with touch, keys and the rotary encoder. Use this to confirm that a page, dialog or widget looks and behaves right before calling a pilot-visible change done.

Tooling:
- **Claude Code:** this repository's `.claude/settings.json` lists the `ethos-tools` marketplace and
  enables its `ethos-simulator` plugin, so Claude Code offers to install it when you trust the folder.
  To install it by hand: `/plugin marketplace add FrSkyRC/ethos-tools` and then
  `/plugin install ethos-simulator@ethos-tools`.
  Its `ethos-navigate` skill covers starting the simulator, the screenshot loop and the radio buttons.
  If `ethos-navigate` is not in the session's skill list (the plugin was installed mid-session, or the
  install was declined), restart the session, or read `simulation/skills/ethos-navigate/SKILL.md` from a
  clone of [FrSkyRC/ethos-tools](https://github.com/FrSkyRC/ethos-tools) and follow it by hand.
- **Other agents:** run `simulation/run_wasm.js --serve` from a clone of
  [FrSkyRC/ethos-tools](https://github.com/FrSkyRC/ethos-tools) directly. Its README lists the commands.

This repository:
- **Simulator build:** board and protocol come from `ethos.board` / `ethos.protocol` in `.vscode/settings.json`.
  The Ethos VS Code extension caches the `<BOARD>_<PROTOCOL>.js` + `.wasm` pair in its global storage
  (`<VS Code user dir>/globalStorage/bsongis.ethos/cache`).
- **Deploy first:** `python .vscode/scripts/deploy.py --lang en --step i18n --step soundpack --step sensors`
  (the same command as the "Deploy & Launch [SIM]" VS Code task).
  This writes `src/rfsuite` to `simulators/<BOARD>_<PROTOCOL>@<release>/scripts/rfsuite`.
- **Mount that folder** (`simulators/<BOARD>_<PROTOCOL>@<release>/`) as the radio's root directory.
  It is git-ignored, so mounting it directly is fine. Don't run a second simulator on the same folder at the same time, for example the VS Code extension's.
- **Boot dialogs:** booting shows a *Select Battery* dialog, then *Battery Profile*, then *Checklist warning*.
  Dismiss each one before any other input. Menu keys are ignored while a dialog is open.
- **Opening the app:** `SYS`, then `PAGE` to System page 2, then the **Rotorflight** tile. The app's own pages are tile grids with a **BACK** button at the top right.
- **Another board, or a fresh radio folder:** a model saved by a newer Ethos build
  will not load on an older one ("Need firmware update"), so for a second board
  (e.g. `X18S_EU`, the smallest screen at 480x320) mount a new folder under the
  scratchpad holding only `scripts/rfsuite` copied from the deployed one. It boots
  through *Select language*, *Storage error, default settings restored* and the
  *Create model* wizard; finish the wizard, then set the model up, or every app tile
  shows *Background task not running*:
  1. Model menu, page 3, **Lua**: turn **Rotorflight [Background]** on.
  2. Model menu, page 1, **RF system**, **Internal module**: turn **State** on.
  3. Model menu, page 2, **Telemetry**: discover sensors if the list is empty.
- **Cached modules:** `app/header.lua` and other shared modules cache themselves in
  `package.loaded`, so a redeploy is not picked up until the simulator restarts
  (`quit`, then start it again).
- **No flight controller needed:** the suite's built-in simulated sensors and MSP responses (`src/rfsuite/sim/sensors/` and the `simulatorResponse` tables in `src/rfsuite/lib/msp_*.lua`) populate pages such as PIDs.
- **Lua errors** appear in the output of the `log` command, not on screen.
