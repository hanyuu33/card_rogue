# -*- coding: utf-8 -*-
"""Cut Codex magenta keys and build detail/compact integrated class frames."""
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src/2026-11-20_card_face_redesign/codex_frames"
OUT = ROOT / "assets/ui"


def alpha_key(im):
    im = im.convert("RGBA")
    src = im.load()
    mask = Image.new("L", im.size, 0)
    dst = mask.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _a = src[x, y]
            # Magenta background/opening, including anti-aliased mixed edge pixels.
            if r > 145 and b > 145 and abs(r - b) < 105 and min(r, b) - g > 45:
                dst[x, y] = max(0, min(255, round((g - 12) * 2.8)))
            else:
                dst[x, y] = 255
    im.putalpha(mask)
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("empty chroma-key result")
    return im.crop(bbox)


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "forest"
    raw = Image.open(D / "raw" / (kind + ".png"))
    master = alpha_key(raw)
    master.save(D / "raw" / (kind + "_alpha.png"))
    # Locate the plaque at the center column: first opaque pixel after the opening.
    cx = master.width // 2
    alpha = master.getchannel("A")
    ap = alpha.load()
    candidates = [y for y in range(master.height // 2, master.height) if ap[cx, y] > 40]
    if not candidates:
        raise RuntimeError("rarity plaque not found")
    band_y = candidates[0]
    width = 728
    scaled_h = round(master.height * width / master.width)
    base = master.resize((width, scaled_h), Image.Resampling.LANCZOS)
    scaled_band_y = round(band_y * width / master.width)
    upper = base.crop((0, 0, width, scaled_band_y))
    band = base.crop((0, scaled_band_y, width, scaled_h))
    band_h = 126
    band = band.resize((width, band_h), Image.Resampling.LANCZOS)
    for suffix, height in (("", 552), ("_compact", 630)):
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        top = upper.resize((width, height - band_h), Image.Resampling.LANCZOS)
        frame.alpha_composite(top, (0, 0))
        frame.alpha_composite(band, (0, height - band_h))
        # Lanczos 会在全透明窗口留下 alpha=1 的采样残迹；统一归零，避免导入后薄雾。
        frame.putalpha(frame.getchannel("A").point(lambda value: 0 if value < 6 else value))
        path = OUT / ("art_rarity_frame_" + kind + suffix + ".png")
        frame.save(path)
        print("OK", path, frame.size, "band_y", band_y, flush=True)


if __name__ == "__main__":
    main()
