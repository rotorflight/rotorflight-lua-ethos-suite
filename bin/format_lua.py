#!/usr/bin/env python3
import argparse
import os
import re
import sys
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import tempfile
from typing import Optional, Tuple, List
from datetime import datetime

DEFAULT_EXCLUDES = {"vendor", "third_party", "build", "dist", ".git", "node_modules"}

# ---------- Encoding helpers (preserve originals; avoid losing characters like '°') ----------
PREFERRED_FALLBACKS = ("cp1252", "latin-1")

def read_text_preserve_encoding(path: Path) -> Tuple[str, str]:
    """Read file, returning (text, encoding). Try utf-8 strict, then cp1252, latin-1, then raw latin-1 decode."""
    try:
        return path.read_text(encoding="utf-8", errors="strict"), "utf-8"
    except UnicodeDecodeError:
        pass
    for enc in PREFERRED_FALLBACKS:
        try:
            return path.read_text(encoding=enc, errors="strict"), enc
        except UnicodeDecodeError:
            continue
    # Last resort: binary -> latin-1 decode to avoid data loss
    raw = path.read_bytes()
    return raw.decode("latin-1"), "latin-1"

def write_text_with_encoding(path: Path, text: str, encoding: str) -> None:
    path.write_text(text, encoding=encoding, newline=None)

# ---------- Robust Lua comment stripper (respects ' " and long strings [=[ ]=]) ----------
def _match_long_bracket(s: str, i: int) -> Optional[int]:
    if i >= len(s) or s[i] != "[":
        return None
    j = i + 1
    eqs = 0
    while j < len(s) and s[j] == "=":
        eqs += 1
        j += 1
    if j < len(s) and s[j] == "[":
        return eqs
    return None


def strip_lua_comments(code: str) -> str:
    """Remove real Lua comments while preserving strings (', ", [=[ ]=])."""
    i, n = 0, len(code)
    out: List[str] = []
    NORMAL, SQ, DQ, LONG_STR, LINE_COM, BLOCK_COM = range(6)
    state = NORMAL
    long_eqs = 0

    while i < n:
        ch = code[i]

        if state == NORMAL:
            if ch == "-" and i + 1 < n and code[i + 1] == "-":
                j = i + 2
                if j < n and code[j] == "[":
                    eqs = _match_long_bracket(code, j)
                    if eqs is not None:
                        state = BLOCK_COM
                        long_eqs = eqs
                        i = j + 2 + eqs
                        continue
                state = LINE_COM
                i += 2
                continue

            if ch == "[":
                eqs = _match_long_bracket(code, i)
                if eqs is not None:
                    state = LONG_STR
                    long_eqs = eqs
                    out.append(code[i : i + 2 + eqs])
                    i += 2 + eqs
                    continue

            if ch == "'":
                state = SQ
                out.append(ch)
                i += 1
                continue
            if ch == '"':
                state = DQ
                out.append(ch)
                i += 1
                continue

            out.append(ch)
            i += 1
            continue

        if state == LINE_COM:
            if ch == "\n":
                out.append("\n")
                state = NORMAL
            i += 1
            continue

        if state == BLOCK_COM:
            if ch == "]":
                j = i + 1
                eqs = 0
                while j < n and code[j] == "=":
                    eqs += 1
                    j += 1
                if eqs == long_eqs and j < n and code[j] == "]":
                    i = j + 1
                    state = NORMAL
                    continue
            if ch == "\n":
                out.append("\n")
            i += 1
            continue

        if state == SQ:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(code[i + 1])
                i += 2
                continue
            if ch == "'":
                state = NORMAL
            i += 1
            continue

        if state == DQ:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(code[i + 1])
                i += 2
                continue
            if ch == '"':
                state = NORMAL
            i += 1
            continue

        if state == LONG_STR:
            out.append(ch)
            if ch == "]":
                j = i + 1
                eqs = 0
                while j < n and code[j] == "=":
                    eqs += 1
                    j += 1
                if eqs == long_eqs and j < n and code[j] == "]":
                    out.append(code[i + 1 : j + 1])
                    i = j + 1
                    state = NORMAL
                    continue
            i += 1
            continue

    return "".join(out)


# ---------- Header injection ----------
def make_header(year: int, holder: str) -> str:
    """Compact 3–4 line GPLv3 header."""
    return (
        "--[[\n"
        f"  Copyright (C) {year} {holder}\n"
        "  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html\n"
        "]] --\n"
    )


def split_bom_shebang(text: str):
    """Return (prefix, rest) where prefix keeps BOM and/or shebang if present."""
    prefix = ""
    i = 0
    if text.startswith("\ufeff"):
        prefix += "\ufeff"
        i = 1
    if text[i:].startswith("#!"):
        nl = text.find("\n", i)
        if nl == -1:
            prefix += text[i:]
            return prefix, ""
        prefix += text[i : nl + 1]
        i = nl + 1
    return prefix, text[i:]


def inject_header_final(formatted_text: str, header: str, enable: bool) -> str:
    """Prepend header after BOM/shebang."""
    if not enable:
        return formatted_text
    prefix, body = split_bom_shebang(formatted_text)
    # Since comments are stripped earlier, duplication isn’t possible.
    header_out = header if (not body or body.startswith("\n")) else header + "\n"
    return prefix + header_out + body


