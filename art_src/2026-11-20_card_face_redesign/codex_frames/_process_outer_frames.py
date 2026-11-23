# -*- coding: utf-8 -*-
"""Extend the six class materials into full-card outer frames (R843i preview)."""
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(r"E:\work\card_rogue")
OUT = ROOT / "assets/ui"
KINDS = ("forest", "shadow", "mech", "bard", "common", "enemy")
W, H = 728, 878  # Same aspect as the live card rectangle (640:772).
RAIL_W = 43
# 店长口径「宝石再放大一点，尤其是缩略图」：紧凑外圈整体缩得更小，宝石用更大的
# 放大系数补回来；碎钻级小亮点只轻放，避免糊成斑。
GEM_SCALE = 1.8        # 详情外圈：主宝石
GEM_SCALE_COMPACT = 2.4
GEM_SCALE_LARGE = 1.5  # 较大装饰件（中央菱形等）
GEM_SCALE_LARGE_COMPACT = 1.9
GEM_SCALE_SPARKLE = 1.15

# Only shadow (purple) and bard (teal) carry real gems; mech has gears, forest
# flowers, common/enemy rivets — those are not gems and stay untouched.
GEM_COLORS = {
    "shadow": lambda r, g, b: r > 70 and b > 100 and b > g + 25 and r > g + 10,
    "bard": lambda r, g, b: g > 110 and b > 95 and r < g - 25 and r < b - 15,
}
GEM_MIN_W, GEM_MAX_W = 8, 120
GEM_MIN_H, GEM_MAX_H = 8, 120
GEM_MIN_PX, GEM_MAX_PX = 90, 6000


def _gem_scale(w: int, h: int, n: int, compact: bool) -> float:
    """Tiered enlargement: main gems get the big factor, large ornaments less,
    sparkle specks only a nudge. Compact (thumbnail) frames get the largest
    factors so gems stay readable at 99x119."""
    big = GEM_SCALE_COMPACT if compact else GEM_SCALE
    large = GEM_SCALE_LARGE_COMPACT if compact else GEM_SCALE_LARGE
    if n < 260 or w < 13 or h < 13:
        return GEM_SCALE_SPARKLE
    if w > 60 or h > 60 or n > 1400:
        return large
    return big


def enlarge_gems(out: Image.Image, kind: str, compact: bool) -> int:
    """Find small opaque gem ornaments by class color and upscale each in place.

    The purple cloth drapes / teal bands match the same hues but are huge
    connected regions, so the size window alone rejects them; only isolated
    gem-sized components are magnified. Other classes have no gem colors at all.
    """
    test = GEM_COLORS.get(kind)
    if test is None:
        return 0
    px = out.load()
    ap = out.getchannel("A").load()
    mask = set()
    for y in range(out.height):
        for x in range(out.width):
            if ap[x, y] >= 128:
                r, g, b, _ = px[x, y]
                if test(r, g, b):
                    mask.add((x, y))
    enlarged = 0
    while mask:
        seed = mask.pop()
        stack = [seed]
        comp = [seed]
        while stack:
            cx, cy = stack.pop()
            for nx in (cx - 1, cx, cx + 1):
                for ny in (cy - 1, cy, cy + 1):
                    if (nx, ny) in mask:
                        mask.discard((nx, ny))
                        stack.append((nx, ny))
                        comp.append((nx, ny))
        xs = [p[0] for p in comp]
        ys = [p[1] for p in comp]
        x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
        w, h, n = x1 - x0, y1 - y0, len(comp)
        if not (GEM_MIN_W <= w <= GEM_MAX_W and GEM_MIN_H <= h <= GEM_MAX_H
                and GEM_MIN_PX <= n <= GEM_MAX_PX):
            continue
        scale = _gem_scale(w, h, n, compact)
        if scale <= 1.0:
            continue
        pad = 2
        sx0, sy0 = max(0, x0 - pad), max(0, y0 - pad)
        sx1, sy1 = min(out.width, x1 + pad), min(out.height, y1 + pad)
        crop = out.crop((sx0, sy0, sx1, sy1))
        nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
        crop = crop.resize((nw, nh), Image.Resampling.LANCZOS)
        ccx, ccy = (sx0 + sx1) // 2, (sy0 + sy1) // 2
        dx, dy = ccx - nw // 2, ccy - nh // 2
        # Clip at the canvas edge so corner gems never spill outside the card.
        cx0, cy0 = max(0, dx), max(0, dy)
        fx0, fy0 = cx0 - dx, cy0 - dy
        fx1 = min(nw, fx0 + (out.width - cx0))
        fy1 = min(nh, fy0 + (out.height - cy0))
        out.alpha_composite(crop.crop((fx0, fy0, fx1, fy1)), (cx0, cy0))
        enlarged += 1
    return enlarged


def build(kind, compact):
    suffix = "_compact" if compact else ""
    src = Image.open(OUT / ("art_rarity_frame_" + kind + suffix + ".png")).convert("RGBA")
    source_band_h = 96
    source_upper_h = src.height - source_band_h
    rarity_top = 0.610 if compact else 0.550
    rarity_bottom = 0.715 if compact else 0.660
    upper_h = round(H * rarity_top)
    band_bottom = round(H * rarity_bottom)
    band_h = band_bottom - upper_h
    bottom_top = round(H * 0.940)

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    upper = src.crop((0, 0, W, source_upper_h)).resize((W, upper_h), Image.Resampling.LANCZOS)
    band = src.crop((0, source_upper_h, W, src.height)).resize((W, band_h), Image.Resampling.LANCZOS)
    out.alpha_composite(upper, (0, 0))
    out.alpha_composite(band, (0, upper_h))

    # Extend only the real side material through the name and stats zones. The centre
    # stays transparent, so the existing paper and all live text remain unobstructed.
    extension_h = bottom_top - band_bottom
    clean_bottom = max(80, source_upper_h - 24)
    for left in (True, False):
        x0 = 0 if left else W - RAIL_W
        strip = src.crop((x0, 100, x0 + RAIL_W, clean_bottom))
        strip = ImageEnhance.Brightness(strip).enhance(0.91)
        strip = strip.resize((RAIL_W, extension_h), Image.Resampling.LANCZOS)
        out.alpha_composite(strip, (x0, band_bottom))

    # Reuse the class's own top rail, mirrored as the missing bottom rail. This gives
    # the whole card one outer silhouette instead of a separate nameplate seam.
    bottom = upper.crop((0, 0, W, 62)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    bottom = bottom.resize((W, H - bottom_top), Image.Resampling.LANCZOS)
    out.alpha_composite(bottom, (0, bottom_top))
    out.putalpha(out.getchannel("A").point(lambda value: 0 if value < 6 else value))
    gems = enlarge_gems(out, kind, compact)
    path = OUT / ("card_outer_frame_" + kind + suffix + ".png")
    out.save(path)
    print("OK", path.name, out.size, "rarity", (upper_h, band_bottom),
            "bottom", bottom_top, "gems", gems, flush=True)


def main():
    for kind in KINDS:
        for compact in (False, True):
            build(kind, compact)


if __name__ == "__main__":
    main()
