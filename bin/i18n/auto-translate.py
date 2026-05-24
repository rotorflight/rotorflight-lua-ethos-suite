#!/usr/bin/env python3
"""
Auto-translate Rotorflight i18n JSON files using the Claude API.

Finds all entries with needs_translation=True across all non-English locale files
and translates them in batches, respecting max_length constraints.

Usage:
    python bin/i18n/auto-translate.py                  # all locales
    python bin/i18n/auto-translate.py --only de fr     # specific locales
    python bin/i18n/auto-translate.py --dry-run        # count only, no API calls
    python bin/i18n/auto-translate.py --batch-size 20  # tune batch size

Requires: pip install anthropic
Environment: ANTHROPIC_API_KEY must be set.
"""

import argparse
import json
import os
import re
import sys
import time
from collections import OrderedDict
from pathlib import Path

try:
    import anthropic
except ImportError:
    print("ERROR: anthropic package not installed. Run: pip install anthropic")
    sys.exit(1)

ROOT_DIR = Path(__file__).parent / "json"
DEFAULT_BATCH_SIZE = 30
MODEL = "claude-haiku-4-5-20251001"

LANGUAGE_NAMES = {
    "cs": "Czech",
    "de": "German",
    "es": "Spanish",
    "fr": "French",
    "he": "Hebrew",
    "it": "Italian",
    "nl": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt-br": "Portuguese (Brazilian)",
    "zh-cn": "Chinese (Simplified)",
}

# Terms that must never be translated — keep as-is in all languages
NO_TRANSLATE_TERMS = (
    "ESC", "BEC", "MSP", "PID", "RPM", "FrSky", "F.BUS", "ELRS", "GPS", "IMU",
    "FC", "ADC", "DMA", "UART", "PWM", "ACC", "GYRO", "SmartFuel", "SmartPort",
    "SmartAudio", "CRSF", "SBUS", "IBUS", "DSM", "DSMX", "SRXL", "Spektrum",
    "Futaba", "JR", "LED", "LUA", "Lua", "Ethos", "Rotorflight", "FBL",
)

SYSTEM_PROMPT = """You are a professional technical translator for radio-controlled (RC) helicopter flight controller software. The software is Rotorflight, a flight controller firmware for RC helicopters, displayed on FrSky Ethos radio transmitters.

Your task: translate English strings to {language}.

Hard rules:
1. NEVER translate these technical terms — copy them exactly: {no_translate}
2. Use aviation/RC-helicopter-appropriate vocabulary in {language} (e.g. collective, cyclic, swashplate, tail rotor, headspeed, governor, spoolup, throttle, pitch, roll, yaw, armed/disarmed).
3. Keep all numbers, units (V, mV, A, mA, mAh, Hz, ms, s, %, x, dps) and parenthetical examples like (1-6) or (angle, horizon) unchanged.
4. STRICTLY respect the max character length noted as [max:N] — your translation must not exceed N characters including spaces.
5. If a string is a proper noun, brand name, or abbreviation with no natural translation (e.g. "FrSky F.BUS"), keep it as-is.
6. Do not add explanations, notes, or commentary — translate only.
7. Respond with a single JSON object: {{"0": "...", "1": "...", ...}} — one key per input entry.
""".format(
    language="{language}",
    no_translate=", ".join(NO_TRANSLATE_TERMS),
)


def read_json(filepath: Path) -> OrderedDict:
    raw = filepath.read_text(encoding="utf-8")
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw, object_pairs_hook=OrderedDict)


def write_json(filepath: Path, data: OrderedDict) -> None:
    with filepath.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def find_untranslated(obj: dict, path: str = "") -> list[dict]:
    """Walk the JSON tree and collect all entries where needs_translation is True."""
    results = []
    if isinstance(obj, dict):
        if obj.get("needs_translation") is True:
            results.append({
                "path": path,
                "english": obj.get("english", ""),
                "max_length": obj.get("max_length", 999),
            })
        else:
            for k, v in obj.items():
                new_path = f"{path}.{k}" if path else k
                results.extend(find_untranslated(v, new_path))
    return results


def set_translation(data: OrderedDict, path: str, translation: str) -> None:
    """Write a translation value into the nested data structure."""
    parts = path.split(".")
    obj = data
    for part in parts[:-1]:
        obj = obj[part]
    leaf = obj[parts[-1]]
    leaf["translation"] = translation
    leaf["needs_translation"] = False
    # Hebrew: mark reverse_text based on whether translation contains Hebrew chars
    if "reverse_text" in leaf:
        leaf["reverse_text"] = bool(re.search(r"[֐-׿]", translation))


def _extract_json(text: str) -> dict | None:
    """Extract a JSON object from an API response that may include prose or code fences."""
    # Strip code fences if present
    text = re.sub(r"```(?:json)?\s*", "", text).strip()
    # Find the outermost { ... }
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1:
        return None
    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None


