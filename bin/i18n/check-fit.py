#!/usr/bin/env python3
"""
Report i18n strings too wide for where they are shown on the smallest radio.

max_length (update-max-lengths.py) caps a translation at the English string's
character count, but characters are not all the same width: a German or Polish
label within that count can still run past its field, and an English one can be
too long to begin with. This check measures pixels instead.

Widths come from bin/i18n/fit/x18_glyph_widths.json, each character's advance in
FONT_XS / FONT_S / FONT_STD measured on an X18S in the Ethos simulator. Ethos
draws text as the plain sum of those advances, so the table reproduces
lcd.getTextSize() exactly. A layout that fits the X18's 480x320 screen fits the
larger radios too.

Where a key is used decides its budget. Each @i18n tag in src/ is classified
from its source line:

  title  last level of a PAGE_TITLE / header.build title: app/header.lua drops
         the leading breadcrumb levels to fit, so the page's own name must fit
         alone (178px, FONT_STD)
  tile   a menu tile title in app/tool.lua (98px, FONT_XS: the tile is 110px,
         less its frame padding)
  label  a form label with a field beside it (215px, FONT_STD: the field starts
         at x=225)
  choice an entry in a choice list (200px, FONT_STD)
  note   a line with nothing beside it: a bare form.addLine(), addTextLine(),
         an expansion panel or group heading (460px, FONT_STD)

Anything else (dialog text, which wraps; formatted messages; audio) is not
checked. A key used in several places must fit the tightest of them.

Usage:
  python bin/i18n/check-fit.py                # every locale
  python bin/i18n/check-fit.py --lang en de   # only these locales
  python bin/i18n/check-fit.py --json         # machine-readable output
  python bin/i18n/check-fit.py --self-test    # prove the check can fail

Remeasuring (a locale gained characters the table lacks, which this check
reports): measure lcd.getTextSize("|c|") - lcd.getTextSize("||") for each
character in each of the three fonts on the X18 simulator and update the table.

Exit status: 0 when everything fits, 1 when anything is too wide.
"""

import argparse
import importlib.util
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parents[2]
RESOLVER = REPO / ".vscode" / "scripts" / "resolve_i18n_tags.py"
SUITE_ROOT = REPO / "src" / "rfsuite"
JSON_ROOT = Path(__file__).resolve().parent / "json"
GLYPHS = Path(__file__).resolve().parent / "fit" / "x18_glyph_widths.json"

FONT_INDEX = {"XS": 0, "S": 1, "STD": 2}
BUDGETS = OrderedDict([
    ("tile", ("XS", 98)),
    ("title", ("STD", 178)),
    ("choice", ("STD", 200)),
    ("label", ("STD", 215)),
    ("note", ("STD", 460)),
])
SKIP_DIRS = ("widgets/", "i18n/", "sim/")

PLACEHOLDER = "@T@"
FIELD_RE = re.compile(r"(\w+)\s*=\s*\"$")
TITLE_RE = re.compile(r"PAGE_TITLE\s*=|header\.build\(|pageTitle\s*=|buildHeader\(")
TOOL_TILE_RE = re.compile(r"\btitle\s*=")
NOTE_RE = re.compile(
    r"^\s*(if\b.*\bthen\s+)?form\.addLine\(\s*\"@T@\"\s*\)\s*(end)?\s*$"
    r"|addTextLine\(|addExpansionPanel\(|addCenteredMessage\(|\{\s*group\s*=|buildGroup\("
)
CHOICE_RE = re.compile(r"\{\s*\"@T@\"\s*,\s*-?\d|^\s*(\"@T@\"\s*,\s*)+$")
SKIP_RE = re.compile(
    r"MSG_|BTN_|ERR_|\baction\s*=|Dialog|showInfo|showProgress|showBanner|string\.format|message\s*=|body\s*=|print\(",
    re.I,
)
LABEL_RE = re.compile(
    r"addLine\(|addValueLine\(|addBool|addNumber|addChoice|addRange|addRow\(|addField\(|addCellField\("
    r"|buildSingle\(|buildAxisRow\(|ctx\.add|\blabel\s*=|\btitle\s*=|\bname\s*="
)


