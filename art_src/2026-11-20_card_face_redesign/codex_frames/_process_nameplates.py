# -*- coding: utf-8 -*-
"""Build class-matched card-name backplates with exact detail/compact aspect ratios."""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "assets/ui"
KINDS = ("forest", "shadow", "mech", "bard", "common", "enemy")
PAPER = {
    "forest": (211, 222, 190),
    "shadow": (211, 202, 220),
    "mech": (235, 216, 174),
    "bard": (201, 227, 219),
    "common": (237, 224, 196),
    "enemy": (234, 204, 193),
}


def clamp(value):
    return max(0, min(255, round(value)))


def paper_center(kind, size):
    """Quiet light centre: no inner rectangular frame and no text-like ornament."""
    w, h = size
    base = PAPER[kind]
    rng = random.Random(8430 + list(KINDS).index(kind) + h)
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        # A short shadow under the shared upper edge, then an evenly lit writing surface.
        shade = 0.82 + 0.18 * min(1.0, t / 0.20)
        shade *= 1.0 - 0.07 * max(0.0, (t - 0.78) / 0.22)
        for x in range(w):
            grain = rng.choice((-2, -1, 0, 0, 0, 1, 2))
            px[x, y] = tuple(clamp(c * shade + grain) for c in base) + (255,)
    return im.filter(ImageFilter.GaussianBlur(0.45))


def build(kind, compact):
    suffix = "_compact" if compact else ""
    frame = Image.open(OUT / ("art_rarity_frame_" + kind + suffix + ".png")).convert("RGBA")
    # 728 is the canonical frame width. Heights match 728 * card_h/card_w * zone_h/zone_w.
    # Detail: 0.660..0.845; compact: 0.715..0.835. Both start exactly at the rarity bottom.
    height = 113 if compact else 175
    plate = paper_center(kind, (728, height))

    # Reuse each class's actual lower side material. Only the side rails are retained;
    # the rarity centre is never stretched into a second plaque behind the card name.
    band = frame.crop((0, frame.height - 96, 728, frame.height))
    rail_w = 43
    left = band.crop((0, 8, rail_w, 88)).resize((rail_w, height), Image.Resampling.LANCZOS)
    right = band.crop((728 - rail_w, 8, 728, 88)).resize((rail_w, height), Image.Resampling.LANCZOS)
    left = ImageEnhance.Brightness(left).enhance(0.88)
    right = ImageEnhance.Brightness(right).enhance(0.88)
    plate.alpha_composite(left, (0, 0))
    plate.alpha_composite(right, (728 - rail_w, 0))

    draw = ImageDraw.Draw(plate, "RGBA")
    # Narrow bevels visually join the existing rails; no new horizontal line at the top.
    draw.line((42, 0, 42, height - 1), (70, 48, 27, 150), width=2)
    draw.line((44, 0, 44, height - 1), (255, 244, 205, 105), width=1)
    draw.line((684, 0, 684, height - 1), (255, 244, 205, 105), width=1)
    draw.line((685, 0, 685, height - 1), (70, 48, 27, 150), width=2)
    # The attribute bar begins immediately below; a restrained lower edge belongs to it.
    draw.line((0, height - 3, 727, height - 3), (72, 49, 28, 170), width=2)
    draw.line((0, height - 1, 727, height - 1), (235, 202, 127, 190), width=1)
    path = OUT / ("card_nameplate_" + kind + suffix + ".png")
    plate.save(path)
    print("OK", path.name, plate.size, flush=True)


def main():
    for kind in KINDS:
        for compact in (False, True):
            build(kind, compact)


if __name__ == "__main__":
    main()
