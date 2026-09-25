---
title: Documentation
sidebar_label: RFSuite documentation
---

# RFSuite for Ethos documentation

This folder is the reference for what the tool shows and does: one file per configuration
page, in the layout of the menu on the radio, plus the topics that are not a page. It is
plain Markdown, versioned with the code, and it is not part of the installation archive.

Installing and updating RFSuite, the dashboard and ActiveLook widgets, and audio announcements
are described in the [README](../README.md).

## Map

| Document / Folder | What it holds |
| --- | --- |
| [pages/](pages/README.md) | One file per configuration page, in the menu hierarchy of the system tool. Its index lists every page with its menu path, conditions, and documentation status. |
| [dashboard-themes.md](dashboard-themes.md) | The dashboard widget: available themes, layout specifications, and screenshots. |
| [i18n-locales.md](i18n-locales.md) | Supported languages, locale codes, and translation workflows. |
| [memory-and-module-lifecycle.md](memory-and-module-lifecycle.md) | Ethos Lua runtime memory architecture, closure caches, GC behavior, and lifecycle management. |

## How page documentation is organized

Every configuration page reachable from the system tool (`src/rfsuite/app/tool.lua`) is
documented in a matching file under `docs/pages/`:
- **Flight Tuning:** `docs/pages/flight_tuning/` (PIDs, Rates, Governor, Advanced tuning pages)
- **Setup:** `docs/pages/setup/` (Hardware configuration, Mixer, Servos, Controls, Power, ESC & Motors, Governor)
- **Tools:** `docs/pages/tools/` (Profile tools, Diagnostics, Developer utilities)
- **Logs:** `docs/pages/logs.md` (Flight log browser)
- **Settings:** `docs/pages/settings/` (General, Dashboard, ActiveLook, Audio, Developer settings)

Each page document follows [_template.md](_template.md).

The scaffold generator tool `bin/docs/generate_menu_docs.py` automatically parses page
definitions and form structures, extracts field metadata and constraints, and verifies
documentation completeness.

## Conventions

- **Plain CommonMark:** Renders cleanly on GitHub and can be lifted directly to the Rotorflight website documentation.
- **YAML Frontmatter:** Every page defines `title`, `sidebar_label`, and `sidebar_position` (in multiples of 10 matching menu tile order).
- **Menu Breadcrumbs:** Exact navigation path in bold italic, e.g. `*Configuration* → *Flight Tuning* → *PIDs*`.
- **Preconditions and Guards:** Clear declaration of access constraints (`offline`, `requiresServoBus`, `escProtocolId`, `lockedWhileArmed`).
- **Settings Table:** Tabular listing of each parameter, its purpose, acceptable range, unit, and default value.
- **Version Tag:** Every document records the suite version it was validated against (`*Documented against RFSuite Ethos 2.3.1.*`).
