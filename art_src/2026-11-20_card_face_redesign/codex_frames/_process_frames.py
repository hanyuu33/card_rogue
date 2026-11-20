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


def longest_transparent_run(values):
    """Return the longest transparent half-open run, retaining the image object upstream."""
    best = (0, 0)
    start = None
    for i, transparent in enumerate(list(values) + [False]):
        if transparent and start is None:
            start = i
        elif not transparent and start is not None:
            if i - start > best[1] - best[0]:
                best = (start, i)
            start = None
    return best


def opening_box(im):
    """Locate the central art opening, not the transparent outside corners."""
    alpha = im.getchannel("A")
    px = alpha.load()
    w, h = im.size
    vertical = (0, 0)
    for xf in (0.50, 0.42, 0.58, 0.35, 0.65):
        run = longest_transparent_run(px[round(w * xf), y] < 24 for y in range(h))
        if run[1] - run[0] > vertical[1] - vertical[0]:
            vertical = run
    if vertical[1] - vertical[0] < h * 0.25:
        raise RuntimeError("art opening vertical run not found: %s" % (vertical,))
    cy = (vertical[0] + vertical[1]) // 2
    horizontal = longest_transparent_run(px[x, cy] < 24 for x in range(w))
    if horizontal[1] - horizontal[0] < w * 0.35:
        raise RuntimeError("art opening horizontal run not found: %s" % (horizontal,))
    return horizontal[0], vertical[0], horizontal[1], vertical[1]


def warp_opening(im, target_size, target_opening):
    """Nine-region warp: all classes share inner-window coordinates without losing ornaments."""
    source_opening = opening_box(im)
    sw, sh = im.size
    tw, th = target_size
    sx0, sy0, sx1, sy1 = source_opening
    tx0, ty0, tx1, ty1 = target_opening
    if not (0 <= sx0 < sx1 <= sw and 0 <= sy0 < sy1 <= sh):
        raise RuntimeError("invalid source opening: %s" % (source_opening,))
    xs = [0, sx0, sx1, sw]
    ys = [0, sy0, sy1, sh]
    txs = [0, tx0, tx1, tw]
    tys = [0, ty0, ty1, th]
    out = Image.new("RGBA", target_size, (0, 0, 0, 0))
    for row in range(3):
        for col in range(3):
            src_box = (xs[col], ys[row], xs[col + 1], ys[row + 1])
            dst_box = (txs[col], tys[row], txs[col + 1], tys[row + 1])
            src_w, src_h = src_box[2] - src_box[0], src_box[3] - src_box[1]
            dst_w, dst_h = dst_box[2] - dst_box[0], dst_box[3] - dst_box[1]
            if min(src_w, src_h, dst_w, dst_h) <= 0:
                continue
            piece = im.crop(src_box).resize((dst_w, dst_h), Image.Resampling.LANCZOS)
            out.alpha_composite(piece, (dst_box[0], dst_box[1]))
    return out


def plaque_start(master):
    """Find the first opaque row below the art opening; try symmetric columns for ornaments."""
    alpha = master.getchannel("A")
    px = alpha.load()
    w, h = master.size
    found = []
    for xf in (0.50, 0.42, 0.58, 0.35, 0.65):
        x = round(w * xf)
        candidates = [y for y in range(round(h * 0.48), h) if px[x, y] > 40]
        if candidates:
            found.append(candidates[0])
    if not found:
        raise RuntimeError("rarity plaque not found")
    found.sort()
    return found[len(found) // 2]


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "forest"
    raw = Image.open(D / "raw" / (kind + ".png"))
    master = alpha_key(raw)
    # Normalize the real outer edge before measuring the inner window. A second crop after
    # warping would move the canonical opening again (the R843f partial-fix trap).
    solid = master.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    outer = solid.getbbox()
    if outer is None:
        raise RuntimeError("empty integrated frame")
    master = master.crop(outer)
    master.save(D / "raw" / (kind + "_alpha.png"))
    band_y = plaque_start(master)
    width = 728
    scaled_h = round(master.height * width / master.width)
    base = master.resize((width, scaled_h), Image.Resampling.LANCZOS)
    scaled_band_y = round(band_y * width / master.width)
    # Keep a short tail below the detected plaque start so classes whose bottom border
    # crosses that row still have real pixels for the canonical lower frame segment.
    upper = base.crop((0, 0, width, min(scaled_h, scaled_band_y + 24)))
    band = base.crop((0, scaled_band_y, width, scaled_h))
    band_alpha = band.getchannel("A")
    band_px = band_alpha.load()
    band_cx = width // 2
    band_gap = next((y for y in range(band.height) if band_px[band_cx, y] >= 24), 0)
    if 0 < band_gap < band.height // 3:
        band = band.crop((0, band_gap, width, band.height))
    # 96 / 552 and 96 / 630 match the two code-side rarity rows after R843g.
    band_h = 96
    band = band.resize((width, band_h), Image.Resampling.LANCZOS)
    for suffix, height, opening_top in (("", 552, 52), ("_compact", 630, 62)):
        upper_h = height - band_h
        top = warp_opening(upper, (width, upper_h),
                (34, opening_top, 694, upper_h - 10))
        frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        frame.alpha_composite(top, (0, 0))
        frame.alpha_composite(band, (0, upper_h))
        # Remove only imperceptible Lanczos residue; flowers and opaque ornamental edges stay.
        frame.putalpha(frame.getchannel("A").point(lambda value: 0 if value < 6 else value))
        actual = frame.getchannel("A").point(lambda value: 255 if value >= 24 else 0).getbbox()
        if actual is None or actual[0] > 1 or actual[1] > 1 \
                or actual[2] < width - 1 or actual[3] < height - 1:
            raise RuntimeError("integrated frame bounds not normalized: %s" % (actual,))
        path = OUT / ("art_rarity_frame_" + kind + suffix + ".png")
        frame.save(path)
        print("OK", path, frame.size, "band_y", band_y, "opening", opening_box(top),
                "outer", actual, flush=True)


if __name__ == "__main__":
    main()