def load_resolver():
    spec = importlib.util.spec_from_file_location("resolve_i18n_tags", RESOLVER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_glyphs(path=GLYPHS):
    return json.loads(path.read_text(encoding="utf-8"))["glyphs"]


def text_width(text, font, glyphs, unknown=None):
    """Pixel width of text in font; characters missing from the table count as 'W'."""
    i = FONT_INDEX[font]
    total = 0
    for ch in text:
        w = glyphs.get(ch)
        if w is None:
            if unknown is not None:
                unknown.add(ch)
            w = glyphs["W"]
        total += w[i]
    return total


def classify(rel, bare):
    """Context of the tags on one tag-stripped source line, or None to skip it."""
    if TITLE_RE.search(bare):
        return "title"
    if rel == "app/tool.lua" and TOOL_TILE_RE.search(bare):
        return "tile"
    if NOTE_RE.search(bare):
        return "note"
    if CHOICE_RE.search(bare):
        return "choice"
    if SKIP_RE.search(bare):
        return None
    if LABEL_RE.search(bare):
        return "label"
    return None


def collect_uses(resolver, suite_root=SUITE_ROOT):
    """Return {key: {context: [(relative path, line), ...]}} for every checked tag."""
    uses = {}
    for path in sorted(resolver.iter_source_files(suite_root, exts=(".lua",))):
        rel = path.relative_to(suite_root).as_posix()
        if rel.startswith(SKIP_DIRS):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            matches = list(resolver.TAG_RE.finditer(line))
            if not matches:
                continue
            ctx = classify(rel, resolver.TAG_RE.sub(PLACEHOLDER, line))
            if ctx is None:
                continue
            # A breadcrumb title only has to fit by its last level (see app/header.lua).
            if ctx == "title":
                matches = matches[-1:]
            for m in matches:
                key = m.group(1).strip()
                where = (path.relative_to(REPO).as_posix(), lineno)
                # A menu entry carries its tile title and its group heading on one line.
                field = FIELD_RE.search(line[:m.start()])
                tag_ctx = "note" if field and field.group(1) == "group" else ctx
                uses.setdefault(key, {}).setdefault(tag_ctx, []).append(where)
    return uses


def find_overflows(uses, locales, glyphs, unknown):
    """Return a list of overflow records, tightest context per key and locale."""
    out = []
    for loc, tree in locales.items():
        for key, ctxs in sorted(uses.items()):
            node = tree
            for part in key.split("."):
                node = node.get(part) if isinstance(node, dict) else None
            if not isinstance(node, dict) or "translation" not in node:
                continue
            text = node.get("translation") or node.get("english") or ""
            worst = None
            for ctx, where in ctxs.items():
                font, budget = BUDGETS[ctx]
                px = text_width(text, font, glyphs, unknown)
                if px > budget and (worst is None or px - budget > worst["px"] - worst["budget"]):
                    worst = dict(lang=loc, key=key, context=ctx, px=px, budget=budget, text=text,
                                 file=where[0][0], line=where[0][1])
            if worst:
                out.append(worst)
    return out


def load_locales(only):
    locales = OrderedDict()
    for path in sorted(JSON_ROOT.glob("*.json")):
        if only and path.stem not in only:
            continue
        locales[path.stem] = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)
    return locales


def self_test(resolver, glyphs):
    """The check must flag a too-wide label and pass the same label shortened."""
    uses = {"t.k": {"label": [("src/x.lua", 1)]}}
    wide = {"x": {"t": {"k": {"english": "x", "translation": "W" * 40}}}}
    narrow = {"x": {"t": {"k": {"english": "x", "translation": "OK"}}}}
    red = find_overflows(uses, wide, glyphs, set())
    green = find_overflows(uses, narrow, glyphs, set())
    probe = classify("app/pages/x.lua", 'form.addBooleanField(form.addLine("@T@"), nil, get, set)')
    note = classify("app/pages/x.lua", '  form.addLine("@T@")')
    ok = len(red) == 1 and not green and probe == "label" and note == "note"
    print(f"[i18n-fit] self-test {'OK' if ok else 'FAILED'}: red={len(red)} green={len(green)} "
          f"label={probe} note={note}")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("--lang", nargs="*", help="locales to check (default: all)")
    ap.add_argument("--json", action="store_true", help="print JSON instead of text")
    ap.add_argument("--self-test", action="store_true", help="prove the check can fail")
    args = ap.parse_args()

    resolver = load_resolver()
    glyphs = load_glyphs()
    if args.self_test:
        return self_test(resolver, glyphs)

    uses = collect_uses(resolver)
    unknown = set()
    overflows = find_overflows(uses, load_locales(set(args.lang or [])), glyphs, unknown)

    if args.json:
        print(json.dumps({"overflows": overflows, "unknown_chars": sorted(unknown)}, ensure_ascii=False, indent=2))
    else:
        for o in sorted(overflows, key=lambda o: (o["lang"], o["file"], o["line"])):
            print(f"  {o['file']}:{o['line']}: [{o['lang']}] {o['key']} ({o['context']}) "
                  f"{o['px']}px > {o['budget']}px: \"{o['text']}\"")
        if unknown:
            print(f"[i18n-fit] {len(unknown)} character(s) missing from {GLYPHS.name}, counted as 'W': "
                  + "".join(sorted(unknown)))
        if overflows:
            print(f"[i18n-fit] {len(overflows)} string(s) too wide for the X18. Shorten them in "
                  "bin/i18n/json/ and regenerate (see AGENTS.md section 7).")
        else:
            print("[i18n-fit] OK: every checked string fits the X18")
    return 1 if overflows else 0


if __name__ == "__main__":
    sys.exit(main())
