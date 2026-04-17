#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_ROOT = REPO_ROOT / "src"
DEFAULT_PACKAGE_DIR = "rfsuite"

MAIN_VERSION_RE = re.compile(
    r"version\s*=\s*\{[^}]*major\s*=\s*(\d+),\s*minor\s*=\s*(\d+),\s*revision\s*=\s*(\d+),\s*suffix\s*=\s*\"([^\"]*)\"",
    re.DOTALL,
)
MAIN_SUFFIX_RE = re.compile(
    r'(version\s*=\s*\{[^}]*suffix\s*=\s*")([^"]*)(")',
    re.DOTALL,
)
MANIFEST_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build an ETHOS Suite-installable package zip with manifest.json."
    )
    parser.add_argument("--lang", required=True, help="Locale to package, for example en or fr.")
    parser.add_argument(
        "--artifact-version",
        required=True,
        help="Build version string used in the zip filename and staged Lua suffix.",
    )
    parser.add_argument(
        "--artifact-name",
        help="Output zip filename. Defaults to rotorflight-lua-ethos-suite-<version>-<lang>.zip.",
    )
    parser.add_argument(
        "--manifest-version",
        help="Optional manifest version override. Must be numeric X.Y.Z.",
    )
    parser.add_argument(
        "--package-name",
        default="Rotorflight Lua Ethos Suite",
        help="Display name written into manifest.json.",
    )
    parser.add_argument(
        "--package-key",
        default="org.rotorflight.ethos-suite",
        help="Stable package key written into manifest.json.",
    )
    parser.add_argument(
        "--folder",
        default=DEFAULT_PACKAGE_DIR,
        help="Install folder under RADIO:/scripts/.",
    )
    parser.add_argument(
        "--package-dir",
        default=DEFAULT_PACKAGE_DIR,
        help="Directory under scripts/ to flatten into the Suite package root.",
    )
    parser.add_argument(
        "--build-root",
        help="Scratch directory used for staging and packaging. Defaults to a temporary directory.",
    )
    parser.add_argument(
        "--keep-build-root",
        action="store_true",
        help="Keep the per-run scratch directory instead of deleting it after packaging.",
    )
    parser.add_argument(
        "--output-dir",
        default=".",
        help="Directory where the finished zip will be written.",
    )
    parser.add_argument(
        "--release-notes-file",
        help="Optional UTF-8 file to embed as manifest releaseNotes content.",
    )
    parser.add_argument(
        "--release-notes-format",
        choices=("markdown", "text"),
        default="markdown",
        help="Release notes format written into manifest.json.",
    )
    return parser.parse_args()


def run(command: list[str]) -> None:
    print("[package] Running:", " ".join(command))
    child_env = os.environ.copy()
    child_env["PYTHONUTF8"] = "1"
    child_env["PYTHONIOENCODING"] = "utf-8"
    result = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        env=child_env,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
        if result.stderr:
            print(result.stderr, end="" if result.stderr.endswith("\n") else "\n")
        raise subprocess.CalledProcessError(
            result.returncode,
            command,
            output=result.stdout,
            stderr=result.stderr,
        )


def read_base_version(main_lua_path: Path) -> str:
    match = MAIN_VERSION_RE.search(main_lua_path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"Could not parse version table from {main_lua_path}")
    return ".".join(match.group(i) for i in range(1, 4))


def choose_manifest_version(
    requested_version: str | None, artifact_version: str, base_version: str
) -> str:
    version = requested_version or artifact_version
    if MANIFEST_VERSION_RE.fullmatch(version):
        return version
    if requested_version:
        raise ValueError(
            f"Manifest version must be numeric X.Y.Z, got {requested_version!r}"
        )
    print(
        f"[package] artifact version {artifact_version!r} is not a numeric X.Y.Z manifest version; "
        f"using base version {base_version!r} instead"
    )
    return base_version


def update_staged_main_version(main_lua_path: Path, artifact_version: str) -> None:
    content = main_lua_path.read_text(encoding="utf-8")
    updated, count = MAIN_SUFFIX_RE.subn(
        lambda match: f"{match.group(1)}{artifact_version}{match.group(3)}",
        content,
        count=1,
    )
    if count != 1:
        raise ValueError(f"Could not update version suffix in {main_lua_path}")
    main_lua_path.write_text(updated, encoding="utf-8")


def remove_tree(path: Path) -> None:
    if not path.exists():
        return
    for _ in range(5):
        shutil.rmtree(path, ignore_errors=True)
        if not path.exists():
            return
        time.sleep(0.1)
    raise OSError(f"Could not remove directory tree: {path}")


def remove_empty_parents(path: Path, stop_at: Path) -> None:
    current = path
    while current != stop_at and current.exists():
        try:
            current.rmdir()
        except OSError:
            break
        current = current.parent


