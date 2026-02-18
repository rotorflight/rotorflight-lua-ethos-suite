#!/usr/bin/env python3
"""
Generate `src/rfsuite/app/modules/manifest.lua` from JSON source.
"""

from __future__ import annotations

import argparse
import copy
import difflib
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, Iterable


ROOT_KEY_ORDER = ("sections", "menus")
LUA_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SLUG_RE = re.compile(r"[^a-z0-9]+")


def lua_escape(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def lua_key(key: str) -> str:
    if LUA_IDENT_RE.match(key):
        return key
    return f'["{lua_escape(key)}"]'


def ordered_items(obj: dict[str, Any], path: tuple[str, ...]) -> Iterable[tuple[str, Any]]:
    if path != ():
        return obj.items()

    taken = set()
    ordered: list[tuple[str, Any]] = []
    for key in ROOT_KEY_ORDER:
        if key in obj:
            ordered.append((key, obj[key]))
            taken.add(key)
    for key, value in obj.items():
        if key not in taken:
            ordered.append((key, value))
    return ordered


def slugify(text: str, max_len: int = 40) -> str:
    slug = SLUG_RE.sub("_", text.lower()).strip("_")
    if not slug:
        slug = "shortcut"
    if len(slug) > max_len:
        slug = slug[:max_len].rstrip("_")
    return slug


def build_shortcut_id(menu_id: str, page: dict[str, Any]) -> str:
    payload = {
        "menu": menu_id,
        "menuId": page.get("menuId"),
        "script": page.get("script"),
        "script_default": page.get("script_default"),
        "script_by_mspversion": page.get("script_by_mspversion"),
        "apiversion": page.get("apiversion"),
        "apiversionlt": page.get("apiversionlt"),
        "apiversiongt": page.get("apiversiongt"),
        "apiversionlte": page.get("apiversionlte"),
        "apiversiongte": page.get("apiversiongte"),
        "mspversion": page.get("mspversion"),
        "ethosversion": page.get("ethosversion"),
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    digest = hashlib.sha1(canonical.encode("utf-8")).hexdigest()[:10]
    target = page.get("menuId") or page.get("script") or "item"
    slug = slugify(f"{menu_id}_{target}", max_len=36)
    return f"s_{slug}_{digest}"


def inject_shortcut_ids(manifest: dict[str, Any]) -> None:
    menus = manifest.get("menus")
    if not isinstance(menus, dict):
        return

    seen_ids: set[str] = set()
    for menu_id, menu in menus.items():
        if not isinstance(menu_id, str) or not isinstance(menu, dict):
            continue
        pages = menu.get("pages")
        if not isinstance(pages, list):
            continue
        for page in pages:
            if not isinstance(page, dict):
                continue
            shortcut_id = page.get("shortcutId")
            if not isinstance(shortcut_id, str) or shortcut_id.strip() == "":
                shortcut_id = build_shortcut_id(menu_id, page)
                page["shortcutId"] = shortcut_id
            else:
                shortcut_id = shortcut_id.strip()
                page["shortcutId"] = shortcut_id

            if shortcut_id in seen_ids:
                raise ValueError(f"Duplicate shortcutId detected in manifest: {shortcut_id}")
            seen_ids.add(shortcut_id)


def apply_runtime_translation_fields(manifest: dict[str, Any]) -> None:
    sections = manifest.get("sections")
    if isinstance(sections, list):
        for group in sections:
            if not isinstance(group, dict):
                continue

            group_translation = group.get("translation")
            if isinstance(group_translation, str) and group_translation.strip() != "":
                group["title"] = group_translation.strip()
            group.pop("translation", None)

            child_sections = group.get("sections")
            if not isinstance(child_sections, list):
                continue
            for section in child_sections:
                if not isinstance(section, dict):
                    continue
                section_translation = section.get("translation")
                if isinstance(section_translation, str) and section_translation.strip() != "":
                    section["title"] = section_translation.strip()
                section.pop("translation", None)

    menus = manifest.get("menus")
    if not isinstance(menus, dict):
        return

    for _, menu in menus.items():
        if not isinstance(menu, dict):
            continue
        menu_translation = menu.get("translation")
        if isinstance(menu_translation, str) and menu_translation.strip() != "":
            menu["title"] = menu_translation.strip()
        menu.pop("translation", None)

        pages = menu.get("pages")
        if not isinstance(pages, list):
            continue
        for page in pages:
            if not isinstance(page, dict):
                continue
            translation = page.get("translation")
            if isinstance(translation, str) and translation.strip() != "":
                page["name"] = translation.strip()
            page.pop("translation", None)


def scalar_to_lua(value: Any) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError(f"Non-finite float not supported in manifest JSON: {value!r}")
        text = repr(value)
        if text.endswith(".0"):
            text = text[:-2]
        return text
    if isinstance(value, str):
        return f'"{lua_escape(value)}"'
    raise TypeError(f"Unsupported scalar type in manifest JSON: {type(value)!r}")


def is_inline_array(value: list[Any]) -> bool:
    if not value:
        return True
    if len(value) > 6:
        return False
    for item in value:
        if isinstance(item, (dict, list)):
            return False
    return True


def to_lua(value: Any, indent: int = 0, path: tuple[str, ...] = ()) -> str:
    pad = "    " * indent

    if isinstance(value, dict):
        if not value:
            return "{}"

        lines = ["{"]
        for key, child in ordered_items(value, path):
            if not isinstance(key, str):
                raise TypeError(f"Manifest object keys must be strings; got {type(key)!r}")
            child_lua = to_lua(child, indent + 1, path + (key,))
            lines.append(f"{pad}    {lua_key(key)} = {child_lua},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)

    if isinstance(value, list):
        if not value:
            return "{}"
        if is_inline_array(value):
            parts = ", ".join(to_lua(item, 0, path + ("[]",)) for item in value)
            return f"{{ {parts} }}"

        lines = ["{"]
        for child in value:
            child_lua = to_lua(child, indent + 1, path + ("[]",))
            lines.append(f"{pad}    {child_lua},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)

    return scalar_to_lua(value)


def validate_manifest(data: dict[str, Any]) -> None:
    if not isinstance(data, dict):
        raise ValueError("Manifest source must be a JSON object")
    if not isinstance(data.get("sections"), list):
        raise ValueError("Manifest source must contain `sections` as an array")
    if not isinstance(data.get("menus"), dict):
        raise ValueError("Manifest source must contain `menus` as an object")

    for group_idx, group in enumerate(data.get("sections", [])):
        if not isinstance(group, dict):
            continue
        title = group.get("title")
        if title is not None and not isinstance(title, str):
            raise ValueError(f"sections[{group_idx}].title must be a string")
        translation = group.get("translation")
        if translation is not None and not isinstance(translation, str):
            raise ValueError(f"sections[{group_idx}].translation must be a string")

        child_sections = group.get("sections")
        if not isinstance(child_sections, list):
            continue
        for section_idx, section in enumerate(child_sections):
            if not isinstance(section, dict):
                continue
            section_title = section.get("title")
            if section_title is not None and not isinstance(section_title, str):
                raise ValueError(
                    f"sections[{group_idx}].sections[{section_idx}].title must be a string"
                )
            section_translation = section.get("translation")
            if section_translation is not None and not isinstance(section_translation, str):
                raise ValueError(
                    f"sections[{group_idx}].sections[{section_idx}].translation must be a string"
                )

    for menu_id, menu in data.get("menus", {}).items():
        if not isinstance(menu, dict):
            continue
        menu_title = menu.get("title")
        if menu_title is not None and not isinstance(menu_title, str):
            raise ValueError(f"menus.{menu_id}.title must be a string")
        menu_translation = menu.get("translation")
        if menu_translation is not None and not isinstance(menu_translation, str):
            raise ValueError(f"menus.{menu_id}.translation must be a string")

        pages = menu.get("pages")
        if not isinstance(pages, list):
            continue
        for idx, page in enumerate(pages):
            if not isinstance(page, dict):
                continue
            name = page.get("name")
            if name is not None and not isinstance(name, str):
                raise ValueError(f"menus.{menu_id}.pages[{idx}].name must be a string")
            translation = page.get("translation")
            if translation is not None and not isinstance(translation, str):
                raise ValueError(f"menus.{menu_id}.pages[{idx}].translation must be a string")


def render_manifest(manifest: dict[str, Any], source_rel: str) -> str:
    runtime_manifest = copy.deepcopy(manifest)
    apply_runtime_translation_fields(runtime_manifest)
    body = to_lua(runtime_manifest, indent=0, path=())
    return (
        "--[[\n"
        "  Copyright (C) 2026 Rotorflight Project\n"
        "  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html\n"
        "\n"
        "  AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY.\n"
        "  Edit menu data with: bin/menu/editor/menu_editor.cmd (Windows)\n"
        "  or: python bin/menu/editor/src/menu_editor.py\n"
        f"  Source of truth: {source_rel}\n"
        "  Regenerate with: python bin/menu/generate.py\n"
        "]] --\n"
        "\n"
        "return "
        f"{body}\n"
    )


def print_diff(expected: str, actual: str, expected_name: str, actual_name: str) -> None:
    diff = difflib.unified_diff(
        actual.splitlines(),
        expected.splitlines(),
        fromfile=actual_name,
        tofile=expected_name,
        lineterm="",
    )
    for line in diff:
        print(line)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate menu manifest Lua from JSON source.")
    parser.add_argument(
        "--source",
        default="bin/menu/manifest.source.json",
        help="Path to manifest JSON source.",
    )
    parser.add_argument(
        "--output",
        default="src/rfsuite/app/modules/manifest.lua",
        help="Output path for generated Lua manifest.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate that output is up to date; do not write files.",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    source_arg = Path(args.source)
    output_arg = Path(args.output)

    if source_arg.is_absolute():
        source_path = source_arg
    else:
        source_path = (repo_root / source_arg).resolve()

    if output_arg.is_absolute():
        output_path = output_arg
    else:
        output_path = (repo_root / output_arg).resolve()

    if not source_path.is_file():
        print(f"[menu] Source file not found: {source_path}", file=sys.stderr)
        return 2

    with source_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    validate_manifest(data)
    inject_shortcut_ids(data)

    try:
        source_rel = source_path.relative_to(repo_root).as_posix()
    except ValueError:
        source_rel = source_path.as_posix()

    generated = render_manifest(data, source_rel)
    current = None
    preferred_eol = "\n"
    current_raw = None
    if output_path.is_file():
        current_raw = output_path.read_bytes()
        if b"\r\n" in current_raw:
            preferred_eol = "\r\n"
        current = current_raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")

    if args.check:
        if current != generated:
            print(f"[menu] Generated manifest is out of date: {output_path}")
            print_diff(generated, current or "", "expected", "current")
            return 1
        print(f"[menu] OK: {output_path} is up to date")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if current != generated:
        output_payload = generated.replace("\n", preferred_eol)
        output_path.write_bytes(output_payload.encode("utf-8"))
        print(f"[menu] Wrote {output_path}")
    else:
        print(f"[menu] No changes: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
