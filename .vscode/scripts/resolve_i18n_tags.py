# i18n/resolve_i18n_tags.py
#!/usr/bin/env python3
"""
Replace tags like @i18n(app.modules.governor.menu_filters,upper)@ in files under a root.
Usage:
  python resolve_i18n_tags.py --json scripts/rfsuite/i18n/en.json --root <folder> [--ext .lua .json .txt]
"""
#!/usr/bin/env python3
import argparse, json, re, sys, os
from pathlib import Path

TAG_RE = re.compile(r'@i18n\(\s*([^)@,]+?)\s*(?:,\s*(upper|lower))?\s*\)@')

def load_translations(path: Path) -> dict:
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)

def resolve_key(tree: dict, dotted: str):
    """
    Walk dotted path. If the leaf is a dict like
    { english: "...", translation: "..." }, prefer 'translation',
    fall back to 'english'. Otherwise cast to str.
    """
    node = tree
    for part in dotted.split('.'):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]

    # Leaf handling
    if isinstance(node, dict):
        # common schema: english/translation/needs_translation
        if 'translation' in node and isinstance(node['translation'], (str, int, float)):
            return str(node['translation'])
        if 'english' in node and isinstance(node['english'], (str, int, float)):
            return str(node['english'])
        # if dict but not the expected shape, refuse
        return None

    if node is None:
        return None

    # Primitive leaf
    return str(node)

def apply_modifier(s: str, mod: str | None):
    if not mod:
        return s
    if mod == 'upper':
        return s.upper()
    if mod == 'lower':
        return s.lower()
    return s  # unknown modifier, ignore

def replace_tags_in_text(text: str, translations: dict, stats: dict):
    """
    Returns (new_text, num_replacements)
    Updates stats['unresolved'] with keys that couldn't be resolved.
    """

    def _sub(m: re.Match):
        key = m.group(1).strip()
        mod = m.group(2)
        resolved = resolve_key(translations, key)
        if resolved is None:
            stats.setdefault('unresolved', {}).setdefault(key, 0)
            stats['unresolved'][key] += 1
            return m.group(0)  # leave tag untouched
        return apply_modifier(resolved, mod)

    new_text, n = TAG_RE.subn(_sub, text)
    return new_text, n

def process_file(path: Path, translations: dict, dry_run=False):
    before = path.read_text(encoding='utf-8')
    stats = {}
    new_text, n = replace_tags_in_text(before, translations, stats)

    if n == 0:
        return 0, stats.get('unresolved', {})

    if dry_run:
        print(f"[i18n] DRY-RUN would update {path} — {n} replacement(s)")
        return n, stats.get('unresolved', {})

    # check writability (best-effort on Windows)
    writable = os.access(path, os.W_OK) and os.access(path.parent, os.W_OK)
    if not writable:
        print(f"[i18n] NOTE: {path} looks protected (Program Files?) — you may need to run elevated or deploy to a staging folder first.")

    # attempt write with good diagnostics
    try:
        path.write_text(new_text, encoding='utf-8')
    except PermissionError as e:
        print(f"[i18n] FAILED to write (permission): {path} — {e}")
        return 0, stats.get('unresolved', {})
    except OSError as e:
        print(f"[i18n] FAILED to write (os error): {path} — {e}")
        return 0, stats.get('unresolved', {})

    # verify the write actually stuck
    try:
        after = path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"[i18n] WARNING: couldn’t read back for verify: {path} — {e}")
        after = None

    if after is None or after == before:
        print(f"[i18n] WARNING: write verification shows no change: {path}")
        return 0, stats.get('unresolved', {})

    return n, stats.get('unresolved', {})

def iter_source_files(root: Path, exts=('.lua', '.ts', '.tsx', '.js', '.jsx', '.json', '.md', '.txt')):
    for p in root.rglob('*'):
        if p.is_file() and p.suffix.lower() in exts:
            yield p

def main():
    ap = argparse.ArgumentParser(description="Resolve @i18n(...)@ tags in a codebase")
    ap.add_argument('--json', required=True, help='Path to en.json')
    ap.add_argument('--root', required=True, help='Root of codebase to scan')
    ap.add_argument('--dry-run', action='store_true', help='Do not write changes')
    args = ap.parse_args()

    translations = load_translations(Path(args.json))
    root = Path(args.root)

    total_files_changed = 0
    total_replacements = 0
    unresolved_agg = {}

    for f in iter_source_files(root):
        replaced, unresolved = process_file(f, translations, dry_run=args.dry_run)
        if replaced:
            total_files_changed += 1
            total_replacements += replaced
            # per-file debug line
            #print(f"[i18n] updated {f} — {replaced} replacement(s) (verified)")
        # aggregate unresolved
        for k, c in unresolved.items():
            unresolved_agg[k] = unresolved_agg.get(k, 0) + c

    print(f"[i18n] DONE — files changed: {total_files_changed}, total replacements: {total_replacements}")

    if unresolved_agg:
        print("[i18n] unresolved keys:")
        # show top offenders first
        for k, c in sorted(unresolved_agg.items(), key=lambda kv: (-kv[1], kv[0])):
            print(f"  {k}: {c} occurrence(s)")

if __name__ == "__main__":
    sys.exit(main())