# ---------- File discovery ----------
def find_lua_files(root: Path, excludes: set[str]) -> list[Path]:
    files: list[Path] = []
    root = root.resolve()
    for dirpath, dirnames, filenames in os.walk(root):
        rel = Path(dirpath).relative_to(root)
        dirnames[:] = [d for d in dirnames if (rel / d).parts[0] not in excludes]
        for name in filenames:
            if name.lower().endswith(".lua"):
                files.append(Path(dirpath) / name)
    return files


# ---------- Format pipeline ----------
def run_lua_format_on_text(text: str, column_limit: int, extra_args: list[str]) -> Tuple[int, str, str]:
    """Write text to a temp file, run lua-format (no -i) and return (exit_code, stdout, stderr)."""
    with tempfile.NamedTemporaryFile("w+", suffix=".lua", delete=False, encoding="utf-8") as tf:
        temp_path = Path(tf.name)
        tf.write(text)
        tf.flush()
    try:
        cmd = [
            "lua-format",
            f"--column-limit={column_limit}",
            "--keep-simple-function-one-line",
            "--keep-simple-control-block-one-line",
            "--no-align-args",
            "--no-align-table-field",
        ] + extra_args + [str(temp_path)]
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="strict")
        return proc.returncode, (proc.stdout or ""), (proc.stderr or "")
    finally:
        try:
            temp_path.unlink(missing_ok=True)
        except Exception:
            pass


def process_file(
    path: Path,
    column_limit: int,
    extra_args: list[str],
    dry_run: bool,
    make_backup: bool,
    header_enable: bool,
    header_holder: str,
    header_year: int,
) -> Tuple[bool, Optional[str]]:
    """Returns (changed, error_message)."""
    # Read preserving original encoding
    original, orig_enc = read_text_preserve_encoding(path)

    stripped = strip_lua_comments(original)

    code, out_stdout, out_stderr = run_lua_format_on_text(stripped, column_limit, extra_args)
    if code != 0:
        return (False, f"lua-format failed: {out_stderr.strip() or 'non-zero exit'}")

    formatted_text = out_stdout  # only stdout contains the formatted code

    # Final: inject header
    header_text = make_header(header_year, header_holder)
    final_text = inject_header_final(formatted_text, header_text, enable=header_enable)

    if dry_run:
        return (final_text != original, None)

    if final_text == original:
        return (False, None)

    if make_backup:
        bak = path.with_suffix(path.suffix + ".bak")
        try:
            shutil.copy2(path, bak)
        except Exception as e:
            return (False, f"failed to create backup: {e}")

    # Write back using the same encoding the file was originally in
    write_text_with_encoding(path, final_text, orig_enc)
    return (True, None)


# ---------- CLI ----------
def main():
    parser = argparse.ArgumentParser(
        description="Strip Lua comments, format via lua-format, then inject a compact GPL header (encoding-safe)."
    )
    parser.add_argument("root", nargs="?", default=".", help="Root directory to scan (default: current dir)")
    parser.add_argument("-x", "--exclude", action="append", default=[], help=f"Directory to exclude (default: {', '.join(sorted(DEFAULT_EXCLUDES))})")
    parser.add_argument("--column-limit", type=int, default=300, help="Column limit (default: 300)")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4, help="Parallelism (default: CPU count)")
    parser.add_argument("--extra", nargs=argparse.REMAINDER, default=[], help="Extra args passed to lua-format (put them after --extra)")
    parser.add_argument("--dry-run", action="store_true", help="Do not modify files; just report which would change")
    parser.add_argument("--backup", action="store_true", help="Create .bak backups before writing")

    # Header options
    parser.add_argument("--no-header", action="store_true", help="Disable final header injection")
    parser.add_argument("--header-holder", default="Rotorflight Project", help="Header holder name (default: Rotorflight Project)")
    parser.add_argument("--header-year", type=int, default=datetime.now().year, help="Header year (default: current year)")

    args = parser.parse_args()

    if shutil.which("lua-format") is None:
        print("Error: lua-format not found in PATH.", file=sys.stderr)
        sys.exit(127)

    root = Path(args.root)
    excludes = set(DEFAULT_EXCLUDES) | set(args.exclude)
    files = find_lua_files(root, excludes)
    if not files:
        print("No .lua files found.")
        return

    print(f"Processing {len(files)} Lua files…")
    changed = 0
    failed = 0
    failures: list[tuple[Path, str]] = []

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        futures = {
            ex.submit(
                process_file,
                f,
                args.column_limit,
                args.extra,
                args.dry_run,
                args.backup,
                not args.no_header,
                args.header_holder,
                args.header_year,
            ): f
            for f in files
        }
        for fut in as_completed(futures):
            f = futures[fut]
            try:
                did_change, err = fut.result()
                if err:
                    failed += 1
                    failures.append((f, err))
                elif did_change:
                    changed += 1
            except Exception as e:
                failed += 1
                failures.append((f, str(e)))

    if args.dry_run:
        print(f"[dry-run] Would change: {changed} file(s); Failures: {failed}")
    else:
        print(f"Changed: {changed} file(s); Failures: {failed}")

    if failures:
        print("\nFailures:")
        for f, msg in failures:
            print(f"- {f}: {msg}")
        sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