def stage_source_tree(stage_scripts_dir: Path) -> None:
    remove_tree(stage_scripts_dir)
    shutil.copytree(SRC_ROOT, stage_scripts_dir, dirs_exist_ok=True)


def build_locale_json(lang: str) -> None:
    run([sys.executable, "bin/i18n/build-single-json.py", "--only", lang])


def resolve_i18n(stage_scripts_dir: Path, lang: str) -> None:
    run(
        [
            sys.executable,
            ".vscode/scripts/resolve_i18n_tags.py",
            "--json",
            str(stage_scripts_dir / "rfsuite" / "i18n" / f"{lang}.json"),
            "--root",
            str(stage_scripts_dir),
        ]
    )


def copy_sound_pack(stage_scripts_dir: Path, lang: str) -> None:
    sound_root = REPO_ROOT / "bin" / "sound-generator" / "soundpack"
    source = sound_root / lang
    if not source.is_dir():
        fallback = sound_root / "en"
        print(f"[package] Audio {source} not found; falling back to {fallback}")
        source = fallback
    if not source.is_dir():
        print(f"[package] No sound pack found for {lang}; skipping audio copy")
        return

    dest = stage_scripts_dir / "rfsuite" / "audio" / lang
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, dest)
    print(f"[package] Copied audio {source} -> {dest}")


def build_package_root(stage_scripts_dir: Path, package_root: Path, package_dir: str) -> None:
    source_root = stage_scripts_dir / package_dir
    if not source_root.is_dir():
        raise FileNotFoundError(f"Package source directory not found: {source_root}")
    remove_tree(package_root)
    shutil.copytree(source_root, package_root, dirs_exist_ok=True)


def collect_files(package_root: Path) -> list[str]:
    files: list[str] = []
    for path in sorted(package_root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(package_root).as_posix()
        if rel.lower() == "manifest.json":
            continue
        files.append(rel)
    if "main.lua" not in files and "main.luac" not in files:
        raise ValueError("Package must include main.lua or main.luac at package root")
    return files


def load_release_notes(path: str | None, fmt: str) -> dict[str, str] | None:
    if not path:
        return None
    content = Path(path).read_text(encoding="utf-8").strip()
    if not content:
        return None
    return {"format": fmt, "content": content}


def write_manifest(
    package_root: Path,
    package_name: str,
    package_key: str,
    version: str,
    folder: str,
    files: list[str],
    release_notes: dict[str, str] | None,
) -> None:
    manifest: dict[str, object] = {
        "manifestVersion": 1,
        "name": package_name,
        "key": package_key,
        "version": version,
        "folder": folder,
        "files": files,
    }
    if release_notes:
        manifest["releaseNotes"] = release_notes
    manifest_path = package_root / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def create_zip(package_root: Path, zip_path: Path) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    if zip_path.exists():
        zip_path.unlink()
    with ZipFile(zip_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(package_root.rglob("*")):
            if not path.is_file():
                continue
            archive.write(path, arcname=path.relative_to(package_root).as_posix())


def main() -> int:
    args = parse_args()

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    artifact_name = (
        args.artifact_name
        or f"rotorflight-lua-ethos-suite-{args.artifact_version}-{args.lang}.zip"
    )
    zip_path = output_dir / artifact_name

    using_temp_build_root = args.build_root is None
    if using_temp_build_root:
        build_root = Path(
            tempfile.mkdtemp(prefix=f"rfsuite-package-{args.lang}-", dir=str(output_dir))
        ).resolve()
        lang_root = build_root
    else:
        build_root = Path(args.build_root).resolve()
        lang_root = build_root / args.lang

    stage_scripts_dir = lang_root / "scripts"
    package_root = lang_root / "suite"

    base_version = read_base_version(SRC_ROOT / "rfsuite" / "main.lua")
    manifest_version = choose_manifest_version(
        args.manifest_version, args.artifact_version, base_version
    )

    try:
        build_locale_json(args.lang)
        stage_source_tree(stage_scripts_dir)
        resolve_i18n(stage_scripts_dir, args.lang)
        copy_sound_pack(stage_scripts_dir, args.lang)
        update_staged_main_version(
            stage_scripts_dir / args.package_dir / "main.lua", args.artifact_version
        )
        build_package_root(stage_scripts_dir, package_root, args.package_dir)

        files = collect_files(package_root)
        release_notes = load_release_notes(args.release_notes_file, args.release_notes_format)
        write_manifest(
            package_root=package_root,
            package_name=args.package_name,
            package_key=args.package_key,
            version=manifest_version,
            folder=args.folder,
            files=files,
            release_notes=release_notes,
        )
        create_zip(package_root, zip_path)
    finally:
        if not args.keep_build_root:
            remove_tree(lang_root)
            if not using_temp_build_root:
                remove_empty_parents(lang_root.parent, build_root.parent)

    print(f"[package] Created {zip_path}")
    print(
        f"[package] Manifest version={manifest_version}, folder={args.folder}, files={len(files)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
