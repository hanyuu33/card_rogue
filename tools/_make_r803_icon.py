# -*- coding: utf-8 -*-
"""R803：爆炸蘑菇 7016 图标后处理（codex 出图 → 透明 128×128）。

背景处理照抄 R755 的做法（`tools/_make_r755_icons.py`）：
不走「按亮度抠白」，而是从四边做 4-连通泛洪取背景 —— 后端可能把 transparent
画成棋盘格，按亮度算会把蘑菇自身的亮部也算成半透明。

这里把 `_bg_mask` / `cut` 复制过来而不是 import：`_make_r755_icons.py` 在 import 时
就会执行它自己的 cut()，会顺手重写 7012 石头和交换图标那两张图（R755/R797/R801 都踩过）。

用法：python tools/_make_r803_icon.py
"""
import os

from PIL import Image, ImageChops, ImageEnhance, ImageFilter

ROOT = "E:/work/card_rogue/"
SENTINEL = (255, 0, 255)
SENTINEL_SET = {SENTINEL}


def _bg_mask(im, bright=200, satmax=45):
    """从四边向内做 4-连通泛洪，返回「背景」掩膜（255 = 背景）。"""
    w, h = im.size
    px = im.load()
    ok = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) >= bright and max(r, g, b) - min(r, g, b) <= satmax:
                ok[base + x] = 1
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if ok[y * w + x]:
                stack.append(y * w + x)
    for y in range(h):
        for x in (0, w - 1):
            if ok[y * w + x]:
                stack.append(y * w + x)
    while stack:
        i = stack.pop()
        if seen[i]:
            continue
        seen[i] = 1
        x = i % w
        if x > 0 and ok[i - 1] and not seen[i - 1]:
            stack.append(i - 1)
        if x < w - 1 and ok[i + 1] and not seen[i + 1]:
            stack.append(i + 1)
        if i >= w and ok[i - w] and not seen[i - w]:
            stack.append(i - w)
        if i + w < w * h and ok[i + w] and not seen[i + w]:
            stack.append(i + w)
    return Image.frombytes("L", (w, h), bytes(255 if v else 0 for v in seen))


def cut(src, out, pad_pct=0.06, bright=1.0, sat=1.0, work=512, **bg_kw):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im, **bg_kw)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧抗锯齿像素「亮且不饱和」会被当前景 → 圆图标带一圈虚线亮边
    for _ in range(2):
        fg = fg.filter(ImageFilter.MinFilter(3))
    darks = sorted([c for c in im.getdata() if c not in SENTINEL_SET and sum(c) < 210],
                   key=lambda c: sum(c))
    edge = darks[max(0, len(darks) // 20)] if darks else (30, 30, 36)
    rgb = Image.composite(im, Image.new("RGB", (w, h), edge), fg)
    alpha = fg.resize((work, work), Image.LANCZOS)
    rgb = rgb.resize((work, work), Image.LANCZOS)
    bb = alpha.point(lambda v: 255 if v >= 8 else 0).getbbox()
    side = max(bb[2] - bb[0], bb[3] - bb[1])
    side = int(side * (1.0 + pad_pct * 2))
    cx = (bb[0] + bb[2]) // 2
    cy = (bb[1] + bb[3]) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    rgb = rgb.crop(box).resize((128, 128), Image.LANCZOS)
    alpha = alpha.crop(box).resize((128, 128), Image.LANCZOS)
    if bright != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    if sat != 1.0:
        rgb = ImageEnhance.Color(rgb).enhance(sat)
    out_im = rgb.convert("RGBA")
    out_im.putalpha(alpha)
    out_im.save(ROOT + out)
    print("wrote", out, out_im.size)
    return out_im


def preview(paths, out, bg=(26, 26, 32, 255), scale=3):
    ims = [Image.open(ROOT + p).convert("RGBA") for p in paths]
    w = 128 * len(ims) + 20 * (len(ims) + 1)
    canvas = Image.new("RGBA", (w, 168), bg)
    for i, im in enumerate(ims):
        canvas.paste(im, (20 + i * 148, 20), im)
    canvas.resize((canvas.width * scale, canvas.height * scale), Image.LANCZOS).save(ROOT + out)
    print("preview", out)


RAW = "art_src/2026-11-18_连斩炮火就位与蘑菇_R803/raw/mushroom_7016.png"

cut(RAW, "assets/ui/trap_icon_7016.png", bright=1.06, sat=1.05)

# 44px 实机尺寸对照（工具栏 CELL = 44）
peers = ["assets/ui/trap_icon_7001.png", "assets/ui/trap_icon_7002.png",
         "assets/ui/trap_icon_7004.png", "assets/ui/trap_icon_7015.png",
         "assets/ui/trap_icon_7016.png"]
for name, px in (("_preview_44px.png", 44), ("_preview_88px.png", 88)):
    ims = [Image.open(ROOT + p).convert("RGBA").resize((px, px), Image.LANCZOS) for p in peers]
    w = px * len(ims) + 12 * (len(ims) + 1)
    c = Image.new("RGBA", (w, px + 24), (44, 38, 32, 255))
    for i, im in enumerate(ims):
        c.paste(im, (12 + i * (px + 12), 12), im)
    c.save(ROOT + "art_src/2026-11-18_连斩炮火就位与蘑菇_R803/processed/" + name)
    print("preview", name, c.size)
