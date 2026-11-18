# -*- coding: utf-8 -*-
"""R804 蜂蜜图标：1024x1024 生成图 → 128x128 透明 PNG。

两个固定毛病都要处理：
  1. 右下角「AI生成 / WORKBUDDY」水印 —— 先把那块填成背景色再抠，白字不会留在 alpha 里；
  2. 背景没有真透明（出图请求了 transparent，给的是深灰底）—— 按**色差**抠，
     不用亮度（浅色罐身比背景还亮，按亮度抠会连罐子一起吃掉）。

抠完按内容 bbox 裁切、留 6% 边距，再缩到 128x128（RelicBarLayout.CELL = 44 的验收尺寸）。
"""
import struct
import sys
from PIL import Image, ImageFilter

SRC = "E:/tmp/r804_icon/A_single_game_item_icon__a_sma_2026-11-18T12-46-00.png"
DST = "E:/tmp/wt804/assets/ui/relic_icon_6079.png"

TOL = 30          # 背景色差容差（0-255，逐通道取最大差）
EDGE = 0.06       # 裁切后四周留白比例


def bg_color(im):
    """四角各取 12x12 小块求均值 —— 背景是纯色渐变，四角最可信。"""
    w, h = im.size
    px = im.load()
    pts = []
    for cx, cy in [(12, 12), (w - 13, 12), (12, h - 13), (w - 13, h - 13)]:
        rs = gs = bs = n = 0
        for dx in range(-6, 6):
            for dy in range(-6, 6):
                r, g, b, _a = px[cx + dx, cy + dy]
                rs += r
                gs += g
                bs += b
                n += 1
        pts.append((rs // n, gs // n, bs // n))
    # 取四个角里出现最多的那种（防止某个角正好落在物件上）
    return max(set(pts), key=pts.count)


def main():
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()

    # ---- 1. 水印：右下角一块先涂成背景色 ----
    bg = bg_color(im)
    print("bg =", bg)
    x0, y0 = int(w * 0.84), int(h * 0.90)
    for y in range(y0, h):
        for x in range(x0, w):
            px[x, y] = (bg[0], bg[1], bg[2], 255)

    # ---- 2. 按色差生成前景 alpha ----
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    bgd = Image.new("RGB", (w, h), bg).load()
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            d = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            if d <= TOL:
                ap[x, y] = 0
            elif d <= TOL + 18:
                # 过渡带：线性羽化，避免缩放后出现一圈硬白边
                ap[x, y] = int(255.0 * (d - TOL) / 18.0)
    # 去掉零星孤点（背景噪点 / 压缩脏块）
    alpha = alpha.filter(ImageFilter.MedianFilter(3))
    im.putalpha(alpha)

    # ---- 3. 按内容 bbox 裁切 + 留边 ----
    bbox = alpha.getbbox()
    print("bbox =", bbox)
    if bbox is None:
        print("!! 全透明，抠图失败")
        return 1
    l, t, r, b = bbox
    side = max(r - l, b - t)
    pad = int(side * EDGE)
    cx, cy = (l + r) // 2, (t + b) // 2
    half = side // 2 + pad
    box = (cx - half, cy - half, cx + half, cy + half)
    out = Image.new("RGBA", (half * 2, half * 2), (0, 0, 0, 0))
    src = im.crop((max(0, box[0]), max(0, box[1]), min(w, box[2]), min(h, box[3])))
    out.paste(src, (max(0, -box[0]), max(0, -box[1])))
    out = out.resize((128, 128), Image.LANCZOS)
    out.save(DST)
    with open(DST, "rb") as f:
        bts = f.read(33)
    print("saved", DST, struct.unpack(">II", bts[16:24]))
    return 0


sys.exit(main())
