# -*- coding: utf-8 -*-
"""R806 法术卷轴图标：1024x1024 生成图 → 128x128 透明 PNG。

这张图的背景是**棋盘格伪透明**（不是纯色），单靠「与某一种背景色的色差」抠不干净 ——
两种灰格会在 alpha 里留下一块块方格。所以改用**从四边泛洪**：
  * 判据 = 「灰色」（三通道极差 <= 14）且亮度落在棋盘格两色的范围内；
  * 只有与画面边缘连通的那一片才被标成背景 → 对象内部的浅色高光不会被挖洞；
  * 右下角「AI生成 / WORKBUDDY」水印先填成灰再泛洪，白字不会留在 alpha 里。

抠完按内容 bbox 裁切、留 6% 边距，缩到 128x128（RelicBarLayout.CELL = 44 的验收尺寸）。
"""
import struct
import sys
from collections import deque
from PIL import Image, ImageFilter

SRC = "E:/tmp/r806_icon/A_single_game_item_icon__an_an_2026-11-18T15-06-06.png"
DST = "E:/tmp/wt806/assets/ui/relic_icon_6080.png"

GRAY_TOL = 20      # 三通道极差 <= 它 → 认为是灰色（对象是暖色羊皮纸，极差 35+，不会被误吃）
PROBE = 16         # 角落采样块边长
EDGE = 0.06        # 裁切后留白比例


def corner_samples(im):
    w, h = im.size
    px = im.load()
    lums = []
    for cx, cy in [(PROBE, PROBE), (w - PROBE - 1, PROBE),
                   (PROBE, h - PROBE - 1), (w - PROBE - 1, h - PROBE - 1)]:
        for dx in range(0, PROBE, 4):
            for dy in range(0, PROBE, 4):
                r, g, b, _ = px[cx - PROBE // 2 + dx, cy - PROBE // 2 + dy]
                lums.append((r + g + b) / 3.0)
    return min(lums), max(lums)


def main():
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()

    lo, hi = corner_samples(im)
    print("棋盘格亮度范围 = %.1f .. %.1f" % (lo, hi))
    # 上界放宽到 hi+45：对象外圈那层柔光是**中性灰**（亮度比棋盘格亮格再高一截），
    # 只放到 hi+16 会把整圈光晕留在 alpha 里，缩到 44px 就是一圈脏灰边。
    b_lo, b_hi = lo - 16, hi + 45

    # ---- 1. 水印：右下角先涂成背景灰（泛洪会把它一起吃掉）----
    fill = int((lo + hi) / 2)
    x0, y0 = int(w * 0.82), int(h * 0.88)
    for y in range(y0, h):
        for x in range(x0, w):
            px[x, y] = (fill, fill, fill, 255)

    def is_bg(x, y):
        r, g, b, _ = px[x, y]
        if max(r, g, b) - min(r, g, b) > GRAY_TOL:
            return False
        lum = (r + g + b) / 3.0
        return b_lo <= lum <= b_hi

    # ---- 2. 从四边泛洪标记连通背景 ----
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_bg(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    nbg = 0
    for y in range(h):
        base = y * w
        for x in range(w):
            if seen[base + x]:
                ap[x, y] = 0
                nbg += 1
    print("背景像素 %d / %d (%.1f%%)" % (nbg, w * h, 100.0 * nbg / (w * h)))

    # 边缘轻微羽化：先模糊再压回硬边，缩放后不会留一圈硬白边。
    # 阈值定在 130 偏高：这张图对象外圈有一层**中性灰柔光**，弱 alpha 处留着它
    # 在深色底上就是一圈脏灰晕（和龟壳 / 蜂蜜那种干净描边对比很明显）。
    # 再收 1px（MinFilter），把柔光最外面那圈灰芯一起切掉。
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2))
    px_a = alpha.load()
    for y in range(h):
        for x in range(w):
            v = px_a[x, y]
            px_a[x, y] = 0 if v < 130 else (255 if v > 215 else int(255.0 * (v - 130) / 85.0))
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    im.putalpha(alpha)

    # ---- 2.5 前景色向透明区外扩（防灰边）----
    # 透明像素里仍留着棋盘格的灰色。缩到 128 / 44px 时 LANCZOS 会按 RGB 插值，
    # 那些灰就会被揉进边缘 —— 肉眼看就是「抠得不干净的一圈脏边」。
    # 把完全透明的像素反复用邻近像素的颜色填满（只填 RGB，不碰 alpha），
    # 缩放时边缘就只会混入卷轴自己的颜色。
    rgb = im.convert("RGB")
    a = im.getchannel("A")
    hole = a.point(lambda v: 255 if v < 8 else 0)
    for _ in range(10):
        rgb = Image.composite(rgb.filter(ImageFilter.BoxBlur(2)), rgb, hole)
    im = rgb.convert("RGBA")
    im.putalpha(a)

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

    # 三档预览（1x / 2x / 5x），方便看 44px 下认不认得出
    prev = Image.new("RGBA", (256 + 88 + 44 + 40, 256), (28, 28, 34, 255))
    for i, sz in enumerate((256, 88, 44)):
        s = out.resize((sz, sz), Image.LANCZOS)
        xo = (0, 266, 364)[i]
        prev.alpha_composite(s, (xo, (256 - sz) // 2))
    prev.save("E:/tmp/wt806/_shots/r806_icon_preview.png")
    return 0


sys.exit(main())
