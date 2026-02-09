#!/usr/bin/env python3
import json
import os
import shutil
import tkinter as tk
from tkinter import ttk, messagebox
from tkinter import filedialog
from datetime import datetime
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from zipfile import ZipFile, ZIP_DEFLATED
from pathlib import Path
from collections import OrderedDict

APP_TITLE = "RF Suite Translation Editor"
# Allowed non-ASCII characters observed in existing translations.
ALLOWED_NON_ASCII = set("­°µÄÑÜßàáâäèéêëíîïñóôöùúûü​–“”")

REPO_OWNER = "rotorflight"
REPO_NAME = "rotorflight-lua-ethos-suite"
REPO_BRANCH = "master"
API_BASE = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents"
DATA_ROOT = Path.home() / ".rfsuite-translation-editor"
I18N_REL = Path("bin/i18n/json")
SOUND_REL = Path("bin/sound-generator/json")


def repo_root():
    return Path(__file__).resolve().parents[3]


def data_root():
    return DATA_ROOT


def i18n_root():
    data_path = data_root() / I18N_REL
    if data_path.exists():
        return data_path
    return repo_root() / I18N_REL


def sound_root():
    data_path = data_root() / SOUND_REL
    if data_path.exists():
        return data_path
    return repo_root() / SOUND_REL


class DataStore:
    def __init__(self):
        self.dataset = "i18n"  # or "sound"
        self.locale = "en"
        self.rows = []          # list of dicts: {key, english, translation, needs}
        self.filtered_rows = []
        self.original_by_key = {}
        self.undo_stack = []

    def set_dataset(self, dataset):
        self.dataset = dataset

    def set_locale(self, locale):
        self.locale = locale


