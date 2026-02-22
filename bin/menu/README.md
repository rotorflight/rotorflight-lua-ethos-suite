# Menu Manifest Generator

Source of truth:
- `bin/menu/manifest.source.json`

Generated runtime file:
- `src/rfsuite/app/modules/manifest.lua`

Generator behavior:
- Adds deterministic `shortcutId` fields to menu pages in generated `manifest.lua`.
- Supports source text + i18n reference pairs:
  - page: `name` + `translation`
  - menu/group/section: `title` + `translation`
  In generated Lua, `translation` is emitted as runtime `name`/`title`.
- This keeps shortcut selections stable when menu order changes.

Generate:

```bash
python bin/menu/generate.py
```

Windows wrapper:

```bat
bin\menu\generate.cmd
```

Verify generated file is up to date:

```bash
python bin/menu/generate.py --check
```

Menu editor (Tk):

```bash
python bin/menu/editor/src/menu_editor.py
```

Windows wrapper:

```bat
bin\menu\editor\menu_editor.cmd
```

Do not edit `src/rfsuite/app/modules/manifest.lua` directly.
