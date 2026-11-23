# -*- coding: utf-8 -*-
"""title18 六类卡框 -> 工程卡面外框 + 可染色卡名框纸面（R866）。

口径：
  * 卡面比例 728:878（= 640:772 工程基准），原素材 1:1 -> 整图重采样；
  * `card_outer_frame_<kind>.png`：整张外框，**卡名框纸面被抠空**（金边/雕花保留），
    绘制时压在「染色纸面」之上 —— 稀有度只改纸面颜色，不伤金属描边；
  * `card_plate_<kind>.png`：卡名框纸面，亮度归一化灰度，绘制时 modulate 稀有度色；
  * `_plate_boxes.json`：每类的卡名框 bbox 与**卡图窗** bbox（六类确实略有差异）。
输出：assets/ui/
"""
import os
import io
import json
import colorsys
from PIL import Image, ImageFilter, ImageDraw

ROOT = r"D:\work\card_rogue"
SRC = os.path.join(ROOT, r"art_src\2026-11-23_frames\title18")
OUT = os.path.join(ROOT, "assets", "ui")
KINDS = {"bard": "bard", "enemy": "enemy", "forest": "forest",
         "mech": "mech", "other": "common", "shadow": "shadow"}
W, H = 728, 878
ALPHA_T = 24
SAT_T = 0.34
VAL_T = 0.36
EDGE_X = 0.03
EDGE_T = 0.07
EDGE_B = 0.04


def runs(n, geta):
    out, i = [], 0
    while i < n:
        if geta(i) > ALPHA_T:
            j = i
            while j < n and geta(j) > ALPHA_T:
                j += 1
            out.append((i, j - 1))
            i = j
        else:
            i += 1
    return out


def measure(im):
    """返回 (卡名框 bbox, 卡图窗 bbox)，均 0..1 归一化。"""
    w, h = im.size
    a = im.split()[3].load()
    cx = w // 2
    col = runs(h, lambda y: a[cx, y])
    p_top, p_bot = col[0]
    y_probe = int(p_top + 0.60 * (p_bot - p_top))
    row = runs(w, lambda x: a[x, y_probe])
    inner = [r for r in row if r[0] > w * 0.08 and r[1] < w * 0.92]
    mid = max(inner, key=lambda r: r[1] - r[0])
    cy = h // 2
    crow = runs(w, lambda x: a[x, cy])
    art_l = crow[0][1]
    art_r = crow[-1][0]
    art_b = col[-1][0]
    return ((mid[0] / w, p_top / h, mid[1] / w, p_bot / h),
            (art_l / w, p_bot / h, art_r / w, art_b / h))


def build(name, kind):
    src = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    src = src.crop(src.split()[3].getbbox())
    frame = src.resize((W, H), Image.Resampling.LANCZOS)
    frame.putalpha(frame.getchannel("A").point(lambda v: 0 if v < 6 else v))
    plate_box, art_box = measure(frame)
    x0, y0, x1, y1 = [int(round(v * (W if i % 2 == 0 else H))) for i, v in enumerate(plate_box)]
    iw, ih = x1 - x0, y1 - y0
    ix0, ix1 = x0 + int(iw * EDGE_X), x1 - int(iw * EDGE_X)
    iy0, iy1 = y0 + int(ih * EDGE_T), y1 - int(ih * EDGE_B)
    fpx = frame.load()
    raw = Image.new("L", (W, H), 0)
    rpx = raw.load()
    for yy in range(iy0, iy1 + 1):
        for xx in range(ix0, ix1 + 1):
            r, g, b, a = fpx[xx, yy]
            if a <= 0:
                continue
            _h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if s <= SAT_T and v >= VAL_T:
                rpx[xx, yy] = 255
    # 只认「从卡名框中心出发连得通」的那一片纸面：顶部金饰高光与噪点因此不被染色
    seed = ((ix0 + ix1) // 2, (iy0 + iy1) // 2)
    if rpx[seed] == 0:
        best, bd = seed, 1e9
        for yy in range(iy0, iy1 + 1, 2):
            for xx in range(ix0, ix1 + 1, 2):
                if rpx[xx, yy] > 0:
                    d = (xx - seed[0]) ** 2 + (yy - seed[1]) ** 2
                    if d < bd:
                        bd, best = d, (xx, yy)
        seed = best
    ImageDraw.floodfill(raw, seed, 128, thresh=0)
    soft = raw.point(lambda v: 255 if v == 128 else 0)
    soft = soft.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    soft = soft.filter(ImageFilter.GaussianBlur(1.4))
    mpx = soft.load()
    lum, n = 0.0, 0
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            r, g, b, a = fpx[xx, yy]
            if a > 0 and mpx[xx, yy] > 128:
                lum += 0.299 * r + 0.587 * g + 0.114 * b
                n += 1
    avg = max(1.0, lum / max(1, n))
    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ppx = plate.load()
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            r, g, b, a = fpx[xx, yy]
            if a <= 0:
                continue
            m = mpx[xx, yy]
            if m <= 2:
                continue
            l = (0.299 * r + 0.587 * g + 0.114 * b) / avg
            g8 = int(max(0.0, min(1.0, l)) * 255)
            ppx[xx, yy] = (g8, g8, g8, int(a * m / 255.0))
            fpx[xx, yy] = (r, g, b, int(a * (255 - m) / 255.0))
    frame.save(os.path.join(OUT, "card_outer_frame_%s.png" % kind))
    frame.save(os.path.join(OUT, "card_outer_frame_%s_compact.png" % kind))
    plate.save(os.path.join(OUT, "card_plate_%s.png" % kind))
    return plate_box, art_box


def main():
    plates, arts = {}, {}
    for name, kind in KINDS.items():
        p, a = build(name, kind)
        plates[kind] = [round(v, 4) for v in p]
        arts[kind] = [round(v, 4) for v in a]
        print("OK", kind, "plate", plates[kind], "art", arts[kind], flush=True)
    cx0 = max(v[0] for v in plates.values())
    cy0 = max(v[1] for v in plates.values())
    cx1 = min(v[2] for v in plates.values())
    cy1 = min(v[3] for v in plates.values())
    print("PLATE_COMMON", [round(cx0, 4), round(cy0, 4), round(cx1, 4), round(cy1, 4)], flush=True)
    with io.open(os.path.join(SRC, "_plate_boxes.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps({"plate": plates, "art": arts,
                            "plate_common": [round(cx0, 4), round(cy0, 4), round(cx1, 4), round(cy1, 4)]},
                           ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
