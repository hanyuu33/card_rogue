# -*- coding: utf-8 -*-
"""R759 收尾：把 raw 裁成项目口径 448x404 写进 assets/pics/_pending/，并出验收页。

⚠️ 尺寸口径（R644 之后，**不要**再用旧 tools/cardart_prep.py 的 448x403）：
   素材统一 **448x404**；卡面按 CardFace.cover_region() 居中裁成 1.51:1
   （UiTheme.CARD_ART_RATIO = 0.662）→ 只显示第 53..350 行，上下各 53 行永远看不见。
   本脚本先裁 1.51:1 横带 → 448x297 → 上下补边 → 448x404。宽高都可被 4 整除。

⚠️ 纯色标志图的两个坑（本批踩过）：
   1) 补边不能拿 1px 行拉伸 —— 圆环若被横带切断，白色环会被拉成两根白柱；
   2) 出图常在背景上留一道很淡的竖直暗纹，拉伸后变成一条黑带。
   所以对纯色底标志图一律走 `clean_flat()`：四角取背景色 → 量出圆牌圆心/半径 →
   把圆牌以外全部涂回背景色。补边、暗纹、接缝一次解决。

纪律 J：成品只落 _pending，**不自动覆盖主目录**、不 approve，等店长选版。

用法：
    python _finish.py v2        # 把 raw/9252_代偿_v2.png 裁成 _pending/9252.png
    python _finish.py           # 两个方案都裁成 _R759_448x404_<tag>.png 供比对
"""
import os
import sys
from collections import Counter

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_代偿卡图_R759")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

RATIO = 1.0 / 0.662
W, H = 448, 404
BAND_H = round(W / RATIO)   # 297
PAD = (H - BAND_H) // 2     # 53
FONT = "C:/Windows/Fonts/msyh.ttc"

VARIANTS = [("_v1", "v1 重压"), ("_v2", "v2 加价")]


def _diff(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def clean_flat(im, tol=30):
    """纯色底标志图：量出圆牌圆心/半径，把圆牌以外一律涂回背景色。"""
    w, h = im.size
    px = im.load()
    corners = []
    for ox, oy in ((0, 0), (w - 8, 0), (0, h - 8), (w - 8, h - 8)):
        for dy in range(8):
            for dx in range(8):
                corners.append(px[ox + dx, oy + dy])
    bg = Counter(corners).most_common(1)[0][0]

    best_w, cy, bx0, bx1 = 0, 0, 0, 0
    for y in range(h):
        x0 = x1 = -1
        for x in range(w):
            if _diff(px[x, y], bg) > tol:
                if x0 < 0:
                    x0 = x
                x1 = x
        if x0 >= 0 and x1 - x0 > best_w:
            best_w, cy, bx0, bx1 = x1 - x0, y, x0, x1
    if best_w <= 0:
        return im

    r = best_w / 2.0 + 4
    cx = (bx0 + bx1) / 2.0
    rr = r * r
    for y in range(h):
        dy = y - cy
        for x in range(w):
            dx = x - cx
            if dx * dx + dy * dy > rr:
                px[x, y] = bg
    return im


def cut(src, dst):
    """1.51:1 居中横带 → 448x297 → 上下补边 → 448x404（RGBA）。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bw = int(round(h * RATIO))
    if bw <= w:
        left = (w - bw) // 2
        band = im.crop((left, 0, left + bw, h))
    else:
        bh = int(round(w / RATIO))
        top = (h - bh) // 2
        band = im.crop((0, top, w, top + bh))
    band = band.resize((W, BAND_H), Image.LANCZOS)

    full = Image.new("RGB", (W, H), (0, 0, 0))
    strip_t = band.crop((0, 0, W, 1)).resize((W, PAD)).filter(ImageFilter.GaussianBlur(3))
    strip_b = band.crop((0, BAND_H - 1, W, BAND_H)).resize(
        (W, H - BAND_H - PAD)).filter(ImageFilter.GaussianBlur(3))
    full.paste(strip_t, (0, 0))
    full.paste(band, (0, PAD))
    full.paste(strip_b, (0, PAD + BAND_H))

    full = clean_flat(full)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    full.convert("RGBA").save(dst, optimize=True)
    return Image.open(dst).size


def sheet(items, out, cell_w=448):
    cell_h = int(round(cell_w * H / float(W)))
    padx, lb = 12, 26
    Wd = padx + len(items) * (cell_w + padx)
    Hd = padx + cell_h + lb + padx
    s = Image.new("RGB", (Wd, Hd), (20, 22, 28))
    d = ImageDraw.Draw(s)
    f = ImageFont.truetype(FONT, 18)
    for i, (label, p) in enumerate(items):
        x = padx + i * (cell_w + padx)
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        s.paste(im, (x, padx))
        top = padx + int(round(PAD * cell_h / float(H)))
        bot = padx + int(round((PAD + BAND_H) * cell_h / float(H)))
        d.rectangle([x, top, x + cell_w - 1, bot], outline=(90, 200, 130), width=2)
        d.text((x + 4, padx + cell_h + 4), label, fill=(235, 235, 240), font=f)
    s.save(os.path.join(D, out))
    print(out, s.size)


def main():
    pick = sys.argv[1] if len(sys.argv) > 1 else None
    items = []
    for tag, label in VARIANTS:
        raw = os.path.join(RAW, "9252_代偿%s.png" % tag)
        if not os.path.exists(raw):
            print("缺 raw:", raw)
            continue
        if pick:
            if tag != ("_" + pick.lstrip("_")):
                continue
            size = cut(raw, os.path.join(PEND, "9252.png"))
            print("cut %s -> _pending/9252.png %s" % (tag, size))
            items.append((label + "  ← 已写入 _pending", os.path.join(PEND, "9252.png")))
        else:
            dst = os.path.join(D, "_R759_448x404%s.png" % tag)
            size = cut(raw, dst)
            print("cut %s -> %s %s" % (tag, os.path.basename(dst), size))
            items.append((label, dst))
    if items:
        sheet(items, "_R759_卡面验收.png" if pick else "_R759_卡面验收_双版.png")
    if pick:
        im = Image.open(os.path.join(PEND, "9252.png"))
        print("规格校验: %s %s  (应为 (448, 404) RGBA)" % (im.size, im.mode))


if __name__ == "__main__":
    main()
