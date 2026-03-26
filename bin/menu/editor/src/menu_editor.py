#!/usr/bin/env python3
"""
Tk editor for `bin/menu/manifest.source.json`.
"""

from __future__ import annotations

import copy
import importlib.util
import json
import os
import re
import sys
import traceback
from pathlib import Path
import tkinter as tk
from tkinter import messagebox
from tkinter import simpledialog
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

APP_TITLE = "RF Suite Menu Editor"
SOURCE_REL = Path("bin/menu/manifest.source.json")
GENERATOR_REL = Path("bin/menu/generate.py")
OUTPUT_REL = Path("src/rfsuite/app/modules/manifest.lua")
I18N_EN_RELS = (Path("bin/i18n/json/en.json"), Path("src/rfsuite/i18n/en.json"))
I18N_TAG_RE = re.compile(r"^@i18n\(([^)]+)\)@$")


def candidate_roots() -> list[Path]:
    starts = [Path.cwd().resolve(), Path(__file__).resolve().parent]
    if getattr(sys, "frozen", False):
        starts.insert(0, Path(sys.executable).resolve().parent)

    roots: list[Path] = []
    seen: set[str] = set()
    for start in starts:
        for root in (start, *start.parents):
            key = str(root)
            if key in seen:
                continue
            seen.add(key)
            roots.append(root)
    return roots


def find_repo_root() -> Path:
    for root in candidate_roots():
        if (root / SOURCE_REL).is_file() and (root / GENERATOR_REL).is_file():
            return root
    raise FileNotFoundError(
        "Could not find repository root containing bin/menu/manifest.source.json"
    )


def optional_bool_to_text(value) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "false"}:
            return lowered
    return ""


def parse_optional_bool(text: str, field_name: str):
    lowered = text.strip().lower()
    if lowered == "":
        return None
    if lowered in {"true", "1", "yes", "on"}:
        return True
    if lowered in {"false", "0", "no", "off"}:
        return False
    raise ValueError(
        f"Field '{field_name}' must be blank, true, or false (got: {text!r})"
    )


def is_i18n_tag(value: str) -> bool:
    return bool(I18N_TAG_RE.match(value.strip()))


def friendly_i18n_label(value: str) -> str:
    match = I18N_TAG_RE.match(value.strip())
    if not match:
        return value
    token = match.group(1)
    tail = token.split(".")[-1]
    return tail.replace("_", " ")


def pick_friendly_name(name_value, translation_value) -> str:
    if isinstance(name_value, str) and name_value.strip() and not is_i18n_tag(name_value):
        return name_value.strip()
    if isinstance(translation_value, str) and translation_value.strip() and not is_i18n_tag(translation_value):
        return translation_value.strip()
    if isinstance(name_value, str) and name_value.strip():
        return friendly_i18n_label(name_value.strip())
    if isinstance(translation_value, str) and translation_value.strip():
        return friendly_i18n_label(translation_value.strip())
    return ""


class MenuEditorApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()

        self.repo_root = find_repo_root()
        self.source_path = self.repo_root / SOURCE_REL
        self.generator_path = self.repo_root / GENERATOR_REL
        self.output_path = self.repo_root / OUTPUT_REL

        self.generator = self.load_generator_module()
        self.i18n_en_data = self._load_i18n_en_data()
        self.script_menu_targets = self._build_script_menu_targets()

        self.title(APP_TITLE)
        self.geometry("1520x900")
        self.minsize(1200, 760)

        self.path_var = tk.StringVar(value="")
        self.status_var = tk.StringVar(value="")
        self.source_var = tk.StringVar(value=str(self.source_path))
        self.quick_name_var = tk.StringVar(value="")
        self.quick_translation_var = tk.StringVar(value="")
        self.quick_script_var = tk.StringVar(value="")
        self.quick_menu_id_var = tk.StringVar(value="")
        self.quick_image_var = tk.StringVar(value="")
        self.quick_shortcut_id_var = tk.StringVar(value="")
        self.quick_order_var = tk.StringVar(value="")
        self.quick_offline_var = tk.StringVar(value="")
        self.quick_bgtask_var = tk.StringVar(value="")
        self.quick_disabled_var = tk.StringVar(value="")

        self.data: dict = {}
        self.dirty = False
        self.node_paths: dict[str, tuple] = {}

        self._build_ui()
        self._load_manifest()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def load_generator_module(self):
        spec = importlib.util.spec_from_file_location("menu_generate", self.generator_path)
        if spec is None or spec.loader is None:
            raise RuntimeError(f"Unable to import generator module: {self.generator_path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        required = ["validate_manifest", "inject_shortcut_ids", "render_manifest"]
        for name in required:
            if not hasattr(module, name):
                raise RuntimeError(f"Generator is missing required symbol: {name}")
        return module

    def _load_i18n_en_data(self):
        for rel in I18N_EN_RELS:
            path = self.repo_root / rel
            if not path.is_file():
                continue
            try:
                loaded = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue
            if isinstance(loaded, dict):
                return loaded
        return {}

    def _lookup_i18n_text(self, token: str) -> str | None:
        if not isinstance(token, str) or token.strip() == "":
            return None
        cursor = self.i18n_en_data
        for part in token.split("."):
            if not isinstance(cursor, dict) or part not in cursor:
                return None
            cursor = cursor[part]

        if isinstance(cursor, str):
            return cursor
        if isinstance(cursor, dict):
            translated = cursor.get("translation")
            if isinstance(translated, str) and translated.strip() != "":
                return translated.strip()
            english = cursor.get("english")
            if isinstance(english, str) and english.strip() != "":
                return english.strip()
        return None

    def _display_label(self, value) -> str:
        if not isinstance(value, str):
            return ""
        trimmed = value.strip()
        if trimmed == "":
            return ""
        match = I18N_TAG_RE.match(trimmed)
        if match is None:
            return trimmed

        token = match.group(1)
        resolved = self._lookup_i18n_text(token)
        if resolved:
            return resolved
        return friendly_i18n_label(trimmed)

    def _build_script_menu_targets(self) -> dict[str, str]:
        targets: dict[str, str] = {}
        modules_root = self.repo_root / "src/rfsuite/app/modules"
        pattern = re.compile(r'createFromManifest\("([A-Za-z0-9_]+)"\)')
        if not modules_root.is_dir():
            return targets

        for root, _, files in os.walk(modules_root):
            for filename in files:
                if not filename.endswith(".lua"):
                    continue
                file_path = Path(root) / filename
                try:
                    text = file_path.read_text(encoding="utf-8", errors="ignore")
                except Exception:
                    continue
                match = pattern.search(text)
                if not match:
                    continue
                rel = file_path.relative_to(modules_root).as_posix()
                targets[rel] = match.group(1)
        return targets

    def _normalize_manifest_script_path(self, script_path: str | None) -> str | None:
        if not isinstance(script_path, str):
            return None
        value = script_path.strip()
        if value == "":
            return None
        if value.startswith("app/modules/"):
            value = value[len("app/modules/"):]
        return value

    def _resolve_script_link_target(self, script_path: str | None) -> str | None:
        normalized = self._normalize_manifest_script_path(script_path)
        if normalized is None:
            return None
        return self.script_menu_targets.get(normalized)

    def _resolve_section_link_target(self, section: dict) -> str | None:
        menu_id = section.get("menuId")
        if isinstance(menu_id, str) and menu_id.strip() != "":
            return menu_id.strip()

        module = section.get("module")
        script = section.get("script")
        if isinstance(module, str) and isinstance(script, str):
            return self._resolve_script_link_target(f"{module}/{script}")
        return None

    def _resolve_page_link_target(self, menu_id: str, menu_spec: dict, page: dict) -> str | None:
        direct_menu_id = page.get("menuId")
        if isinstance(direct_menu_id, str) and direct_menu_id.strip() != "":
            return direct_menu_id.strip()

        script_candidates: list[str] = []
        script = page.get("script")
        if isinstance(script, str):
            script_candidates.append(script)
        script_default = page.get("script_default")
        if isinstance(script_default, str):
            script_candidates.append(script_default)

        version_rules = page.get("script_by_mspversion")
        if isinstance(version_rules, list):
            for rule in version_rules:
                if isinstance(rule, dict):
                    rule_script = rule.get("script")
                    if isinstance(rule_script, str):
                        script_candidates.append(rule_script)

        prefix = menu_spec.get("scriptPrefix")
        if not isinstance(prefix, str):
            prefix = ""

        for script_entry in script_candidates:
            normalized = self._normalize_manifest_script_path(script_entry)
            if normalized is None:
                continue
            if script_entry.startswith("app/modules/"):
                linked_menu = self._resolve_script_link_target(script_entry)
            else:
                linked_menu = self._resolve_script_link_target(prefix + script_entry)
            if isinstance(linked_menu, str) and linked_menu.strip() != "":
                return linked_menu.strip()
        return None

    def _build_ui(self) -> None:
        toolbar = ttk.Frame(self)
        toolbar.pack(fill=tk.X, padx=10, pady=(8, 4))

        ttk.Label(toolbar, text="Source:").pack(side=tk.LEFT)
        source_entry = ttk.Entry(toolbar, textvariable=self.source_var, state="readonly")
        source_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(6, 10))

        ttk.Button(toolbar, text="Reload", command=self._reload_clicked).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="Save Source", command=self._save_manifest).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="Validate", command=self._validate_clicked).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="Generate Lua", command=self._generate_clicked).pack(side=tk.LEFT, padx=2)
        ttk.Button(toolbar, text="Save + Generate", command=self._save_generate_clicked).pack(side=tk.LEFT, padx=2)

        actions = ttk.Frame(self)
        actions.pack(fill=tk.X, padx=10, pady=(0, 8))

        self.add_menu_button = ttk.Button(actions, text="Add Menu", command=self._add_menu)
        self.add_menu_button.pack(side=tk.LEFT, padx=2)
        self.add_page_button = ttk.Button(actions, text="Add Page", command=self._add_page)
        self.add_page_button.pack(side=tk.LEFT, padx=2)
        self.add_section_group_button = ttk.Button(
            actions,
            text="Add Section Group",
            command=self._add_section_group,
        )
        self.add_section_group_button.pack(side=tk.LEFT, padx=2)
        self.add_section_button = ttk.Button(actions, text="Add Section", command=self._add_section)
        self.add_section_button.pack(side=tk.LEFT, padx=2)

        self.delete_button = ttk.Button(actions, text="Delete Selected", command=self._delete_selected)
        self.delete_button.pack(side=tk.LEFT, padx=(16, 2))
        self.move_up_button = ttk.Button(actions, text="Move Up", command=lambda: self._move_selected(-1))
        self.move_up_button.pack(side=tk.LEFT, padx=2)
        self.move_down_button = ttk.Button(actions, text="Move Down", command=lambda: self._move_selected(1))
        self.move_down_button.pack(side=tk.LEFT, padx=2)

        split = ttk.Panedwindow(self, orient=tk.HORIZONTAL)
        split.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 8))

        left_frame = ttk.Frame(split)
        right_frame = ttk.Frame(split)
        split.add(left_frame, weight=1)
        split.add(right_frame, weight=2)

        tree_wrap = ttk.LabelFrame(left_frame, text="Menu Structure")
        tree_wrap.pack(fill=tk.BOTH, expand=True)

        self.tree = ttk.Treeview(tree_wrap, show="tree")
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.tree.bind("<<TreeviewSelect>>", self._on_tree_select)

        tree_scroll = ttk.Scrollbar(tree_wrap, orient=tk.VERTICAL, command=self.tree.yview)
        tree_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree.configure(yscrollcommand=tree_scroll.set)

        editor_wrap = ttk.LabelFrame(right_frame, text="Selected Node JSON")
        editor_wrap.pack(fill=tk.BOTH, expand=True)

        path_row = ttk.Frame(editor_wrap)
        path_row.pack(fill=tk.X, padx=8, pady=(8, 4))
        ttk.Label(path_row, text="Path:").pack(side=tk.LEFT)
        ttk.Entry(path_row, textvariable=self.path_var, state="readonly").pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=(6, 0)
        )

        quick_wrap = ttk.LabelFrame(editor_wrap, text="Quick Edit (Page)")
        quick_wrap.pack(fill=tk.X, padx=8, pady=(0, 4))

        self.quick_entry_widgets = []
        self.quick_combo_widgets = []

        fields = [
            ("Name", self.quick_name_var),
            ("Translation", self.quick_translation_var),
            ("Script", self.quick_script_var),
            ("Menu ID", self.quick_menu_id_var),
            ("Image", self.quick_image_var),
            ("Shortcut ID", self.quick_shortcut_id_var),
            ("Order", self.quick_order_var),
        ]
        for row, (label, variable) in enumerate(fields):
            ttk.Label(quick_wrap, text=label).grid(
                row=row, column=0, sticky="w", padx=(8, 6), pady=2
            )
            entry = ttk.Entry(quick_wrap, textvariable=variable)
            entry.grid(row=row, column=1, sticky="ew", padx=(0, 8), pady=2)
            self.quick_entry_widgets.append(entry)

        ttk.Label(quick_wrap, text="offline").grid(
            row=7, column=0, sticky="w", padx=(8, 6), pady=(4, 2)
        )
        offline_combo = ttk.Combobox(
            quick_wrap,
            textvariable=self.quick_offline_var,
            values=("", "true", "false"),
            state="readonly",
            width=10,
        )
        offline_combo.grid(row=7, column=1, sticky="w", padx=(0, 8), pady=(4, 2))
        self.quick_combo_widgets.append(offline_combo)

        ttk.Label(quick_wrap, text="bgtask").grid(
            row=8, column=0, sticky="w", padx=(8, 6), pady=2
        )
        bgtask_combo = ttk.Combobox(
            quick_wrap,
            textvariable=self.quick_bgtask_var,
            values=("", "true", "false"),
            state="readonly",
            width=10,
        )
        bgtask_combo.grid(row=8, column=1, sticky="w", padx=(0, 8), pady=2)
        self.quick_combo_widgets.append(bgtask_combo)

        ttk.Label(quick_wrap, text="disabled").grid(
            row=9, column=0, sticky="w", padx=(8, 6), pady=2
        )
        disabled_combo = ttk.Combobox(
            quick_wrap,
            textvariable=self.quick_disabled_var,
            values=("", "true", "false"),
            state="readonly",
            width=10,
        )
        disabled_combo.grid(row=9, column=1, sticky="w", padx=(0, 8), pady=2)
        self.quick_combo_widgets.append(disabled_combo)

        self.quick_apply_button = ttk.Button(
            quick_wrap,
            text="Apply Quick Fields",
            command=self._apply_quick_page_fields,
        )
        self.quick_apply_button.grid(
            row=10, column=0, columnspan=2, sticky="w", padx=(8, 8), pady=(6, 6)
        )

        quick_wrap.columnconfigure(1, weight=1)

        self.editor = ScrolledText(editor_wrap, wrap=tk.NONE, undo=True)
        self.editor.pack(fill=tk.BOTH, expand=True, padx=8, pady=4)

        editor_buttons = ttk.Frame(editor_wrap)
        editor_buttons.pack(fill=tk.X, padx=8, pady=(0, 8))
        self.apply_button = ttk.Button(
            editor_buttons,
            text="Apply Node JSON",
            command=self._apply_selected_json,
        )
        self.apply_button.pack(side=tk.LEFT)

        log_wrap = ttk.LabelFrame(self, text="Log")
        log_wrap.pack(fill=tk.BOTH, padx=10, pady=(0, 6))
        self.log_text = ScrolledText(log_wrap, height=8, wrap=tk.WORD, state=tk.DISABLED)
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        status = ttk.Frame(self)
        status.pack(fill=tk.X, padx=10, pady=(0, 8))
        ttk.Label(status, textvariable=self.status_var).pack(side=tk.LEFT)

        self._update_action_states(None)

    def _log(self, message: str) -> None:
        self.log_text.configure(state=tk.NORMAL)
        self.log_text.insert(tk.END, message.rstrip() + "\n")
        self.log_text.see(tk.END)
        self.log_text.configure(state=tk.DISABLED)

    def _set_dirty(self, dirty: bool) -> None:
        self.dirty = dirty
        suffix = " *" if self.dirty else ""
        self.title(f"{APP_TITLE}{suffix}")

    def _selected_path(self):
        selected = self.tree.selection()
        if not selected:
            return None
        return self.node_paths.get(selected[0])

    def _is_page_path(self, path: tuple | None) -> bool:
        return bool(
            path
            and len(path) == 4
            and path[0] == "menus"
            and path[2] == "pages"
            and isinstance(path[3], int)
        )

    def _is_menu_path(self, path: tuple | None) -> bool:
        return bool(path and len(path) == 2 and path[0] == "menus" and isinstance(path[1], str))

    def _is_section_group_path(self, path: tuple | None) -> bool:
        return bool(path and len(path) == 2 and path[0] == "sections" and isinstance(path[1], int))

    def _is_section_path(self, path: tuple | None) -> bool:
        return bool(
            path
            and len(path) == 4
            and path[0] == "sections"
            and path[2] == "sections"
            and isinstance(path[1], int)
            and isinstance(path[3], int)
        )

    def _path_to_text(self, path: tuple) -> str:
        parts = []
        for piece in path:
            if isinstance(piece, int):
                parts.append(f"[{piece}]")
            else:
                if parts:
                    parts.append(f".{piece}")
                else:
                    parts.append(piece)
        return "".join(parts)

    def _resolve_path(self, path: tuple):
        cursor = self.data
        for piece in path:
            cursor = cursor[piece]
        return cursor

    def _set_path(self, path: tuple, value) -> None:
        if not path:
            raise ValueError("Cannot assign root")
        parent = self._resolve_path(path[:-1])
        parent[path[-1]] = value

    def _delete_path(self, path: tuple) -> None:
        if not path:
            raise ValueError("Cannot delete root")
        parent = self._resolve_path(path[:-1])
        key = path[-1]
        if isinstance(parent, list):
            parent.pop(key)
        else:
            del parent[key]

    def _validate_shape(self, data: dict) -> None:
        self.generator.validate_manifest(data)

        sections = data.get("sections")
        for group_idx, group in enumerate(sections):
            if not isinstance(group, dict):
                raise ValueError(f"sections[{group_idx}] must be an object")
            child_sections = group.get("sections")
            if not isinstance(child_sections, list):
                raise ValueError(f"sections[{group_idx}].sections must be an array")
            for section_idx, section in enumerate(child_sections):
                if not isinstance(section, dict):
                    raise ValueError(
                        f"sections[{group_idx}].sections[{section_idx}] must be an object"
                    )

        menus = data.get("menus")
        for menu_id, menu in menus.items():
            if not isinstance(menu_id, str):
                raise ValueError("menu keys must be strings")
            if not isinstance(menu, dict):
                raise ValueError(f"menus.{menu_id} must be an object")
            pages = menu.get("pages")
            if not isinstance(pages, list):
                raise ValueError(f"menus.{menu_id}.pages must be an array")
            for page_idx, page in enumerate(pages):
                if not isinstance(page, dict):
                    raise ValueError(f"menus.{menu_id}.pages[{page_idx}] must be an object")
                name = page.get("name")
                if name is not None and not isinstance(name, str):
                    raise ValueError(f"menus.{menu_id}.pages[{page_idx}].name must be a string")
                translation = page.get("translation")
                if translation is not None and not isinstance(translation, str):
                    raise ValueError(
                        f"menus.{menu_id}.pages[{page_idx}].translation must be a string"
                    )

    def _validate_manifest(self, data: dict) -> None:
        snapshot = copy.deepcopy(data)
        self._validate_shape(snapshot)
        self.generator.inject_shortcut_ids(snapshot)

    def _load_manifest(self) -> None:
        with self.source_path.open("r", encoding="utf-8") as handle:
            loaded = json.load(handle)
        if not isinstance(loaded, dict):
            raise ValueError("manifest source must be an object")
        self.data = loaded
        self._refresh_tree()
        self._set_dirty(False)
        self.status_var.set("Loaded manifest source")
        self._log(f"Loaded {self.source_path}")

    def _write_manifest(self) -> None:
        self._validate_manifest(self.data)
        payload = json.dumps(self.data, indent=2, ensure_ascii=False)
        self.source_path.write_text(payload + "\n", encoding="utf-8")
        self._set_dirty(False)
        self.status_var.set("Saved manifest source")
        self._log(f"Saved {self.source_path}")

    def _refresh_tree(self, select_path: tuple | None = None) -> None:
        self.tree.delete(*self.tree.get_children())
        self.node_paths = {}

        sections = self.data.get("sections", [])
        menus = self.data.get("menus", {})
        linked_menu_ids: set[str] = set()

        def first_non_empty_label(*values) -> str:
            for value in values:
                label = self._display_label(value)
                if isinstance(label, str) and label.strip() != "":
                    return label.strip()
            return ""

        def linked_menu_title(menu_id: str | None) -> str:
            if not isinstance(menu_id, str) or menu_id.strip() == "":
                return ""
            menu = menus.get(menu_id.strip()) if isinstance(menus, dict) else None
            if not isinstance(menu, dict):
                return ""
            return first_non_empty_label(menu.get("title"), menu.get("translation"))

        def page_label(page: dict) -> str:
            page_name = pick_friendly_name(page.get("name"), page.get("translation"))
            if page_name:
                return page_name
            return page.get("script") or page.get("menuId") or "page"

        def menu_label(menu_id: str, menu: dict) -> str:
            title = self._display_label(menu.get("title"))
            if isinstance(title, str) and title.strip() != "":
                clean_title = title.strip()
                if clean_title.lower() != menu_id.lower():
                    return f"menu: {menu_id} ({clean_title})"
            return f"menu: {menu_id}"

        def add_menu_branch(parent_item: str, menu_id: str, ancestry: set[str], inline: bool = False) -> None:
            if not isinstance(menu_id, str):
                return
            menu_id = menu_id.strip()
            if menu_id == "":
                return

            menu_path = ("menus", menu_id)
            menu = menus.get(menu_id) if isinstance(menus, dict) else None

            if not isinstance(menu, dict):
                missing_item = self.tree.insert(parent_item, tk.END, text=f"menu: {menu_id} (missing)")
                self.node_paths[missing_item] = menu_path
                return

            linked_menu_ids.add(menu_id)

            if inline:
                menu_item = self.tree.insert(parent_item, tk.END, text=menu_label(menu_id, menu), open=False)
                self.node_paths[menu_item] = menu_path
                pages_parent = parent_item
            else:
                menu_item = self.tree.insert(parent_item, tk.END, text=menu_label(menu_id, menu), open=False)
                self.node_paths[menu_item] = menu_path
                pages_parent = menu_item

            if menu_id in ancestry:
                self.tree.insert(pages_parent, tk.END, text="(cycle)")
                return

            pages = menu.get("pages", [])
            if not isinstance(pages, list):
                return

            next_ancestry = set(ancestry)
            next_ancestry.add(menu_id)

            for page_idx, page in enumerate(pages):
                if not isinstance(page, dict):
                    continue
                child_menu_id = self._resolve_page_link_target(menu_id, menu, page)
                label = page_label(page)
                if isinstance(child_menu_id, str) and child_menu_id.strip() != "":
                    label = f"{label} (menu)"
                page_item = self.tree.insert(
                    pages_parent,
                    tk.END,
                    text=f"[{page_idx}] {label}",
                )
                self.node_paths[page_item] = ("menus", menu_id, "pages", page_idx)

                if isinstance(child_menu_id, str) and child_menu_id.strip() != "":
                    add_menu_branch(page_item, child_menu_id, next_ancestry, inline=True)

        for group_idx, group in enumerate(sections):
            group_label = first_non_empty_label(
                group.get("title"),
                group.get("translation"),
                group.get("id"),
            )
            if group_label == "":
                group_label = "group"
            group_item = self.tree.insert(
                "",
                tk.END,
                text=f"[{group_idx}] {group_label}",
                open=True,
            )
            group_path = ("sections", group_idx)
            self.node_paths[group_item] = group_path

            child_sections = group.get("sections", [])
            for section_idx, section in enumerate(child_sections):
                menu_id = self._resolve_section_link_target(section)
                section_label = first_non_empty_label(
                    section.get("title"),
                    section.get("translation"),
                    linked_menu_title(menu_id),
                    section.get("id"),
                    section.get("menuId"),
                    section.get("script"),
                )
                if section_label == "":
                    section_label = "section"

                section_text = f"[{section_idx}] {section_label}"

                section_item = self.tree.insert(
                    group_item,
                    tk.END,
                    text=section_text,
                )
                self.node_paths[section_item] = (
                    "sections",
                    group_idx,
                    "sections",
                    section_idx,
                )

                if isinstance(menu_id, str) and menu_id.strip() != "":
                    add_menu_branch(section_item, menu_id, set(), inline=True)

        if isinstance(menus, dict):
            unlinked_menu_ids = sorted(
                [menu_id for menu_id in menus.keys() if isinstance(menu_id, str) and menu_id not in linked_menu_ids]
            )
        else:
            unlinked_menu_ids = []

        if unlinked_menu_ids:
            unlinked_root = self.tree.insert(
                "",
                tk.END,
                text=f"Unlinked Menus ({len(unlinked_menu_ids)})",
                open=True,
            )
            for menu_id in unlinked_menu_ids:
                add_menu_branch(unlinked_root, menu_id, set(), inline=False)

        if select_path is not None:
            for item, path in self.node_paths.items():
                if path == select_path:
                    self.tree.selection_set(item)
                    self.tree.focus(item)
                    self.tree.see(item)
                    break
        elif self.node_paths:
            first_item = next(iter(self.node_paths.keys()))
            self.tree.selection_set(first_item)
            self.tree.focus(first_item)
            self.tree.see(first_item)

    def _update_action_states(self, path: tuple | None) -> None:
        can_add_page = self._is_menu_path(path) or self._is_page_path(path)
        can_add_section = self._is_section_group_path(path) or self._is_section_path(path)

        self.add_page_button.configure(state=(tk.NORMAL if can_add_page else tk.DISABLED))
        self.add_section_button.configure(state=(tk.NORMAL if can_add_section else tk.DISABLED))

        apply_state = tk.NORMAL if path is not None else tk.DISABLED
        self.apply_button.configure(state=apply_state)
        self.delete_button.configure(state=apply_state)
        quick_enabled = self._is_page_path(path)
        self.quick_apply_button.configure(state=(tk.NORMAL if quick_enabled else tk.DISABLED))
        self._set_quick_editor_state(quick_enabled)

        move_allowed = False
        if path is not None:
            move_allowed = (
                (len(path) == 4 and path[0] == "menus" and path[2] == "pages" and isinstance(path[3], int))
                or (len(path) == 4 and path[0] == "sections" and path[2] == "sections" and isinstance(path[3], int))
                or (len(path) == 2 and path[0] == "sections" and isinstance(path[1], int))
            )

        move_state = tk.NORMAL if move_allowed else tk.DISABLED
        self.move_up_button.configure(state=move_state)
        self.move_down_button.configure(state=move_state)

    def _set_quick_editor_state(self, enabled: bool) -> None:
        entry_state = tk.NORMAL if enabled else tk.DISABLED
        combo_state = "readonly" if enabled else "disabled"
        for widget in self.quick_entry_widgets:
            widget.configure(state=entry_state)
        for widget in self.quick_combo_widgets:
            widget.configure(state=combo_state)

    def _load_quick_page_fields(self, page: dict) -> None:
        name = page.get("name")
        translation = page.get("translation")
        script = page.get("script")
        menu_id = page.get("menuId")
        image = page.get("image")
        shortcut_id = page.get("shortcutId")

        self.quick_name_var.set(name if isinstance(name, str) else "")
        self.quick_translation_var.set(translation if isinstance(translation, str) else "")
        self.quick_script_var.set(script if isinstance(script, str) else "")
        self.quick_menu_id_var.set(menu_id if isinstance(menu_id, str) else "")
        self.quick_image_var.set(image if isinstance(image, str) else "")
        self.quick_shortcut_id_var.set(shortcut_id if isinstance(shortcut_id, str) else "")

        order_value = page.get("order")
        if order_value is None:
            self.quick_order_var.set("")
        else:
            self.quick_order_var.set(str(order_value))

        self.quick_offline_var.set(optional_bool_to_text(page.get("offline")))
        self.quick_bgtask_var.set(optional_bool_to_text(page.get("bgtask")))
        self.quick_disabled_var.set(optional_bool_to_text(page.get("disabled")))

    def _clear_quick_page_fields(self) -> None:
        self.quick_name_var.set("")
        self.quick_translation_var.set("")
        self.quick_script_var.set("")
        self.quick_menu_id_var.set("")
        self.quick_image_var.set("")
        self.quick_shortcut_id_var.set("")
        self.quick_order_var.set("")
        self.quick_offline_var.set("")
        self.quick_bgtask_var.set("")
        self.quick_disabled_var.set("")

    def _on_tree_select(self, _event=None) -> None:
        path = self._selected_path()
        self.editor.delete("1.0", tk.END)

        if path is None:
            self.path_var.set("")
            self._clear_quick_page_fields()
            self._update_action_states(None)
            return

        try:
            node = self._resolve_path(path)
            text = json.dumps(node, indent=2, ensure_ascii=False)
        except Exception as exc:
            text = f"{{\n  \"error\": \"{str(exc)}\"\n}}"

        self.path_var.set(self._path_to_text(path))
        self.editor.insert("1.0", text)
        if self._is_page_path(path) and isinstance(node, dict):
            self._load_quick_page_fields(node)
        else:
            self._clear_quick_page_fields()
        self._update_action_states(path)

    def _apply_selected_json(self) -> None:
        path = self._selected_path()
        if path is None:
            return

        raw = self.editor.get("1.0", tk.END).strip()
        if not raw:
            messagebox.showerror("Apply JSON", "Editor is empty.")
            return

        try:
            parsed = json.loads(raw)
        except Exception as exc:
            messagebox.showerror("Apply JSON", f"Invalid JSON:\n{exc}")
            return

        if not isinstance(parsed, dict):
            messagebox.showerror("Apply JSON", "Selected node JSON must be an object.")
            return

        try:
            self._set_path(path, parsed)
        except Exception as exc:
            messagebox.showerror("Apply JSON", str(exc))
            return

        self._set_dirty(True)
        self._refresh_tree(select_path=path)
        self.status_var.set("Applied node JSON")
        self._log(f"Updated {self._path_to_text(path)}")

    def _apply_quick_page_fields(self) -> None:
        path = self._selected_path()
        if not self._is_page_path(path):
            messagebox.showerror(
                "Apply Quick Fields",
                "Select a page node under menus.<id>.pages first.",
            )
            return

        page = self._resolve_path(path)
        if not isinstance(page, dict):
            messagebox.showerror("Apply Quick Fields", "Selected page is not an object.")
            return

        name = self.quick_name_var.get().strip()
        if name == "":
            messagebox.showerror("Apply Quick Fields", "Name cannot be empty.")
            return

        translation = self.quick_translation_var.get().strip()
        script = self.quick_script_var.get().strip()
        menu_id = self.quick_menu_id_var.get().strip()
        image = self.quick_image_var.get().strip()
        shortcut_id = self.quick_shortcut_id_var.get().strip()
        order_text = self.quick_order_var.get().strip()

        try:
            offline = parse_optional_bool(self.quick_offline_var.get(), "offline")
            bgtask = parse_optional_bool(self.quick_bgtask_var.get(), "bgtask")
            disabled = parse_optional_bool(self.quick_disabled_var.get(), "disabled")
        except ValueError as exc:
            messagebox.showerror("Apply Quick Fields", str(exc))
            return

        if order_text == "":
            order_value = None
        else:
            try:
                order_value = int(order_text)
            except ValueError:
                messagebox.showerror("Apply Quick Fields", "Order must be an integer.")
                return

        page["name"] = name
        if translation:
            page["translation"] = translation
        else:
            page.pop("translation", None)

        if script:
            page["script"] = script
        else:
            page.pop("script", None)

        if menu_id:
            page["menuId"] = menu_id
        else:
            page.pop("menuId", None)

        if image:
            page["image"] = image
        else:
            page.pop("image", None)

        if shortcut_id:
            page["shortcutId"] = shortcut_id
        else:
            page.pop("shortcutId", None)

        if order_value is not None:
            page["order"] = order_value
        else:
            page.pop("order", None)

        if offline is None:
            page.pop("offline", None)
        else:
            page["offline"] = offline

        if bgtask is None:
            page.pop("bgtask", None)
        else:
            page["bgtask"] = bgtask

        if disabled is None:
            page.pop("disabled", None)
        else:
            page["disabled"] = disabled

        self._set_dirty(True)
        self._refresh_tree(select_path=path)
        self.status_var.set("Applied quick page fields")
        self._log(f"Quick-updated {self._path_to_text(path)}")

    def _add_menu(self) -> None:
        menu_id = simpledialog.askstring("Add Menu", "Menu ID (unique key):", parent=self)
        if menu_id is None:
            return

        menu_id = menu_id.strip()
        if not menu_id:
            messagebox.showerror("Add Menu", "Menu ID cannot be empty.")
            return

        menus = self.data.setdefault("menus", {})
        if menu_id in menus:
            messagebox.showerror("Add Menu", f"Menu '{menu_id}' already exists.")
            return

        menus[menu_id] = {
            "title": "New Menu",
            "pages": []
        }

        self._set_dirty(True)
        self._refresh_tree(select_path=("menus", menu_id))
        self.status_var.set(f"Added menu '{menu_id}'")
        self._log(f"Added menu {menu_id}")

    def _resolve_menu_from_selection(self):
        path = self._selected_path()
        if path is None:
            return None
        if len(path) == 2 and path[0] == "menus":
            return path[1]
        if len(path) == 4 and path[0] == "menus" and path[2] == "pages":
            return path[1]
        return None

    def _center_dialog_over_parent(self, dialog: tk.Toplevel) -> None:
        self.update_idletasks()
        dialog.update_idletasks()

        parent_x = self.winfo_rootx()
        parent_y = self.winfo_rooty()
        parent_w = self.winfo_width()
        parent_h = self.winfo_height()

        dialog_w = dialog.winfo_width()
        dialog_h = dialog.winfo_height()
        if dialog_w <= 1:
            dialog_w = dialog.winfo_reqwidth()
        if dialog_h <= 1:
            dialog_h = dialog.winfo_reqheight()

        if parent_w <= 1:
            parent_w = self.winfo_screenwidth()
            parent_x = 0
        if parent_h <= 1:
            parent_h = self.winfo_screenheight()
            parent_y = 0

        x = parent_x + max((parent_w - dialog_w) // 2, 0)
        y = parent_y + max((parent_h - dialog_h) // 2, 0)
        dialog.geometry(f"+{x}+{y}")

    def _prompt_text_dialog(
        self,
        title: str,
        label: str,
        initial: str = "",
    ) -> str | None:
        value_var = tk.StringVar(value=initial)
        result = {"value": None}

        dialog = tk.Toplevel(self)
        dialog.title(title)
        dialog.transient(self)
        dialog.grab_set()
        dialog.resizable(False, False)

        frame = ttk.Frame(dialog, padding=10)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frame, text=label).grid(row=0, column=0, sticky="w")
        entry = ttk.Entry(frame, textvariable=value_var, width=50)
        entry.grid(row=1, column=0, sticky="ew", pady=(4, 10))
        entry.focus_set()
        entry.selection_range(0, tk.END)

        button_row = ttk.Frame(frame)
        button_row.grid(row=2, column=0, sticky="e")

        def on_ok() -> None:
            result["value"] = value_var.get().strip()
            dialog.destroy()

        def on_cancel() -> None:
            dialog.destroy()

        ttk.Button(button_row, text="OK", command=on_ok).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(button_row, text="Cancel", command=on_cancel).pack(side=tk.LEFT)

        frame.columnconfigure(0, weight=1)
        self._center_dialog_over_parent(dialog)
        dialog.bind("<Return>", lambda _event: on_ok())
        dialog.bind("<Escape>", lambda _event: on_cancel())
        dialog.protocol("WM_DELETE_WINDOW", on_cancel)

        self.wait_window(dialog)
        return result["value"]

    def _add_page(self) -> None:
        menu_id = self._resolve_menu_from_selection()
        if menu_id is None:
            messagebox.showerror("Add Page", "Select a menu or page first.")
            return

        menus = self.data.get("menus", {})
        if menu_id not in menus:
            messagebox.showerror("Add Page", f"Unknown menu '{menu_id}'.")
            return

        pages = menus[menu_id].setdefault("pages", [])
        if not isinstance(pages, list):
            messagebox.showerror("Add Page", f"menus.{menu_id}.pages is not an array.")
            return

        pages.append(
            {
                "name": "New Page",
                "translation": "@i18n(app.modules.new.name)@",
                "script": "new/new.lua",
                "image": "new/new.png"
            }
        )
        new_index = len(pages) - 1

        self._set_dirty(True)
        self._refresh_tree(select_path=("menus", menu_id, "pages", new_index))
        self.status_var.set(f"Added page to menu '{menu_id}'")
        self._log(f"Added page menus.{menu_id}.pages[{new_index}]")

    def _add_section_group(self) -> None:
        group_id = simpledialog.askstring("Add Section Group", "Group ID:", parent=self)
        if group_id is None:
            return

        group_id = group_id.strip() or f"group_{len(self.data.get('sections', [])) + 1}"
        title = simpledialog.askstring("Add Section Group", "Title:", parent=self)
        if title is None:
            title = "New Section Group"

        sections = self.data.setdefault("sections", [])
        if not isinstance(sections, list):
            messagebox.showerror("Add Section Group", "Top-level sections is not an array.")
            return

        sections.append(
            {
                "id": group_id,
                "title": title,
                "sections": []
            }
        )
        new_index = len(sections) - 1

        self._set_dirty(True)
        self._refresh_tree(select_path=("sections", new_index))
        self.status_var.set(f"Added section group '{group_id}'")
        self._log(f"Added section group sections[{new_index}]")

    def _resolve_section_group_index(self):
        path = self._selected_path()
        if path is None:
            return None
        if len(path) == 2 and path[0] == "sections":
            return path[1]
        if len(path) == 4 and path[0] == "sections" and path[2] == "sections":
            return path[1]
        return None

    def _add_section(self) -> None:
        group_index = self._resolve_section_group_index()
        if group_index is None:
            messagebox.showerror(
                "Add Section",
                "Select a section group (or one of its sections) first.",
            )
            return

        groups = self.data.get("sections", [])
        if not isinstance(groups, list) or group_index >= len(groups):
            messagebox.showerror("Add Section", "Invalid section group selection.")
            return

        group = groups[group_index]
        child_sections = group.setdefault("sections", [])
        if not isinstance(child_sections, list):
            messagebox.showerror("Add Section", "Selected group's sections is not an array.")
            return

        link_name = self._prompt_text_dialog(
            "Add Section",
            "Link name:",
            initial="New Section",
        )
        if link_name is None:
            return
        link_name = link_name.strip() or "New Section"

        base_id = re.sub(r"[^a-z0-9]+", "_", link_name.lower()).strip("_") or "new_section"
        existing_ids = {
            section.get("id")
            for section in child_sections
            if isinstance(section, dict) and isinstance(section.get("id"), str)
        }
        section_id = base_id
        suffix = 2
        while section_id in existing_ids:
            section_id = f"{base_id}_{suffix}"
            suffix += 1

        child_sections.append(
            {
                "id": section_id,
                "title": link_name,
                "menuId": "tools_menu",
                "image": "app/gfx/tools.png"
            }
        )
        new_index = len(child_sections) - 1

        self._set_dirty(True)
        self._refresh_tree(select_path=("sections", group_index, "sections", new_index))
        self.status_var.set("Added section")
        self._log(
            f"Added section sections[{group_index}].sections[{new_index}]"
        )

    def _delete_selected(self) -> None:
        path = self._selected_path()
        if path is None:
            return

        confirm = messagebox.askyesno(
            "Delete Selected",
            f"Delete {self._path_to_text(path)}?",
            parent=self,
        )
        if not confirm:
            return

        select_parent = path[:-1] if len(path) > 1 else None

        try:
            self._delete_path(path)
        except Exception as exc:
            messagebox.showerror("Delete Selected", str(exc))
            return

        self._set_dirty(True)
        self._refresh_tree(select_path=select_parent)
        self.status_var.set("Deleted selected node")
        self._log(f"Deleted {self._path_to_text(path)}")

    def _move_selected(self, delta: int) -> None:
        path = self._selected_path()
        if path is None:
            return

        if len(path) == 2 and path[0] == "sections" and isinstance(path[1], int):
            container = self.data.get("sections", [])
            idx = path[1]
            prefix: tuple = ("sections",)
        elif len(path) == 4 and path[0] == "sections" and path[2] == "sections" and isinstance(path[3], int):
            container = self._resolve_path(path[:-1])
            idx = path[3]
            prefix = path[:-1]
        elif len(path) == 4 and path[0] == "menus" and path[2] == "pages" and isinstance(path[3], int):
            container = self._resolve_path(path[:-1])
            idx = path[3]
            prefix = path[:-1]
        else:
            return

        if not isinstance(container, list):
            return

        new_idx = idx + delta
        if new_idx < 0 or new_idx >= len(container):
            return

        entry = container.pop(idx)
        container.insert(new_idx, entry)

        self._set_dirty(True)
        self._refresh_tree(select_path=prefix + (new_idx,))
        self.status_var.set("Moved selected node")
        self._log(f"Moved {self._path_to_text(path)} to index {new_idx}")

    def _validate_clicked(self) -> None:
        try:
            self._validate_manifest(self.data)
        except Exception as exc:
            messagebox.showerror("Validate", f"Validation failed:\n{exc}")
            self.status_var.set("Validation failed")
            self._log(f"Validation failed: {exc}")
            return

        messagebox.showinfo("Validate", "Manifest is valid.")
        self.status_var.set("Validation passed")
        self._log("Validation passed")

    def _render_generated_manifest(self) -> str:
        source_rel: str
        try:
            source_rel = self.source_path.relative_to(self.repo_root).as_posix()
        except ValueError:
            source_rel = self.source_path.as_posix()

        snapshot = copy.deepcopy(self.data)
        self._validate_manifest(snapshot)
        self.generator.inject_shortcut_ids(snapshot)
        return self.generator.render_manifest(snapshot, source_rel)

    def _write_generated_manifest(self) -> bool:
        generated = self._render_generated_manifest()

        current = None
        preferred_eol = "\n"
        if self.output_path.exists():
            current_raw = self.output_path.read_bytes()
            if b"\r\n" in current_raw:
                preferred_eol = "\r\n"
            current = current_raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")

        if current == generated:
            self.status_var.set("Generated manifest already up to date")
            self._log(f"No changes: {self.output_path}")
            return False

        payload = generated.replace("\n", preferred_eol)
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        self.output_path.write_bytes(payload.encode("utf-8"))
        self.status_var.set("Generated Lua manifest updated")
        self._log(f"Wrote {self.output_path}")
        return True

    def _reload_clicked(self) -> None:
        if self.dirty:
            confirm = messagebox.askyesno(
                "Reload",
                "Discard unsaved changes and reload from disk?",
                parent=self,
            )
            if not confirm:
                return

        try:
            self._load_manifest()
        except Exception as exc:
            messagebox.showerror("Reload", f"Failed to reload:\n{exc}")
            self.status_var.set("Reload failed")
            self._log(f"Reload failed: {exc}")

    def _save_manifest(self) -> bool:
        try:
            self._write_manifest()
            return True
        except Exception as exc:
            messagebox.showerror("Save Source", f"Save failed:\n{exc}")
            self.status_var.set("Save failed")
            self._log(f"Save failed: {exc}")
            self._log(traceback.format_exc())
            return False

    def _generate_clicked(self) -> None:
        if self.dirty:
            save_first = messagebox.askyesno(
                "Generate Lua",
                "You have unsaved changes. Save source first?",
                parent=self,
            )
            if not save_first:
                return
            if not self._save_manifest():
                return

        try:
            changed = self._write_generated_manifest()
            if changed:
                messagebox.showinfo("Generate Lua", "Generated manifest.lua was updated.")
            else:
                messagebox.showinfo("Generate Lua", "Generated manifest.lua is already up to date.")
        except Exception as exc:
            messagebox.showerror("Generate Lua", f"Generation failed:\n{exc}")
            self.status_var.set("Generation failed")
            self._log(f"Generation failed: {exc}")
            self._log(traceback.format_exc())

    def _save_generate_clicked(self) -> None:
        if not self._save_manifest():
            return
        self._generate_clicked()

    def _on_close(self) -> None:
        if not self.dirty:
            self.destroy()
            return

        choice = messagebox.askyesnocancel(
            "Unsaved Changes",
            "Save changes before closing?",
            parent=self,
        )
        if choice is None:
            return
        if choice:
            if not self._save_manifest():
                return
        self.destroy()


def main() -> int:
    try:
        app = MenuEditorApp()
    except Exception as exc:
        messagebox.showerror(APP_TITLE, f"Startup failed:\n{exc}")
        return 1

    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
