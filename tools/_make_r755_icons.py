# -*- coding: utf-8 -*-
"""R755：把 AI 出图切成 128×128 的工具图标 / UI 图标。

背景处理不走「按亮度抠白」—— 后端把 transparent 画成了**棋盘格**（235/253 两色交替），
按 `d = 255 - min(r,g,b)` 算 alpha 会把灰石本身也算成半透明。
改用 **PIL floodfill 从四角种子连通填充**（棋盘两色差 18 < thresh 40，一次填干净），
填充处即背景；再把背景 RGB 刷成物体描边的深色（避免降采样时白色渗进边缘成白雾），
最后 RGB / A 分别降采样再合并。
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = "E:/work/card_rogue/"
SENTINEL = (255, 0, 255)
SENTINEL_SET = {SENTINEL}


def _bg_mask(im, bright=200, satmax=45):
    """从四边向内做 4-连通泛洪，返回「背景」掩膜（255 = 背景）。

    ⚠️ 不用 `ImageDraw.floodfill`：它拿**填充色**跟邻近像素比，填成洋红之后
    下一格就判不过阈值，棋盘格只吃掉一个小角（R755 实测只剩 4/16384 采样点）。
    这里自己 BFS：判据是「亮且不饱和」（棋盘两色 233/254 都满足），
    石头内部的白色高光虽然也亮，但被深色描边围住、从边界走不进去。
    """
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
    mask = Image.frombytes("L", (w, h), bytes(255 if v else 0 for v in seen))
    return mask


def cut(src, out, pad_pct=0.06, bright=1.0, sat=1.0, work=512, **bg_kw):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im, **bg_kw)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧的抗锯齿像素「亮且不饱和」，会被当成前景 → 圆图标带一圈虚线亮边
    for _ in range(2):
        fg = fg.filter(ImageFilter.MinFilter(3))
    darks = sorted([c for c in im.getdata() if c not in SENTINEL_SET and sum(c) < 210],
                   key=lambda c: sum(c))
    edge = darks[max(0, len(darks) // 20)] if darks else (30, 30, 36)
    rgb = Image.composite(im, Image.new("RGB", (w, h), edge), fg)
    alpha = fg.resize((work, work), Image.LANCZOS)
    rgb = rgb.resize((work, work), Image.LANCZOS)
    # 4) 按 alpha>=8 取 bbox → 居中留白 → 128
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


STONE = "art_src/r755_stone_tool/raw/Game_item_icon_of_a_single_thr_2026-11-15T10-11-30.png"
GLYPH = "art_src/r755_stone_tool/raw/Small_UI_glyph__two_curved_arr_2026-11-15T10-12-08.png"

cut(STONE, "assets/ui/trap_icon_7012.png", bright=1.10, sat=1.05)
cut(GLYPH, "assets/ui/ui_tool_swap.png", pad_pct=0.04)
preview(["assets/ui/trap_icon_7001.png", "assets/ui/trap_icon_7012.png", "assets/ui/ui_tool_swap.png"],
        "_preview_r755_icons.png")
