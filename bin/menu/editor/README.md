# Menu Editor

Tk editor for the menu source manifest.

Source of truth:
- `bin/menu/manifest.source.json`

Generated runtime file:
- `src/rfsuite/app/modules/manifest.lua`

## Run from source

```bash
python bin/menu/editor/src/menu_editor.py
```

## Build Windows EXE

```bat
bin\menu\editor\src\make.cmd
```

This creates:
- `bin/menu/editor/menu_editor.exe`

## Workflow

1. Edit menu/section/page nodes in the tree.
2. For page nodes, use `Quick Edit (Page)` and click `Apply Quick Fields` for common fields.
   Keep `name` human-readable and set `translation` to the i18n tag.
3. For menu/section/group labels, keep `title` human-readable and set `translation` to the i18n tag.
4. Use `Apply Node JSON` for advanced node-level JSON edits.
5. Use `Save Source` to update `manifest.source.json`.
6. Use `Generate Lua` (or `Save + Generate`) to write `manifest.lua`.

The editor uses the same generator logic as `bin/menu/generate.py` for validation and generated output.