class TranslationEditor(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.update_idletasks()
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        w = int(sw * 0.85)
        h = int(sh * 0.85)
        self.geometry(f"{w}x{h}")
        self.minsize(1200, 650)

        self.store = DataStore()
        self.search_var = tk.StringVar()
        self.filter_var = tk.StringVar(value="All")

        self._build_ui()
        self._load_dataset_options()
        self._ensure_data()
        self._load_data()
        self.bind_all("<Control-z>", self._undo_last)

    def _build_ui(self):
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

        ttk.Label(top, text="Search:").pack(side=tk.LEFT, padx=(12, 0))
        search_entry = ttk.Entry(top, textvariable=self.search_var, width=28)
        search_entry.pack(side=tk.LEFT, padx=6)
        search_entry.bind("<KeyRelease>", self._apply_filter)

        ttk.Label(top, text="Filter:").pack(side=tk.LEFT, padx=(12, 0))
        self.filter_cb = ttk.Combobox(
            top,
            values=["All", "Needs only", "Done only", "Disallowed chars", "Exceeds max"],
            state="readonly",
            width=14
        )
        self.filter_cb.pack(side=tk.LEFT, padx=6)
        self.filter_cb.current(0)
        self.filter_cb.bind("<<ComboboxSelected>>", self._apply_filter)

        btn_frame = ttk.Frame(top)
        btn_frame.pack(side=tk.RIGHT)
        ttk.Button(btn_frame, text="Save", command=self._save).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Export", command=self._export).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Reset", command=self._reset).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Sync", command=self._sync).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Reload", command=self._load_data).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Undo", command=self._undo_last).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Edit translation", command=self._edit_selected).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Toggle needs", command=self._toggle_needs).pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_frame, text="Undo row", command=self._undo_row).pack(side=tk.RIGHT, padx=4)

        stats = ttk.LabelFrame(self, text="Summary")
        stats.pack(fill=tk.X, padx=10, pady=(0, 4))
        self.stats_label = ttk.Label(stats, text="", anchor=tk.W)
        self.stats_label.pack(side=tk.LEFT, padx=8, pady=4)

        data_path = data_root()
        self.data_label = ttk.Label(self, text=f"Data: {data_path}", anchor=tk.W)
        self.data_label.pack(fill=tk.X, padx=10, pady=(0, 4))

        hint = ttk.Label(self, text="Tip: click a Translation cell to edit. (For en, edit the English cell.)")
        hint.pack(fill=tk.X, padx=10, pady=(0, 4))

        table_frame = ttk.Frame(self)
        table_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        columns = ("key", "english", "translation", "needs")
        style = ttk.Style()
        style.configure("RFSuite.Treeview", rowheight=28)
        self.tree = ttk.Treeview(table_frame, columns=columns, show="headings", style="RFSuite.Treeview")
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
        self.status.pack(fill=tk.X, padx=10, pady=(0, 2))

        self.warning_label = tk.Label(self, text="", anchor=tk.W, fg="red", bg="#fff1f1")
        self.warning_label.pack(fill=tk.X, padx=10, pady=(0, 8))

        self._editor = None
        self._edit_item = None
        self._edit_field = None
        self._live_warn_active = False

    def _load_dataset_options(self):
        self._refresh_locale_list()

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

    def _on_dataset_changed(self, _evt=None):
        self.store.set_dataset(self.dataset_cb.get())
        self._refresh_locale_list()
        self._load_data()

    def _on_locale_changed(self, _evt=None):
        self.store.set_locale(self.locale_cb.get().strip())
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
        en_path = root / "en.json"
        if not en_path.exists():
            messagebox.showerror("Missing en.json", f"Missing {en_path}")
            return []

        en_data = self._read_json(en_path)
        tgt_path = root / f"{self.store.locale}.json"
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
                    "max_length": en_val.get("max_length"),
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
            if mode == "Disallowed chars":
                translation = row.get("translation", "") or ""
                if not self._has_disallowed_non_ascii(translation):
                    continue
            if mode == "Exceeds max":
                english = row.get("english", "")
                translation = row.get("translation", "")
                max_len = row.get("max_length")
                if not self._length_warning(english, translation, max_len):
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
        done = total - missing
        disallowed = sum(
            1 for r in self.store.rows if self._has_disallowed_non_ascii(r.get("translation", ""))
        )
        exceeds = sum(
            1 for r in self.store.rows
            if self._length_warning(r.get("english", ""), r.get("translation", ""), r.get("max_length"))
        )
        shown = len(self.store.filtered_rows)
        if self.store.locale == "en":
            edit_hint = "Edit: click English cell (master)"
        else:
            edit_hint = "Edit: click Translation cell"
        self.status.configure(text=f"Rows: {shown}/{total}   Missing: {missing}   {edit_hint}   Toggle: click Needs")
        self.stats_label.configure(
            text=f"Total: {total}  Done: {done}  Missing: {missing}  Exceeds: {exceeds}  Disallowed: {disallowed}"
        )
        self._update_length_warnings()

    def _length_warning(self, english, translation, max_length=None):
        if translation is None:
            translation = ""
        e = len(english or "")
        t = len(translation or "")
        if e == 0:
            return False
        if isinstance(max_length, int) and max_length > 0:
            return t > max_length
        return t > (e * 1.15)

    def _has_disallowed_non_ascii(self, text):
        if text is None:
            return False
        for ch in text:
            if ord(ch) > 127 and ch not in ALLOWED_NON_ASCII:
                return True
        return False

    def _update_length_warnings(self):
        sel = self.tree.selection()
        if sel:
            row_index = int(sel[0])
            row = self.store.filtered_rows[row_index]
            english = row.get("english", "")
            translation = row.get("translation", "")
            max_len = row.get("max_length")
            if self._length_warning(english, translation, max_len):
                diff = len(translation) - len(english)
                if isinstance(max_len, int) and max_len > 0:
                    self.warning_label.configure(
                        text=f"Warning: translation exceeds max length by {len(translation) - max_len} chars"
                    )
                else:
                    self.warning_label.configure(
                        text=f"Warning: translation exceeds English by {diff} chars (>15%)"
                    )
                self.bell()
            elif self._has_disallowed_non_ascii(translation):
                self.warning_label.configure(
                    text="Warning: translation contains non-ASCII characters (blocked)"
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
        english = row.get("english", "")
        translation = self._editor.get()
        max_len = row.get("max_length")
        is_warn = self._length_warning(english, translation, max_len)
        if is_warn:
            if isinstance(max_len, int) and max_len > 0:
                self.warning_label.configure(
                    text=f"Warning: translation exceeds max length by {len(translation) - max_len} chars"
                )
            else:
                diff = len(translation) - len(english)
                self.warning_label.configure(
                    text=f"Warning: translation exceeds English by {diff} chars (>15%)"
                )
            if not self._live_warn_active:
                self.bell()
            self._live_warn_active = True
        elif self._has_disallowed_non_ascii(translation):
            self.warning_label.configure(
                text="Warning: translation contains non-ASCII characters (blocked)"
            )
            if not self._live_warn_active:
                self.bell()
            self._live_warn_active = True
        else:
            if self._live_warn_active:
                self.warning_label.configure(text="")
            self._live_warn_active = False

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
        self._live_warn_active = False
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

    def _sync(self):
        if not messagebox.askyesno(
            "Sync",
            "Sync will download the latest JSON files from GitHub and overwrite local data. Continue?"
        ):
            return
        working = None
        try:
            working = self._show_working("Syncing... Please wait.")
            self._download_folder(I18N_REL)
            self._download_folder(SOUND_REL)
        except Exception as e:
            if working:
                working.destroy()
            messagebox.showerror("Sync failed", str(e))
            return
        if working:
            working.destroy()
        self._load_dataset_options()
        self._load_data()
        messagebox.showinfo("Sync complete", f"Synced data into {data_root()}")

    def _reset(self):
        if not messagebox.askyesno("Reset", "Reset local data by re-downloading from the repo?"):
            return
        base = data_root()
        if base.exists():
            try:
                shutil.rmtree(base)
            except Exception as e:
                messagebox.showerror("Reset failed", str(e))
                return
        self._sync()

    def _export(self):
        if self.store.dataset == "i18n":
            src_root = i18n_root()
        else:
            src_root = sound_root()

        locale = self.store.locale
        src_file = src_root / f"{locale}.json"
        if not src_file.exists():
            messagebox.showerror("Export failed", f"Missing {src_file}")
            return

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        default_name = f"rfsuite-{self.store.dataset}-{locale}-{ts}.zip"
        out_path = filedialog.asksaveasfilename(
            title="Export translations",
            defaultextension=".zip",
            initialfile=default_name,
            filetypes=[("ZIP files", "*.zip")]
        )
        if not out_path:
            return

        try:
            with ZipFile(out_path, "w", ZIP_DEFLATED) as zf:
                arcname = str(Path(self.store.dataset) / f"{locale}.json")
                zf.write(src_file, arcname)
                info = (
                    f"Dataset: {self.store.dataset}\n"
                    f"Locale: {locale}\n"
                    f"Source: {src_file}\n"
                    f"Exported: {ts}\n"
                    f"Repo: https://github.com/{REPO_OWNER}/{REPO_NAME}\n"
                )
                zf.writestr("README.txt", info)
        except Exception as e:
            messagebox.showerror("Export failed", str(e))
            return

        messagebox.showinfo("Export complete", f"Exported to {out_path}")

    def _download_folder(self, rel_path: Path):
        url = f"{API_BASE}/{rel_path.as_posix()}?ref={REPO_BRANCH}"
        req = Request(url, headers={"Accept": "application/vnd.github+json"})
        try:
            with urlopen(req) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except HTTPError as e:
            raise RuntimeError(f"HTTP error {e.code} for {url}") from e
        except URLError as e:
            raise RuntimeError(f"Network error for {url}") from e

        if not isinstance(data, list):
            raise RuntimeError(f"Unexpected response for {url}")

        out_dir = data_root() / rel_path
        out_dir.mkdir(parents=True, exist_ok=True)
        for item in data:
            if item.get("type") != "file":
                continue
            name = item.get("name", "")
            if not name.endswith(".json"):
                continue
            download_url = item.get("download_url")
            if not download_url:
                continue
            target = out_dir / name
            try:
                with urlopen(download_url) as resp:
                    target.write_bytes(resp.read())
            except Exception as e:
                raise RuntimeError(f"Failed downloading {download_url}: {e}") from e

    def _show_working(self, text):
        win = tk.Toplevel(self)
        win.title("Working")
        win.geometry("320x90")
        win.resizable(False, False)
        win.transient(self)
        win.grab_set()
        win.lift()
        lbl = ttk.Label(win, text=text, anchor=tk.W)
        lbl.pack(fill=tk.X, padx=12, pady=10)
        bar = ttk.Progressbar(win, mode="indeterminate")
        bar.pack(fill=tk.X, padx=12, pady=(0, 12))
        bar.start(10)
        win.update()
        return win

    def _ensure_data(self):
        if (data_root() / I18N_REL / "en.json").exists():
            return
        if not messagebox.askyesno(
            "Initial sync required",
            "No local data found. Download translation files from GitHub now?"
        ):
            return
        self._sync()

    def _has_non_ascii(self):
        for row in self.store.rows:
            text = row.get("translation", "")
            if self._has_disallowed_non_ascii(text):
                return True
        return False

    def _save_i18n(self):
        # Hard block non-ASCII translations to avoid Ethos issues.
        if self._has_non_ascii():
            messagebox.showerror(
                "Non-ASCII blocked",
                "Save blocked: translations contain non-ASCII characters."
            )
            return
        root = i18n_root()
        root.mkdir(parents=True, exist_ok=True)
        out_path = root / f"{self.store.locale}.json"

        en_path = root / "en.json"
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
                    entry = OrderedDict({
                        "english": english,
                        "translation": translation,
                        "needs_translation": needs,
                    })
                    if self.store.locale == "en":
                        max_len = en_val.get("max_length")
                        if isinstance(max_len, int):
                            entry["max_length"] = max_len
                    out[key] = entry
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
        # Hard block non-ASCII translations to avoid Ethos issues.
        if self._has_non_ascii():
            messagebox.showerror(
                "Non-ASCII blocked",
                "Save blocked: translations contain non-ASCII characters."
            )
            return
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