def _truncate_to_limit(text: str, max_len: int) -> str:
    """Hard-truncate at a word boundary to stay within max_len."""
    if len(text) <= max_len:
        return text
    truncated = text[:max_len]
    # Try to cut at the last space to avoid splitting a word
    last_space = truncated.rfind(" ")
    if last_space > max_len // 2:
        return truncated[:last_space]
    return truncated


def translate_batch(
    client: anthropic.Anthropic,
    entries: list[dict],
    language: str,
) -> dict[str, str]:
    """Send one batch to the Claude API and return {index: translation} mapping."""
    lines = []
    for i, entry in enumerate(entries):
        lines.append(f'{i} [max:{entry["max_length"]}]: {entry["english"]}')

    user_message = (
        f"Translate each of these {len(entries)} strings to {language}.\n"
        "Reply with JSON only — {\"0\": \"...\", \"1\": \"...\", ...}\n\n"
        + "\n".join(lines)
    )

    response = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        system=SYSTEM_PROMPT.format(language=language),
        messages=[{"role": "user", "content": user_message}],
    )

    raw = response.content[0].text if response.content else ""
    parsed = _extract_json(raw)
    if parsed is None:
        print(f"\n    WARNING: Could not parse JSON response. Raw:\n    {raw[:200]}")
        return {}
    return parsed


def process_language(
    client: anthropic.Anthropic | None,
    lang_code: str,
    lang_path: Path,
    batch_size: int,
    dry_run: bool,
) -> tuple[int, int]:
    """
    Process a single language file.
    Returns (translated_count, total_untranslated).
    """
    lang_name = LANGUAGE_NAMES.get(lang_code, lang_code)
    data = read_json(lang_path)
    untranslated = find_untranslated(data)

    total = len(untranslated)
    if total == 0:
        print(f"  {lang_code:6s} ({lang_name}): already complete")
        return 0, 0

    if dry_run:
        print(f"  {lang_code:6s} ({lang_name}): {total} entries need translation")
        return 0, total

    num_batches = (total + batch_size - 1) // batch_size
    print(f"  {lang_code:6s} ({lang_name}): {total} entries in {num_batches} batch(es)")

    translated = 0
    failed = 0

    for batch_num, start in enumerate(range(0, total, batch_size), 1):
        batch = untranslated[start : start + batch_size]
        print(f"    [{batch_num}/{num_batches}] translating {len(batch)} entries...", end=" ", flush=True)

        try:
            result = translate_batch(client, batch, lang_name)
        except anthropic.APIError as exc:
            print(f"API error: {exc}")
            failed += len(batch)
            time.sleep(2)
            continue

        for j, entry in enumerate(batch):
            raw_translation = result.get(str(j))
            if not raw_translation:
                failed += 1
                continue
            translation = _truncate_to_limit(str(raw_translation), entry["max_length"])
            set_translation(data, entry["path"], translation)
            translated += 1

        print(f"OK ({translated} done so far)")

        # Polite rate-limit pause between batches
        if batch_num < num_batches:
            time.sleep(0.5)

    write_json(lang_path, data)

    if failed:
        print(f"    WARNING: {failed} entries could not be translated")

    return translated, total


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Auto-translate Rotorflight i18n JSON files via Claude API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("--only", nargs="*", metavar="LOCALE", help="Limit to these locales (e.g. de fr)")
    ap.add_argument("--dry-run", action="store_true", help="Count untranslated entries without calling the API")
    ap.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE, metavar="N",
                    help=f"Entries per API call (default: {DEFAULT_BATCH_SIZE})")
    ap.add_argument("--json-dir", default=str(ROOT_DIR), metavar="PATH",
                    help="Directory containing the i18n JSON files")
    args = ap.parse_args(argv)

    json_dir = Path(args.json_dir)
    if not json_dir.is_dir():
        print(f"ERROR: json directory not found: {json_dir}", file=sys.stderr)
        return 1

    client = None
    if not args.dry_run:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("ERROR: ANTHROPIC_API_KEY environment variable is not set.", file=sys.stderr)
            print("Get an API key at https://console.anthropic.com/", file=sys.stderr)
            return 1
        client = anthropic.Anthropic(api_key=api_key)

    lang_files = sorted(f for f in json_dir.glob("*.json") if f.stem != "en")
    if args.only:
        only_set = set(args.only)
        lang_files = [f for f in lang_files if f.stem in only_set]
        unknown = only_set - {f.stem for f in lang_files}
        if unknown:
            print(f"WARNING: unknown locales ignored: {', '.join(sorted(unknown))}")

    if not lang_files:
        print("No language files to process.")
        return 0

    mode = "DRY RUN — " if args.dry_run else ""
    print(f"\n{mode}Rotorflight i18n auto-translator  (model: {MODEL})")
    print(f"Processing {len(lang_files)} locale(s):\n")

    total_translated = 0
    total_needed = 0

    for lang_path in lang_files:
        done, needed = process_language(client, lang_path.stem, lang_path, args.batch_size, args.dry_run)
        total_translated += done
        total_needed += needed

    print()
    if args.dry_run:
        print(f"Total entries needing translation: {total_needed}")
    else:
        print(f"Total translated: {total_translated} / {total_needed}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
