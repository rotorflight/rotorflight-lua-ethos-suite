# Documentation Maintenance Rule

## Mandatory Workflow Requirement
Whenever changes are made to the codebase that a pilot can observe (a new configuration page, a new or removed setting, changed behaviour, a new widget or dashboard theme option, a new audio announcement, or a removed feature) and a Pull Request is prepared:
1. **Always maintain and update the documentation under `docs/`**:
   - Update the file of the page that changed: `docs/pages/<page path>.md`, mirroring the path of the page under `src/rfsuite/app/pages/`. A surface that is not a page (the dashboard widget, an announcement, the user folder) has its file under `docs/dashboard/`, `docs/audio/` or `docs/reference/`.
   - When a page is added or removed, update the index `docs/pages/README.md` in the same PR.
   - Follow `docs/_template.md`: what the page does, where to find it (the menu path, and the conditions under which it is hidden, greyed out or read-only), one line per setting, related flight-controller documentation, and the release the page was checked against.
   - Record the hiding and locking conditions exactly as the manifest declares them (`enabledWhen`, `visibleWhen`, `lockedWhileArmed`, `minApiVersion`, `hideWhenDisabled`).
   - Keep the page file and the page's `help.lua` consistent. `help.lua` is the short explanation behind the `?` button and the page file is the full one; they must not contradict each other, and a change that affects one is applied to both.
   - Reference the affected module / page path and the issue / PR number where applicable.
2. **Include the documentation change in the PR**:
   - The updated documentation must be committed as part of the PR so `docs/` stays in sync with master at all times.
   - If a change genuinely needs no documentation update, say so explicitly in the PR body and give the reason, on a line of its own beginning with `Documentation:` (a bullet and bold markers are allowed, for example `- **Documentation.** No page: ...`). The `Documentation rule` job in `.github/workflows/pr.yml` reads that line; it does not judge the reason, it only makes sure the rule cannot be skipped in silence.
