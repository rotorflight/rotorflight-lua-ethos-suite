# FrSky ActiveLook bitmap reference, configuration version 8

Source: pilot-supplied `ENGO2_FRSKY_21_Originalsymbole_und_Analyse.zip`,
2026-10-20. Its analysis attributes these resources to a read-only extraction
from X20PROAW-EU `firmware.bin` (8,660,408 bytes). Firmware build version and
source-file hash were not supplied. No upstream licence for these extracted
firmware resources was supplied; do not assume the public ALooK CC0 asset
licence applies to these files.

See [the main evidence record](../activelook-observed-image-ids.md) for the
verification boundaries, descriptions and separate BLE measurements.

- `id_NN_raw_4bpp.bin`: decoded source pixel bytes; hashes in `manifest.json`.
- `id_NN_stored.png`: source orientation rendered as grayscale PNG.
- `id_NN_upright.png`: preview rotated 180 degrees.
- `frsky-21-symbols-*.png`: supplied contact sheets; the contrast sheet boosts
  intensity for inspection and includes descriptive German labels.
- `bitmap_mapping.csv` / `manifest.json`: supplied offsets, sizes and hashes.
- `extract_frsky_icons.py`: supplied extractor, requires Pillow; read-only
  with respect to its firmware input, writes results to an output directory.

The original firmware is not included. These are documentation assets; they
are not deployed to the radio or uploaded to glasses by this change.
