#!/usr/bin/env python3
"""Normalise tile and theme icons to exactly 70x70 px, RGB PNG without alpha.

Scope: every PNG in src/<suite>/app/gfx/ and the theme preview icon.png of each
dashboard theme, for every suite under src/ (rfsuite and wfsuite). Dashboard graphics (dials, logos, toolbar,
default image) are deliberately NOT in scope: they are drawn at their own
size and would be destroyed by a rescale.

Icons that already are 70x70 without alpha are left byte-for-byte untouched.
Other icons (75x75, 79x70, 75x70, 100x77) are resampled with Lanczos so that
they fit into a 70x70 canvas, keeping their aspect ratio, and are centred.
The padding takes the colour of the source's own border, so non-square
sources keep their proportions and their background.

Why no alpha: an RGBA file with a fully opaque alpha channel was measured not
to draw on the Ethos simulator, at 70 px and at 40 px alike (see Issue #2365).
Sources that do carry alpha are refused rather than flattened silently.

Usage:
  python bin/assets/optimize_icons.py           rewrite every icon that is not 70x70 without alpha
  python bin/assets/optimize_icons.py --check   report only; exit 1 if any icon is off-spec

Requires Pillow (pip install pillow).
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

SIZE = 70
REPO_ROOT = Path(__file__).resolve().parents[2]
PATTERNS = (
    "src/*/app/gfx/*.png",
    "src/*/widgets/dashboard/themes/*/icon.png",
)


def icon_paths():
    for pattern in PATTERNS:
        yield from sorted(REPO_ROOT.glob(pattern))


def has_alpha(img):
    return img.mode in ("RGBA", "LA", "PA") or "transparency" in img.info


def border_colour(rgb):
    """Most common colour along the outer edge of an RGB image."""
    width, height = rgb.size
    px = rgb.load()
    edge = [px[x, 0] for x in range(width)]
    edge += [px[x, height - 1] for x in range(width)]
    edge += [px[0, y] for y in range(height)]
    edge += [px[width - 1, y] for y in range(height)]
    return Counter(edge).most_common(1)[0][0]


def fit_to_canvas(source, path):
    """Return a SIZE x SIZE RGB image with the source fitted and centred."""
    if has_alpha(source):
        raise ValueError(f"{path.name}: has an alpha channel; refusing to flatten it silently")
    rgb = source.convert("RGB")
    scale = min(SIZE / rgb.width, SIZE / rgb.height)
    width = max(1, round(rgb.width * scale))
    height = max(1, round(rgb.height * scale))
    scaled = rgb.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (SIZE, SIZE), border_colour(rgb))
    canvas.paste(scaled, ((SIZE - width) // 2, (SIZE - height) // 2))
    return canvas


def is_in_spec(img):
    return img.mode == "RGB" and img.size == (SIZE, SIZE) and not has_alpha(img)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="report off-spec icons, do not write")
    args = parser.parse_args()

    paths = list(icon_paths())
    if not paths:
        print("no icons found under the configured patterns", file=sys.stderr)
        return 1

    off_spec = []
    for path in paths:
        with Image.open(path) as img:
            if is_in_spec(img):
                continue
            off_spec.append((path, f"{img.size[0]}x{img.size[1]} {img.mode}"))
            if not args.check:
                fit_to_canvas(img, path).save(path, format="PNG", optimize=True)

    rel = lambda p: p.relative_to(REPO_ROOT).as_posix()
    verb = "off-spec" if args.check else "rescaled"
    for path, desc in off_spec:
        print(f"{verb}: {rel(path)} {desc}")
    print(f"{len(paths)} icons, {len(off_spec)} {verb}")

    return 1 if (args.check and off_spec) else 0


if __name__ == "__main__":
    sys.exit(main())
