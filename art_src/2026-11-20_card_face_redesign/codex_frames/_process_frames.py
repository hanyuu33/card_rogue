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
        # R843f：抠底原图的透明安全边并不一致。若不二次归一，详情大卡会把几像素的
        # 顶部余量放大成「职业框没对齐」。以实际不透明外框为准重新贴齐同一画布；
        # 不能只信 alpha_key 的 getbbox，因为微弱品红残迹也会把 bbox 往外撑。
        solid = frame.getchannel("A").point(lambda value: 255 if value >= 24 else 0)
        outer = solid.getbbox()
        if outer is None:
            raise RuntimeError("empty integrated frame")
        frame = frame.crop(outer).resize((width, height), Image.Resampling.LANCZOS)
        frame.putalpha(frame.getchannel("A").point(lambda value: 0 if value < 6 else value))
        actual = frame.getchannel("A").point(lambda value: 255 if value >= 24 else 0).getbbox()
        # 重采样后最外一圈可能只剩淡抗锯齿；源图 1px 在最大详情卡上也不足 0.3px。
        if actual is None or actual[0] > 1 or actual[1] > 1 \
                or actual[2] < width - 1 or actual[3] < height - 1:
            raise RuntimeError("integrated frame bounds not normalized: %s" % (actual,))
        path = OUT / ("art_rarity_frame_" + kind + suffix + ".png")
        frame.save(path)
        print("OK", path, frame.size, "band_y", band_y, "outer", outer, flush=True)


if __name__ == "__main__":
    main()
