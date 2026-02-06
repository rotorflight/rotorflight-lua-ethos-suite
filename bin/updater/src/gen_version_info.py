import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RELEASE_JSON = os.path.join(HERE, "release.json")
TEMPLATE = os.path.join(HERE, "version_info_template.txt")
OUT_FILE = os.path.join(HERE, "version_info.txt")

VERSION_RE = re.compile(r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?")


def parse_version(version_str: str):
    m = VERSION_RE.match(version_str.strip())
    if not m:
        return (0, 0, 0, 0), "0.0.0.0"
    parts = [int(p) if p is not None else 0 for p in m.groups()]
    while len(parts) < 4:
        parts.append(0)
    return tuple(parts[:4]), ".".join(str(p) for p in parts[:4])


def main() -> int:
    with open(RELEASE_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)
    version = str(data.get("version", "0.0.0"))

    filevers, filever_str = parse_version(version)
    prodvers = filevers
    prodver_str = filever_str

    with open(TEMPLATE, "r", encoding="utf-8") as f:
        template = f.read()

    content = template.format(
        FILEVERS=", ".join(str(p) for p in filevers),
        PRODVERS=", ".join(str(p) for p in prodvers),
        FILEVER_STR=filever_str,
        PRODVER_STR=prodver_str,
    )

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write(content)

    return 0


if __name__ == "__main__":
    sys.exit(main())
