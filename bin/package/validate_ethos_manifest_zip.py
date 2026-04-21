#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fnmatch
import json
import re
from pathlib import PurePosixPath
from zipfile import ZipFile

ETHOS_MANIFEST_FILE = "ethos_lua_manifest.json"
KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
FOLDER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
DRIVE_ABS_RE = re.compile(r"^[A-Za-z]:/")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate ETHOS local package zip manifest and files selection."
    )
    parser.add_argument("zip_path", help="Path to the package zip file")
    return parser.parse_args()


def normalize_zip_path(path: str) -> str:
    # Normalize ZIP names to ETHOS matching semantics: forward slash, case-insensitive.
    return path.replace("\\", "/").strip("/")


def has_forbidden_path_bits(path: str) -> bool:
    if not path:
        return True
    if path.startswith("/"):
        return True
    if DRIVE_ABS_RE.match(path):
        return True
    parts = path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return True
    return False


def validate_selector_pattern(pattern: str) -> None:
    if not isinstance(pattern, str) or not pattern:
        raise ValueError("Each files entry must be a non-empty string")
    if "\\" in pattern:
        raise ValueError(f"Invalid files pattern {pattern!r}: use '/' separators")

    normalized = normalize_zip_path(pattern)
    if has_forbidden_path_bits(normalized):
        raise ValueError(f"Invalid files pattern {pattern!r}: forbidden path segments")

    parts = normalized.split("/")
    for index, part in enumerate(parts):
        if "**" in part and part != "**":
            raise ValueError(f"Invalid files pattern {pattern!r}: '**' must be a full segment")
        if "**" == part and index != len(parts) - 1:
            raise ValueError(f"Invalid files pattern {pattern!r}: '**' must be the final segment")


def path_segments_match(path_parts: tuple[str, ...], pat_parts: tuple[str, ...]) -> bool:
    if len(path_parts) != len(pat_parts):
        return False
    for file_seg, pat_seg in zip(path_parts, pat_parts):
        # Wildcards are segment-scoped only and never match '/'.
        if not fnmatch.fnmatchcase(file_seg, pat_seg):
            return False
    return True


def expand_selector(pattern: str, zip_files: list[str]) -> set[str]:
    normalized = normalize_zip_path(pattern).lower()

    if normalized == "**":
        return set(zip_files)

    if normalized.endswith("/**"):
        prefix = normalized[:-3]
        if not prefix:
            return set(zip_files)
        return {path for path in zip_files if path.startswith(prefix + "/")}

    if "*" not in normalized:
        return {normalized} if normalized in zip_files else set()

    pat_parts = tuple(PurePosixPath(normalized).parts)
    matches: set[str] = set()
    for path in zip_files:
        path_parts = tuple(PurePosixPath(path).parts)
        if path_segments_match(path_parts, pat_parts):
            matches.add(path)
    return matches


def validate_manifest(manifest: dict, zip_files: list[str]) -> None:
    required = ("manifestVersion", "name", "key", "version", "folder", "files")
    for field in required:
        if field not in manifest:
            raise ValueError(f"Missing required manifest field: {field}")

    if manifest["manifestVersion"] != 1:
        raise ValueError("manifestVersion must be 1")

    name = manifest["name"]
    if not isinstance(name, str) or not (1 <= len(name) <= 128):
        raise ValueError("name must be a string with length 1-128")

    key = manifest["key"]
    if not isinstance(key, str) or not KEY_RE.fullmatch(key):
        raise ValueError(
            "key must be 1-128 chars, start with letter/digit, and use only letters, digits, '.', '_', ':', '-'"
        )

    version = manifest["version"]
    if not isinstance(version, str) or not VERSION_RE.fullmatch(version):
        raise ValueError("version must be numeric X.Y.Z")

    folder = manifest["folder"]
    if not isinstance(folder, str) or not FOLDER_RE.fullmatch(folder):
        raise ValueError(
            "folder must be 1-64 chars, start with letter/digit, and use only letters, digits, '.', '_', '-'"
        )

    release_notes = manifest.get("releaseNotes")
    if release_notes is not None:
        if isinstance(release_notes, str):
            if len(release_notes) > 32000:
                raise ValueError("releaseNotes string exceeds 32000 characters")
        elif isinstance(release_notes, dict):
            fmt = release_notes.get("format")
            content = release_notes.get("content")
            if fmt not in ("markdown", "text"):
                raise ValueError("releaseNotes.format must be 'markdown' or 'text'")
            if not isinstance(content, str):
                raise ValueError("releaseNotes.content must be a string")
            if len(content) > 32000:
                raise ValueError("releaseNotes.content exceeds 32000 characters")
        else:
            raise ValueError("releaseNotes must be either a string or an object")

    files = manifest["files"]
    if not isinstance(files, list) or not files:
        raise ValueError("files must be a non-empty array")

    selected: set[str] = set()
    for pattern in files:
        validate_selector_pattern(pattern)
        norm_pattern = normalize_zip_path(pattern).lower()
        if norm_pattern == ETHOS_MANIFEST_FILE:
            continue
        selected.update(expand_selector(norm_pattern, zip_files))

    if not selected:
        raise ValueError("files did not resolve to any file in zip")

    has_main = any(PurePosixPath(path).name in ("main.lua", "main.luac") for path in selected)
    if not has_main:
        raise ValueError("files expansion must include main.lua or main.luac")


def main() -> int:
    args = parse_args()

    with ZipFile(args.zip_path, "r") as archive:
        normalized_to_actual: dict[str, list[str]] = {}
        for info in archive.infolist():
            if info.is_dir():
                continue
            normalized = normalize_zip_path(info.filename)
            if not normalized:
                continue
            lowered = normalized.lower()
            normalized_to_actual.setdefault(lowered, []).append(normalized)

        zip_files = sorted(normalized_to_actual.keys())

        if "scriptinfo.json" in zip_files:
            raise ValueError("Legacy scriptinfo.json is present; only ethos_lua_manifest.json is supported")

        manifest_candidates = normalized_to_actual.get(ETHOS_MANIFEST_FILE, [])
        if not manifest_candidates:
            raise ValueError("Missing ethos_lua_manifest.json at zip root")
        if len(manifest_candidates) > 1:
            raise ValueError("Multiple ethos_lua_manifest.json entries found")

        manifest_bytes = archive.read(manifest_candidates[0])
        manifest = json.loads(manifest_bytes.decode("utf-8"))
        if not isinstance(manifest, dict):
            raise ValueError("Manifest JSON must be an object")

        validate_manifest(manifest, zip_files)

    print(f"[validate] OK: {args.zip_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
