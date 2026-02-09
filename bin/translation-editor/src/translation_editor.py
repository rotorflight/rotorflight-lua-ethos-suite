#!/usr/bin/env python3
import json
import tkinter as tk
from tkinter import ttk, messagebox
from pathlib import Path
from collections import OrderedDict

APP_TITLE = "RF Suite Translation Editor"


def repo_root():
    return Path(__file__).resolve().parents[3]


def i18n_root():
    return repo_root() / "bin" / "i18n" / "json"


def sound_root():
    return repo_root() / "bin" / "sound-generator" / "json"


class DataStore:
    def __init__(self):
        self.dataset = "i18n"  # or "sound"
        self.module = ""       # relative dir under i18n_root, "" means root
        self.locale = "en"
        self.rows = []          # list of dicts: {key, english, translation, needs}
        self.filtered_rows = []
        self.original_by_key = {}
        self.undo_stack = []

    def set_dataset(self, dataset):
        self.dataset = dataset

    def set_module(self, module):
        self.module = module

    def set_locale(self, locale):
        self.locale = locale


class TranslationEditor(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1300x720")
        self.minsize(1200, 650)

        self.store = DataStore()
        self.search_var = tk.StringVar()
        self.filter_var = tk.StringVar(value="All")

        self._build_ui()
        self._load_dataset_options()
        self._load_data()
        self.bind_all("<Control-z>", self._undo_last)

    def _build_ui(self):
        self.warning_label = tk.Label(self, text="", anchor=tk.W, fg="red", bg="#fff1f1")
        self.warning_label.pack(fill=tk.X, padx=10, pady=(8, 2))

        top = ttk.Frame(self)
        top.pack(fill=tk.X, padx=10, pady=6)

        ttk.Label(top, text="Dataset:").pack(side=tk.LEFT)
        self.dataset_cb = ttk.Combobox(top, values=["i18n", "sound"], state="readonly", width=10)
        self.dataset_cb.current(0)
        self.dataset_cb.pack(side=tk.LEFT, padx=6)
        self.dataset_cb.bind("<<ComboboxSelected>>", self._on_dataset_changed)

        ttk.Label(top, text="Language:").pack(side=tk.LEFT, padx=(12, 0))
        self.locale_cb = ttk.Combobox(top, values=[], width=10)
        self.locale_cb.pack(side=tk.LEFT, padx=6)
        self.locale_cb.bind("<<ComboboxSelected>>", self._on_locale_changed)
        self.locale_cb.bind("<Return>", self._on_locale_changed)

        self.module_label = ttk.Label(top, text="Module:")
        self.module_label.pack(side=tk.LEFT, padx=(12, 0))
        self.module_cb = ttk.Combobox(top, values=[], state="readonly", width=24)
        self.module_cb.pack(side=tk.LEFT, padx=6)
        self.module_cb.bind("<<ComboboxSelected>>", self._on_module_changed)

        ttk.Label(top, text="Search:").pack(side=tk.LEFT, padx=(12, 0))
        search_entry = ttk.Entry(top, textvariable=self.search_var, width=28)
        search_entry.pack(side=tk.LEFT, padx=6)
        search_entry.bind("<KeyRelease>", self._apply_filter)

        ttk.Label(top, text="Filter:").pack(side=tk.LEFT, padx=(12, 0))
        self.filter_cb = ttk.Combobox(top, values=["All", "Needs only", "Done only"], state="readonly", width=12)
        self.filter_cb.pack(side=tk.LEFT, padx=6)
        self.filter_cb.current(0)
        self.filter_cb.bind("<<ComboboxSelected>>", self._apply_filter)

        btn_frame = ttk.Frame(top)
        btn_frame.pack(side=tk.RIGHT)
        ttk.Button(btn_frame, text="Save", command=self._save).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Reload", command=self._load_data).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Undo", command=self._undo_last).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Edit translation", command=self._edit_selected).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Toggle needs", command=self._toggle_needs).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Undo row", command=self._undo_row).pack(side=tk.RIGHT, padx=4)

        hint = ttk.Label(self, text="Tip: click a Translation cell to edit. (For en, edit the English cell.)")
        hint.pack(fill=tk.X, padx=10, pady=(0, 4))

        table_frame = ttk.Frame(self)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        columns = ("key", "english", "translation", "needs")
        self.tree = ttk.Treeview(table_frame, columns=columns, show="headings")
        self.tree.heading("key", text="Key")
        self.tree.heading("english", text="English")
        self.tree.heading("translation", text="Translation")
        self.tree.heading("needs", text="Needs")

        self.tree.column("key", width=280, anchor=tk.W)
        self.tree.column("english", width=360, anchor=tk.W)
        self.tree.column("translation", width=360, anchor=tk.W)
        self.tree.column("needs", width=80, anchor=tk.CENTER)

        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.tree.bind("<Button-1>", self._on_click)
        self.tree.bind("<Double-1>", self._on_double_click)
        self.tree.bind("<<TreeviewSelect>>", self._on_selection)

        scroll = ttk.Scrollbar(table_frame, orient=tk.VERTICAL, command=self.tree.yview)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree.configure(yscrollcommand=scroll.set)

        self.status = ttk.Label(self, text="", anchor=tk.W)
        self.status.pack(fill=tk.X, padx=10, pady=(0, 8))

        self._editor = None
        self._edit_item = None
        self._edit_field = None

    def _load_dataset_options(self):
        self._refresh_locale_list()
        self._refresh_module_list()

    def _refresh_locale_list(self):
        if self.store.dataset == "i18n":
            locales = set()
            root = i18n_root()
            if root.exists():
                for path in root.rglob("*.json"):
                    locales.add(path.stem)
            locales = sorted(locales)
        else:
            root = sound_root()
            locales = sorted([p.stem for p in root.glob("*.json")]) if root.exists() else []

        if "en" not in locales:
            locales.insert(0, "en")
        self.locale_cb["values"] = locales
        if self.store.locale in locales:
            self.locale_cb.set(self.store.locale)
        else:
            self.locale_cb.set("en")
            self.store.locale = "en"

    def _refresh_module_list(self):
        if self.store.dataset != "i18n":
            self.module_cb["values"] = []
            self.module_cb.set("")
            self.module_label.configure(state=tk.DISABLED)
            self.module_cb.configure(state=tk.DISABLED)
            self.store.module = ""
            return

        root = i18n_root()
        modules = []
        if root.exists():
            for dirpath in root.rglob("*"):
                if not dirpath.is_dir():
                    continue
                if (dirpath / "en.json").exists():
                    rel = dirpath.relative_to(root)
                    mod = "" if str(rel) == "." else str(rel).replace("\\", "/")
                    modules.append(mod)
        modules = sorted(modules)
        if "" not in modules:
            modules.insert(0, "")

        labels = ["(root)" if m == "" else m for m in modules]
        self.module_cb["values"] = labels
        current = "(root)" if self.store.module == "" else self.store.module
        if current in labels:
            self.module_cb.set(current)
        else:
            self.module_cb.set(labels[0] if labels else "")
            self.store.module = ""

        self.module_label.configure(state=tk.NORMAL)
        self.module_cb.configure(state="readonly")

    def _on_dataset_changed(self, _evt=None):
        self.store.set_dataset(self.dataset_cb.get())
        self._refresh_locale_list()
        self._refresh_module_list()
        self._load_data()

    def _on_locale_changed(self, _evt=None):
        self.store.set_locale(self.locale_cb.get().strip())
        self._load_data()

    def _on_module_changed(self, _evt=None):
        label = self.module_cb.get()
        module = "" if label == "(root)" else label
        self.store.set_module(module)
        self._load_data()

    def _load_data(self):
        if self.store.dataset == "i18n":
            self.store.rows = self._load_i18n_rows()
        else:
            self.store.rows = self._load_sound_rows()
        self.store.original_by_key = {r["key"]: r.copy() for r in self.store.rows}
        self.store.undo_stack = []
        self._apply_filter()

    def _load_i18n_rows(self):
        root = i18n_root()
        module_dir = root / self.store.module if self.store.module else root
        en_path = module_dir / "en.json"
        if not en_path.exists():
            messagebox.showerror("Missing en.json", f"Missing {en_path}")
            return []

        en_data = self._read_json(en_path)
        tgt_path = module_dir / f"{self.store.locale}.json"
        tgt_data = self._read_json(tgt_path) if tgt_path.exists() else {}

        rows = []
        self._walk_i18n(en_data, tgt_data, "", rows)
        return rows

    def _walk_i18n(self, en_node, tgt_node, prefix, rows):
        if not isinstance(en_node, dict):
            return

        for key, en_val in en_node.items():
            full_key = f"{prefix}.{key}" if prefix else key
            tgt_val = tgt_node.get(key) if isinstance(tgt_node, dict) else None

            if isinstance(en_val, dict) and "english" in en_val and "translation" in en_val:
                translation = ""
                needs = True
                if isinstance(tgt_val, dict):
                    translation = tgt_val.get("translation", "")
                    needs = bool(tgt_val.get("needs_translation", translation == ""))

                rows.append({
                    "key": full_key,
                    "english": en_val.get("english", ""),
                    "translation": translation or "",
                    "needs": needs,
                })
            elif isinstance(en_val, dict):
                self._walk_i18n(en_val, tgt_val if isinstance(tgt_val, dict) else {}, full_key, rows)

    def _load_sound_rows(self):
        root = sound_root()
        en_path = root / "en.json"
        if not en_path.exists():
            messagebox.showerror("Missing en.json", f"Missing {en_path}")
            return []

        en_data = self._read_json(en_path)
        tgt_path = root / f"{self.store.locale}.json"
        tgt_data = self._read_json(tgt_path) if tgt_path.exists() else []

        tgt_map = {e.get("file"): e for e in tgt_data if isinstance(e, dict)}
        rows = []
        for en_entry in en_data:
            key = en_entry.get("file", "")
            english = en_entry.get("english", "")
            tgt_entry = tgt_map.get(key, {})
            translation = tgt_entry.get("translation", "") or ""
            needs = bool(tgt_entry.get("needs_translation", translation == ""))
            rows.append({
                "key": key,
                "english": english,
                "translation": translation,
                "needs": needs,
            })
        return rows

    def _read_json(self, path):
        try:
            with path.open("r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            messagebox.showerror("JSON error", f"Failed to read {path}: {e}")
            return {}

    def _apply_filter(self, _evt=None):
        text = self.search_var.get().strip().lower()
        mode = self.filter_cb.get() if hasattr(self, "filter_cb") else "All"

        filtered = []
        for row in self.store.rows:
            if mode == "Needs only" and not row["needs"]:
                continue
            if mode == "Done only" and row["needs"]:
                continue
            if text:
                hay = " ".join([row["key"], row["english"], row["translation"]]).lower()
                if text not in hay:
                    continue
            filtered.append(row)

        self.store.filtered_rows = filtered
        self._render_rows()

    def _render_rows(self):
        self.tree.delete(*self.tree.get_children())
        for idx, row in enumerate(self.store.filtered_rows):
            needs_text = "[x]" if row["needs"] else "[ ]"
            self.tree.insert("", tk.END, iid=str(idx), values=(row["key"], row["english"], row["translation"], needs_text))

        total = len(self.store.rows)
        missing = sum(1 for r in self.store.rows if r["needs"])
        shown = len(self.store.filtered_rows)
        if self.store.locale == "en":
            edit_hint = "Edit: click English cell (master)"
        else:
            edit_hint = "Edit: click Translation cell"
        self.status.configure(text=f"Rows: {shown}/{total}   Missing: {missing}   {edit_hint}   Toggle: click Needs")
        self._update_length_warnings()

    def _length_warning(self, english, translation):
        e = len(english or "")
        t = len(translation or "")
        if e == 0:
            return False
        return t > e + 10

    def _update_length_warnings(self):
        count = 0
        for row in self.store.rows:
            if self._length_warning(row.get("english", ""), row.get("translation", "")):
                count += 1

        sel = self.tree.selection()
        if sel:
            row_index = int(sel[0])
            row = self.store.filtered_rows[row_index]
            english = row.get("english", "")
            translation = row.get("translation", "")
            if self._length_warning(english, translation):
                diff = len(translation) - len(english)
                self.warning_label.configure(
                    text=f"Warning: translation exceeds English by {diff} chars (limit +10)"
                )
                self.bell()
            else:
                self.warning_label.configure(text="")
        else:
            self.warning_label.configure(text="")

    def _on_selection(self, _evt=None):
        self._update_length_warnings()

    def _enforce_translation_limit(self, _evt=None):
        if not self._editor or self._edit_field != "translation":
            return
        item = self._edit_item
        if item is None:
            return
        row_index = int(item)
        row = self.store.filtered_rows[row_index]
        max_len = len(row.get("english", "")) + 10
        if max_len <= 0:
            return
        value = self._editor.get()
        if len(value) > max_len:
            self._editor.delete(0, tk.END)
            self._editor.insert(0, value[:max_len])
            self.bell()

    def _on_click(self, event):
        if self._editor:
            self._commit_edit(self._edit_item, self._edit_field)
        item = self.tree.identify_row(event.y)
        col = self.tree.identify_column(event.x)
        if not item:
            return
        if self.store.locale == "en":
            if col == "#2":
                self._begin_edit(event, field="english")
            return
        if col == "#3":
            self._begin_edit(event, field="translation")
            return
        if col == "#4":
            row_index = int(item)
            row = self.store.filtered_rows[row_index]
            row["needs"] = not row["needs"]
            self._render_rows()

    def _on_double_click(self, event):
        if self._editor:
            self._commit_edit(self._edit_item, self._edit_field)
        item = self.tree.identify_row(event.y)
        col = self.tree.identify_column(event.x)
        if not item:
            return
        if self.store.locale == "en":
            if col == "#2":
                self._begin_edit(event, field="english")
            return
        if col == "#3":
            self._begin_edit(event, field="translation")

    def _begin_edit(self, event, field="translation"):
        if self._editor:
            self._commit_edit(self._edit_item, self._edit_field)

        item = self.tree.identify_row(event.y)
        col = self.tree.identify_column(event.x)
        if self.store.locale == "en" and field == "translation":
            return
        target_col = "#2" if field == "english" else "#3"
        if not item or col != target_col:
            return

        row_index = int(item)
        row = self.store.filtered_rows[row_index]

        x, y, w, h = self.tree.bbox(item, target_col)
        value = row["english"] if field == "english" else row["translation"]

        self._editor = ttk.Entry(self.tree)
        self._editor.place(x=x, y=y, width=w, height=h)
        self._editor.insert(0, value)
        self._editor.focus_set()
        self._edit_item = item
        self._edit_field = field
        if field == "translation" and self.store.locale != "en":
            self._editor.bind("<KeyRelease>", self._enforce_translation_limit)
        self._editor.bind("<Return>", lambda e: self._commit_edit(item, field))
        self._editor.bind("<FocusOut>", lambda e: self._commit_edit(item, field))

    def _edit_selected(self):
        sel = self.tree.selection()
        if not sel:
            messagebox.showinfo("Edit translation", "Select a row, then click Edit translation.")
            return
        item = sel[0]
        target_col = "#2" if self.store.locale == "en" else "#3"
        bbox = self.tree.bbox(item, target_col)
        if not bbox:
            return
        x, y, w, h = bbox
        class DummyEvent:
            def __init__(self, x, y):
                self.x = x
                self.y = y
        field = "english" if self.store.locale == "en" else "translation"
        self._begin_edit(DummyEvent(x, y), field=field)

    def _commit_edit(self, item, field):
        if not self._editor:
            return
        new_value = self._editor.get()
        self._editor.destroy()
        self._editor = None
        self._edit_item = None
        self._edit_field = None

        row_index = int(item)
        row = self.store.filtered_rows[row_index]
        if field == "english":
            prev = row.get("english", "")
            row["english"] = new_value
            if self.store.locale == "en":
                prev_t = row.get("translation", "")
                row["translation"] = new_value
                row["needs"] = False
                self.store.undo_stack.append((row.get("key"), "english", prev, new_value, prev_t))
            else:
                self.store.undo_stack.append((row.get("key"), "english", prev, new_value, None))
        else:
            prev = row.get("translation", "")
            max_len = len(row.get("english", "")) + 10
            if max_len > 0 and len(new_value) > max_len:
                new_value = new_value[:max_len]
                self.bell()
            row["translation"] = new_value
            if new_value.strip() == "":
                row["needs"] = True
            else:
                row["needs"] = False
            self.store.undo_stack.append((row.get("key"), "translation", prev, new_value, None))
        # Ensure master list is updated even if filtered_rows is a copy.
        key = row.get("key")
        if key is not None:
            for base_row in self.store.rows:
                if base_row.get("key") == key:
                    base_row.update(row)
                    break

        self._render_rows()

    def _toggle_needs(self):
        sel = self.tree.selection()
        if not sel:
            return
        for item in sel:
            row_index = int(item)
            row = self.store.filtered_rows[row_index]
            prev = row.get("needs", False)
            row["needs"] = not row["needs"]
            self.store.undo_stack.append((row.get("key"), "needs", prev, row["needs"], None))
        self._render_rows()

    def _undo_last(self, _evt=None):
        if not self.store.undo_stack:
            return
        key, field, prev, _new, prev_translation = self.store.undo_stack.pop()
        if key is None:
            return
        for row in self.store.rows:
            if row.get("key") == key:
                if field == "english":
                    row["english"] = prev
                    if self.store.locale == "en" and prev_translation is not None:
                        row["translation"] = prev_translation
                elif field == "translation":
                    row["translation"] = prev
                elif field == "needs":
                    row["needs"] = prev
                break
        self._apply_filter()

    def _undo_row(self):
        sel = self.tree.selection()
        if not sel:
            return
        item = sel[0]
        row_index = int(item)
        row = self.store.filtered_rows[row_index]
        key = row.get("key")
        if key is None:
            return
        original = self.store.original_by_key.get(key)
        if not original:
            return
        # Push current state to undo stack before restoring.
        self.store.undo_stack.append((key, "english", row.get("english", ""), original.get("english", ""), None))
        self.store.undo_stack.append((key, "translation", row.get("translation", ""), original.get("translation", ""), None))
        self.store.undo_stack.append((key, "needs", row.get("needs", False), original.get("needs", False), None))
        row.update(original)
        for base_row in self.store.rows:
            if base_row.get("key") == key:
                base_row.update(original)
                break
        self._render_rows()

    def _save(self):
        if self.store.dataset == "i18n":
            self._save_i18n()
        else:
            self._save_sound()

    def _save_i18n(self):
        root = i18n_root()
        module_dir = root / self.store.module if self.store.module else root
        module_dir.mkdir(parents=True, exist_ok=True)
        out_path = module_dir / f"{self.store.locale}.json"

        en_path = module_dir / "en.json"
        if not en_path.exists():
            messagebox.showerror("Missing en.json", f"Missing {en_path}")
            return

        en_data = self._read_json(en_path)
        row_map = {r["key"]: r for r in self.store.rows}

        def rebuild(node, prefix):
            if not isinstance(node, dict):
                return node
            out = OrderedDict()
            for key, en_val in node.items():
                full_key = f"{prefix}.{key}" if prefix else key
                if isinstance(en_val, dict) and "english" in en_val and "translation" in en_val:
                    row = row_map.get(full_key, {})
                    english = row.get("english", en_val.get("english", ""))
                    if self.store.locale == "en":
                        translation = english
                        needs = False
                    else:
                        translation = row.get("translation", "")
                        needs = bool(row.get("needs", True))
                    out[key] = OrderedDict({
                        "english": english,
                        "translation": translation,
                        "needs_translation": needs,
                    })
                elif isinstance(en_val, dict):
                    out[key] = rebuild(en_val, full_key)
                else:
                    out[key] = en_val
            return out

        out_data = rebuild(en_data, "")
        with out_path.open("w", encoding="utf-8") as f:
            json.dump(out_data, f, ensure_ascii=False, indent=2)
        messagebox.showinfo("Saved", f"Saved {out_path}")

    def _save_sound(self):
        root = sound_root()
        root.mkdir(parents=True, exist_ok=True)
        out_path = root / f"{self.store.locale}.json"

        en_path = root / "en.json"
        if not en_path.exists():
            messagebox.showerror("Missing en.json", f"Missing {en_path}")
            return

        en_data = self._read_json(en_path)
        row_map = {r["key"]: r for r in self.store.rows}

        out_data = []
        for en_entry in en_data:
            key = en_entry.get("file", "")
            row = row_map.get(key, {})
            english = row.get("english", en_entry.get("english", ""))
            if self.store.locale == "en":
                translation = english
                needs = False
            else:
                translation = row.get("translation", "")
                needs = bool(row.get("needs", True))
            out_data.append({
                "file": key,
                "english": english,
                "translation": translation,
                "needs_translation": needs,
            })

        with out_path.open("w", encoding="utf-8") as f:
            json.dump(out_data, f, ensure_ascii=False, indent=2)
        messagebox.showinfo("Saved", f"Saved {out_path}")


if __name__ == "__main__":
    app = TranslationEditor()
    app.mainloop()
