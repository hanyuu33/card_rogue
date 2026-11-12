#!/usr/bin/env python3
"""Keep CPU readback compatible with 4x4-block VRAM textures.

Godot 4.3 / GLES3 can return block-padded ASTC data from Texture2D.get_image().
If the source height is not a multiple of four, Image.initialize_data() rejects
the extra row and returns an empty image. UiAssets.filtered()/small_icon() both
need CPU readback, so every VRAM-compressed source must use block-aligned sizes.
"""

from pathlib import Path
import re
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    checked = 0
    bad = []
    for imp in ROOT.glob("assets/**/*.import"):
        text = imp.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"^compress/mode=2\s*$", text, re.MULTILINE):
            continue
        source = Path(str(imp)[:-7])
        if not source.exists():
            bad.append((source.relative_to(ROOT), "source missing"))
            continue
        with Image.open(source) as image:
            width, height = image.size
        checked += 1
        if width % 4 or height % 4:
            bad.append((source.relative_to(ROOT), f"{width}x{height}"))
    # R613: _pending is the staging mirror of the live card art. A size drift here
    # lets archive_pending_r595c.py copy an old (non-block-aligned) image back later.
    pending = ROOT / "assets" / "pics" / "_pending"
    for mirror in sorted(pending.glob("*.png")):
        live = ROOT / "assets" / "pics" / mirror.name
        if not live.exists():
            continue
        with Image.open(mirror) as staged, Image.open(live) as current:
            if staged.size != current.size:
                bad.append((mirror.relative_to(ROOT),
                            f"mirror {staged.size} != live {current.size}"))
    for source, detail in bad:
        print(f"FAIL {source}: {detail}")
    if bad:
        print(f"FAIL: {len(bad)} problem(s) across {checked} VRAM sources + pending mirrors")
        return 1
    print(f"PASS: {checked} VRAM sources are 4x4-block aligned; pending mirrors match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
